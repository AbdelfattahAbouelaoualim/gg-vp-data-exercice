# FAQ - Questions Fréquentes

**Dernière mise à jour** : 2025-11-09

**Contributeurs** : Data Engineering Team

Cette FAQ répond aux questions les plus fréquentes sur le projet. Si votre question n'apparaît pas ici, contactez #data-engineering sur Slack.

---

## Table des Matières

1. [Général](#général)
2. [Installation & Setup](#installation--setup)
3. [Utilisation & Développement](#utilisation--développement)
4. [Données & Modèles](#données--modèles)
5. [Performance & Optimisation](#performance--optimisation)
6. [Erreurs Courantes](#erreurs-courantes)
7. [GPS & Validation](#gps--validation)
8. [Dédoublonnage](#dédoublonnage)
9. [Production & Déploiement](#production--déploiement)
10. [Sécurité & RBAC](#sécurité--rbac)

---

## Général

### Q: Qu'est-ce que ce projet ?

**R** : C'est un projet dbt qui consolide deux sources de données magasins (TH et GI) en une **dimension unique et historisée** (SCD Type 2), avec :
- ✅ Validation et correction GPS automatique (via référentiel INSEE)
- ✅ Dédoublonnage intelligent (fuzzy matching)
- ✅ Enrichissement géographique (communes, départements, régions)
- ✅ Pipeline DataOps complet (CI/CD, tests, observabilité)

**Volumétrie** : 220,833 magasins sources → 215,828 après dédoublonnage

---

### Q: Pourquoi SCD Type 2 plutôt que SCD Type 1 ou snapshots ?

**R** : Le SCD Type 2 permet de **conserver l'historique complet** des changements :

| Approche | Historique | Volumétrie | Requêtes | Use Case |
|----------|-----------|------------|----------|----------|
| **SCD Type 1** | ❌ Écrasé | Faible | Simples | Données ref stables |
| **Snapshots** | ✅ Partiel | Très élevée | Complexes | Audits |
| **SCD Type 2** | ✅ Complet | Modérée | Moyennes | ⭐ Analyses temporelles |

**Notre besoin** : Analyser évolution géographique magasins (déménagements, fermetures, ou même opportunités d'ouverture de nouveaux magasins) → **SCD Type 2** optimal.

Voir [ADR-001](ADR-001-scd-type-2.md) pour détails.

---

### Q: Quelles sont les sources de données ?

**R** : Trois sources principales :

| Source | Database | Table | Volumétrie | Fréquence MAJ | GPS Quality |
|--------|----------|-------|-----------|---------------|-------------|
| **TH** | DTL_EXO | th.magasins | 186,992 | Quotidienne | ⚠️ 80% suspects |
| **GI** | DTL_EXO | gi.magasins | 33,841 | Quotidienne | ⚠️ 80% suspects |
| **INSEE** | Seed CSV | communes-france-2025 | 34,431 | Annuelle | ✅ Référence officielle |

**Note critique** : 80.9% des GPS TH/GI sont erronés (découverte v1.2.0) → correction via INSEE indispensable.

---

### Q: Combien de temps prend le pipeline complet ?

**R** : **~20 minutes** (version 1.2.0) :

| Étape | Temps | % |
|-------|-------|---|
| Staging (TH+GI) | ~10s | 1% |
| Merged | ~10s | 1% |
| **GPS Validation** | **~9 min** | **45%** |
| **Fuzzy Dedup** | **~6 min** | **30%** |
| Augmented | ~15s | 1% |
| **dim_magasin (SCD2)** | **~14 min** | **70%** |
| Observability | ~5s | 1% |

**Optimisations** :
- Clustering Snowflake activé
- Pré-filtrage INSEE (99.97% réduction CROSS JOIN)
- Matérialisations table (pas view)

---

## Installation & Setup

### Q: Quels sont les prérequis ?

**R** :
- ✅ Python 3.10+
- ✅ Git
- ✅ Compte Snowflake avec rôle `DATA_ENGINEER` ou `DBT_RUNNER`
- ✅ Flyway CLI (optionnel, sinon via Docker)

**Installation** :
```bash
pip install dbt-snowflake==1.10.3
git clone <repo>
cd gg-vp-data-exercice
dbt deps
```

---

### Q: Comment configurer `profiles.yml` ?

**R** : Créer `~/.dbt/profiles.yml` :

```yaml
gg_vp_data:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('SNOWFLAKE_USER') }}"
      password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"
      role: "{{ env_var('SNOWFLAKE_ROLE') }}"
      database: "{{ env_var('SNOWFLAKE_DATABASE_DEV') }}"
      warehouse: "{{ env_var('SNOWFLAKE_WAREHOUSE') }}"
      schema: staging
      threads: 4
      client_session_keep_alive: False
```

**Tester** :
```bash
dbt debug  # Doit afficher "All checks passed!"
```

---

### Q: Erreur "Connection timeout" lors de `dbt debug` ?

**R** : Vérifier :

1. **Warehouse suspendu** :
   ```sql
   SHOW WAREHOUSES LIKE 'TRANSFORM_WH';
   -- Si STATE='SUSPENDED', redémarrer :
   ALTER WAREHOUSE TRANSFORM_WH RESUME;
   ```

2. **Permissions** :
   ```sql
   SHOW GRANTS TO ROLE DATA_ENGINEER;
   -- Doit inclure USAGE sur TRANSFORM_WH
   ```

3. **Réseau** :
   - VPN d'entreprise actif ?
   - Firewall bloque port 443 ?

---

## Utilisation & Développement

### Q: Comment exécuter le pipeline localement ?

**R** :
```bash
# 1. Seed données INSEE (première fois uniquement)
dbt seed

# 2. Run tous les modèles
dbt run  # ~20 min

# 3. Tests qualité
dbt test

# 4. Documentation
dbt docs generate
dbt docs serve  # http://localhost:8080
```

---

### Q: Comment run un seul modèle ?

**R** :
```bash
# Run modèle + upstreams
dbt run --select +int_magasins_geo_validated

# Run modèle seul
dbt run --select int_magasins_geo_validated

# Run modèle + downstreams
dbt run --select int_magasins_geo_validated+

# Run plusieurs modèles
dbt run --select int_magasins_geo_validated int_magasins_fuzzy_dedup
```

---

### Q: Comment déboguer un modèle qui échoue ?

**R** :

**Étape 1** : Compiler le SQL :
```bash
dbt compile --select mon_modele
cat target/compiled/gg_vp_data/models/.../mon_modele.sql
```

**Étape 2** : Exécuter directement dans Snowflake (copier/coller SQL compilé)

**Étape 3** : Analyser erreur :
- `invalid identifier` → colonne manquante dans upstream
- `division by zero` → ajouter NULLIF
- `timeout` → optimiser CROSS JOIN

**Étape 4** : Fix + re-run :
```bash
dbt run --select mon_modele --full-refresh
```

---

### Q: Quelle est la différence entre `dbt run` et `dbt run --full-refresh` ?

**R** :

| Commande | Comportement | Modèles Incrémentaux | Modèles Table | Usage |
|----------|-------------|----------------------|---------------|-------|
| `dbt run` | Incrémental | INSERT uniquement nouveaux | DROP + CREATE | Quotidien |
| `dbt run --full-refresh` | Complet | DROP + recréer tout | DROP + CREATE | Après changement schéma |

**Notre projet** : Tous modèles `materialized='table'` → pas de différence pratique.

**Quand utiliser `--full-refresh`** :
- Après modification schéma (ajout colonne)
- Après changement logique métier
- En cas de corruption données

---

## Données & Modèles


### Q: Quelle est la signification de `niveau_anomalie_gps` ?

**R** : Niveau de cohérence entre GPS déclaré et GPS attendu (centre commune INSEE) :

| Niveau | Distance | Signification | Action | % Stores |
|--------|----------|---------------|--------|----------|
| **CRITIQUE** | >50 km | Erreur certaine (ville différente) | Auto-corrigé | 18.4% |
| **MAJEURE** | 10-50 km | Probablement mauvaise ville | Auto-corrigé | 12.0% |
| **MINEURE** | 1-10 km | Peut-être périphérie/banlieue | Flaggé seulement | 50.5% |
| **OK** | ≤1 km | Coordonnées cohérentes | Aucune | 19.1% |

**Exemple** :
```sql
SELECT nom_magasin, niveau_anomalie_gps, distance_gps_vs_commune
FROM int_magasins_geo_validated
WHERE niveau_anomalie_gps = 'CRITIQUE'
ORDER BY distance_gps_vs_commune DESC
LIMIT 5;

-- Résultat typique :
-- FNAC MONTPARNASSE | CRITIQUE | 520.3 km (coords Montpellier au lieu de Paris)
```

---

### Q: Comment savoir si un magasin est un doublon ?

**R** : Vérifier colonne `is_merged_record` :

```sql
SELECT
  magasin_id,
  nom_magasin,
  sources_merged,  -- ['TH', 'GI'] si doublon fusionné
  is_merged_record,  -- TRUE si golden record
  merge_name_similarity,  -- Score 0.85-1.0
  merge_distance_km,  -- Distance 0-0.5 km
  original_th_id,  -- ID source TH
  original_gi_id  -- ID source GI
FROM int_magasins_fuzzy_dedup
WHERE is_merged_record = TRUE
LIMIT 10;
```

**Golden record** : Magasin créé en fusionnant un doublon TH+GI.

---

### Q: Comment tracer l'origine d'un magasin dans dim_magasin ?

**R** : Utiliser lineage via `original_th_id` / `original_gi_id` :

```sql
-- Trouver golden record
SELECT magasin_key, nom_magasin, original_th_id, original_gi_id
FROM dim_magasin
WHERE nom_magasin LIKE '%FNAC BASTILLE%'
  AND is_current = TRUE;

-- Résultat :
-- magasin_key: md5_abc123
-- nom_magasin: FNAC PARIS BASTILLE (nom le plus long choisi)
-- original_th_id: 12345
-- original_gi_id: 78910

-- Tracer retour aux sources
SELECT * FROM DTL_EXO.TH.magasins WHERE id = 12345;
SELECT * FROM DTL_EXO.GI.magasins WHERE id = 78910;
```

---

## Performance & Optimisation

### Q: Pourquoi `int_magasins_geo_validated` prend 9 minutes ?

**R** : **CROSS JOIN** entre magasins et communes de l'INSEE France 2025 :

```sql
-- 220,833 stores × 34,431 communes = 7.6 milliards comparaisons potentielles

-- Optimisations appliquées :
WHERE text_similarity(...) > 0.5  -- Pré-filtre ~95%
   OR haversine_distance(...) < 50  -- Pré-filtre ~98%

-- Résultat : ~50 millions comparaisons (réduction 99.3%)
```

**9 minutes = acceptable** pour :
- 220k stores
- 34k communes
- Calculs EDITDISTANCE + Haversine

**Optimisations futures** (si besoin) :
- Indexer par département (réduction 99.9%)
- Paralléliser par plage latitude
- Cacher résultats matching stable

---

### Q: Comment optimiser les requêtes sur `dim_magasin` ?

**R** :

**1. Utiliser clustering** :
```sql
SELECT * FROM dim_magasin
WHERE source_system = 'TH'  -- Clustered
  AND is_current = TRUE  -- Clustered
LIMIT 100;
-- ⚡ ~10ms (vs ~500ms sans clustering)
```

**2. Filtrer toujours `is_current = TRUE`** :
```sql
-- ❌ LENT (scan toutes versions)
SELECT COUNT(*) FROM dim_magasin;

-- ✅ RAPIDE (scan uniquement version actuelle)
SELECT COUNT(*) FROM dim_magasin WHERE is_current = TRUE;
```

**3. Limiter colonnes** :
```sql
-- ❌ LENT (toutes colonnes)
SELECT * FROM dim_magasin WHERE is_current = TRUE;

-- ✅ RAPIDE (seulement nécessaires)
SELECT magasin_id, nom_magasin, latitude, longitude
FROM dim_magasin
WHERE is_current = TRUE;
```

---

### Q: Comment réduire les coûts Snowflake ?

**R** :

**1. Auto-suspend warehouses** :
```sql
ALTER WAREHOUSE TRANSFORM_WH SET AUTO_SUSPEND = 60;  -- 60 secondes
```

**2. Éviter scans complets** :
```sql
-- ❌ Coûteux
SELECT * FROM dim_magasin;

-- ✅ Optimisé
SELECT magasin_id, nom_magasin, latitude, longitude 
FROM dim_magasin 
WHERE is_current = TRUE;
```

**3. Utiliser vues matérialisées** (si requêtes répétitives) :
```sql
CREATE MATERIALIZED VIEW mv_magasins_actifs AS
SELECT * FROM dim_magasin WHERE is_current = TRUE;

-- Rafraîchir quotidiennement via cron
ALTER MATERIALIZED VIEW mv_magasins_actifs REFRESH;
```

**4. Monitorer usage** :
```sql
SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE WAREHOUSE_NAME = 'TRANSFORM_WH'
  AND START_TIME >= DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY START_TIME DESC;
```

---

## Erreurs Courantes

### Q: Erreur "invalid identifier 'S.LATITUDE'" ?

**R** : **Cause** : Modèle référence ancienne colonne après migration GPS validation.

**Solution** :
```sql
-- Avant (❌ erreur)
SELECT s.latitude, s.longitude FROM all_stores s;

-- Après (✅ correct)
SELECT s.latitude_corrigee AS latitude, s.longitude_corrigee AS longitude
FROM all_stores s;
```

**Fix permanent** : Éditer `.sql` et remplacer références colonnes.

---

### Q: Test `assert_scd2_one_current_per_store` échoue ?

**R** : **Cause** : Plusieurs versions `is_current=TRUE` pour même magasin (intégrité SCD2 violée).

**Diagnostic** :
```sql
SELECT magasin_id, source_system, COUNT(*)
FROM dim_magasin
WHERE is_current = TRUE
GROUP BY 1, 2
HAVING COUNT(*) > 1;
```

**Solution** :
```sql
-- Garder version la plus récente
UPDATE dim_magasin
SET is_current = FALSE
WHERE magasin_key IN (
  SELECT magasin_key
  FROM (
    SELECT magasin_key,
      ROW_NUMBER() OVER (PARTITION BY magasin_id, source_system ORDER BY valid_from DESC) as rn
    FROM dim_magasin
    WHERE is_current = TRUE
  )
  WHERE rn > 1
);
```

---

### Q: Erreur "Compilation Error: Macro 'text_similarity' not found" ?

**R** : **Cause** : Packages dbt non installés.

**Solution** :
```bash
dbt deps  # Install packages dbt_utils, dbt_expectations
dbt run --select int_magasins_geo_validated
```

---

## GPS & Validation

### Q: Pourquoi corriger les GPS plutôt que les accepter tels quels ?

**R** : **80.9%** des magasins ont GPS suspects (découverte critique v1.2.0) :

**Exemple réel** :
```sql
-- Avant correction
SELECT nom_magasin, latitude, longitude
FROM stg_th_magasins
WHERE nom_magasin LIKE '%FNAC MONTPARNASSE%';
-- Résultat : lat=43.6, lon=3.8 (Montpellier) ❌

-- Après correction
SELECT nom_magasin, latitude_corrigee, longitude_corrigee
FROM int_magasins_geo_validated
WHERE nom_magasin LIKE '%FNAC MONTPARNASSE%';
-- Résultat : lat=48.8, lon=2.3 (Paris centre) ✅
```

**Impact métier** :
- ❌ Sans correction : Dashboard "Magasins Île-de-France" manque 50% des stores
- ✅ Avec correction : Analyses géographiques fiables

---

### Q: Les coordonnées originales sont-elles perdues ?

**R** : **NON**, traçabilité complète :

```sql
SELECT
  nom_magasin,
  latitude_originale,  -- GPS déclaré par source
  latitude_corrigee,  -- GPS corrigé (ou original si OK)
  coords_corrigees,  -- TRUE si correction appliquée
  niveau_anomalie_gps  -- Niveau de confiance
FROM int_magasins_geo_validated;
```

**Audit trail** : Toujours possible de retrouver GPS original.

---

## Dédoublonnage

### Q: Comment sont détectés les doublons ?

**R** : **Double critère** :

1. **Similarité nom** (EDITDISTANCE) :
   ```sql
   EDITDISTANCE('FNAC PARIS BASTILLE', 'FNAC BASTILLE')
   / GREATEST(LENGTH(...), LENGTH(...))
   = 0.89  -- 89% similarité
   ```

2. **Distance GPS** (Haversine) :
   ```sql
   haversine_distance(48.8534, 2.3698, 48.8535, 2.3699)
   = 0.011 km  -- 11 mètres
   ```

**Seuils** :
- Similarité ≥ 0.85 (85%)
- Distance ≤ 0.5 km (500 mètres)
- **ET** les deux conditions doivent être vraies

**Résultat** : 2,684 doublons détectés (1.24%)

---

### Q: Comment est créé un "golden record" ?

**R** : **Combine meilleur de chaque source** :

| Champ | Stratégie | Exemple |
|-------|-----------|---------|
| **Nom** | Le plus long (plus détaillé) | "FNAC PARIS BASTILLE" > "FNAC BASTILLE" |
| **GPS** | Non arrondies + valides prioritaires | Coords TH si précises, sinon GI |
| **Source** | Déterministe (TH > GI par défaut) | 'TH' |
| **Timestamp** | Le plus récent | MAX(th.loaded_at, gi.loaded_at) |

```sql
-- Exemple golden record
magasin_id: md5_hash
nom_magasin: "FNAC PARIS BASTILLE"  -- TH (plus long)
latitude: 48.8534  -- TH (non arrondie)
longitude: 2.3698  -- TH (non arrondie)
source_system: 'TH'  -- Déterministe
sources_merged: ['TH', 'GI']  -- Traçabilité
is_merged_record: TRUE
merge_name_similarity: 0.89
merge_distance_km: 0.011
original_th_id: '12345'
original_gi_id: '78910'
```

---

## Production & Déploiement

### Q: Comment déployer en PROD ?

**R** : **Via CI/CD (recommandé)** :

1. Merge `develop` → `main`
2. GitHub Actions démarre workflow PROD
3. **Approbation manuelle requise** (cliquer "Approve" dans GitHub UI)
4. Pipeline exécute :
   - Flyway migrations DDL
   - `dbt run --target prod`
   - `dbt test --target prod --fail-fast`
5. Tag Git créé : `deploy-YYYYMMDD-HHMMSS`

**Manuel (emergency uniquement)** :
```bash
dbt run --target prod --select int_magasins_fuzzy_dedup+
dbt test --target prod --fail-fast
```

---

### Q: Comment rollback en cas d'erreur PROD ?

**R** :

**Option 1 : Git revert**
```bash
git revert <commit_sha>
git push origin main
# CI/CD redéploie automatiquement version précédente
```

**Option 2 : Snowflake Time Travel**
```sql
-- Restaurer table à T-2h
CREATE TABLE dim_magasin_restored CLONE dim_magasin
  AT(OFFSET => -7200);  -- 2 heures = 7200 secondes

-- Vérifier
SELECT COUNT(*) FROM dim_magasin_restored;

-- Remplacer
DROP TABLE dim_magasin;
ALTER TABLE dim_magasin_restored RENAME TO dim_magasin;
```

**Option 3 : Skip modèles problématiques**
```bash
dbt run --target prod --exclude int_magasins_fuzzy_dedup
```

---

## Sécurité & RBAC

### Q: Qui a accès en écriture PROD ?

**R** : **Personne** (zéro humain en écriture directe PROD).

**Accès PROD** :
- ✅ Lecture : `DATA_ENGINEER`, `DATA_ANALYST`, `PRODUCT_OWNER`
- ✅ Écriture : **UNIQUEMENT CI/CD** (via service account `github_actions_bot`)
- ⚠️ Approbation manuelle requise avant tout déploiement

**Principe** : Defense in depth + separation of duties.

---

### Q: Comment demander accès Snowflake ?

**R** : **Process onboarding** :

1. **Data Analyst** :
   ```sql
   CREATE USER alice_analyst PASSWORD='***' DEFAULT_ROLE=DATA_ANALYST;
   GRANT ROLE DATA_ANALYST TO USER alice_analyst;
   ```

2. **Data Engineer** :
   ```sql
   CREATE USER bob_engineer PASSWORD='***' DEFAULT_ROLE=DATA_ENGINEER;
   GRANT ROLE DATA_ENGINEER TO USER bob_engineer;
   ```

**Contact** : Demande via Trello "Access Request" ou DM #data-engineering-leads.

---

## Support

Votre question n'est pas dans la FAQ ?

| Type | Canal | Temps Réponse |
|------|-------|---------------|
| Incident PROD | PagerDuty | Immédiat |
| Question technique | Slack #data-engineering | <2h |
| Feature request | Jira "Data Requests" | Review hebdo |
| Bug documentation | GitHub Issues | <48h |

---

**Dernière mise à jour** : 2025-11-09

**Mainteneur** : Data Engineering Team
