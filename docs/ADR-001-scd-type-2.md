# ADR-001: Choix de SCD Type 2 pour dim_magasin

**Statut:** Accepté

**Date:** 2025-11-08

**Décideurs:** Data Engineering Team, Product Owner

**Consultés:** Data Analysts, Business Stakeholders

---

## Contexte

Nous devons modéliser la dimension `dim_magasin` qui consolide deux sources (TH et GI) avec des mises à jour régulières. Les coordonnées GPS et noms des magasins peuvent changer au fil du temps.

**Besoins métier identifiés:**
- Analyser l'évolution des implantations géographiques dans le temps
- Auditer les changements de localisation pour détecter des erreurs
- Calculer des métriques historiques (ex: "combien de magasins dans cette région au T1 2024?")
- Conformité réglementaire (traçabilité des modifications)

---

## Options Considérées

### Option 1: SCD Type 1 (Overwrite)

**Description:** Écraser les anciennes valeurs à chaque changement.

**Avantages:**
- ✅ Simplicité technique (pas de logique incrémentale complexe)
- ✅ Table plus petite (1 ligne par magasin)
- ✅ Requêtes simples (pas de filtre `is_current`)

**Inconvénients:**
- ❌ **Perte totale de l'historique** → Bloquant métier
- ❌ Impossible de répondre aux questions "état au T-1"
- ❌ Non-confiance réglementaire (pas de traçabilité)

**Verdict:** ❌ Rejeté (ne répond pas au besoin historisation)

---

### Option 2: SCD Type 2 (New Row per Change)

**Description:** Créer une nouvelle ligne à chaque changement, garder les anciennes versions.

**Avantages:**
- ✅ **Historique complet** de tous les changements
- ✅ Requêtes temporelles faciles (`WHERE valid_from <= date AND (valid_to > date OR valid_to IS NULL)`)
- ✅ Flexibilité pour tracker plusieurs attributs changeants
- ✅ Standard de l'industrie (Kimball methodology)
- ✅ Compatible avec incrémental dbt

**Inconvénients:**
- ⚠️ Table plus volumineuse (~10% croissance/an estimé)
- ⚠️ Complexité requêtes (toujours filtrer `is_current = TRUE` pour la version actuelle)
- ⚠️ Logique incrémentale dbt plus complexe (detect changes, close old, insert new)

**Verdict:** ✅ **CHOISI**

---

### Option 3: SCD Type 3 (Previous/Current Columns)

**Description:** Ajouter des colonnes `previous_*` et `current_*`.

**Exemple:**
```sql
latitude_current, latitude_previous,
longitude_current, longitude_previous,
changed_date
```

**Avantages:**
- ✅ Historique limité (version précédente)
- ✅ Table compacte (1 ligne par magasin)

**Inconvénients:**
- ❌ **Historique incomplet** (seulement 1 version précédente)
- ❌ Rigide: doit ajouter colonnes pour chaque attribut tracké
- ❌ Pas scalable si >2 versions nécessaires

**Verdict:** ❌ Rejeté (historique insuffisant)

---

### Option 4: Snapshot Journalier (dbt Snapshots)

**Description:** Capturer snapshot quotidien de toute la table source.

**Avantages:**
- ✅ Historique complet jour par jour
- ✅ Simple à implémenter (dbt snapshot)

**Inconvénients:**
- ❌ **Volumétrie explosive** (220k × 365 = 80M lignes/an même sans changement!)
- ❌ Stockage coûteux
- ❌ Requêtes lentes (scan massif)
- ❌ Pas de logique "change detection" (snapshot tout, même si rien n'a changé)

**Verdict:** ❌ Rejeté (coût prohibitif)

---

## Décision: SCD Type 2

Nous implémentons **SCD Type 2** avec:

### Colonnes SCD

| Colonne | Type | Description |
|---------|------|-------------|
| `valid_from` | TIMESTAMP | Date début validité (CURRENT_TIMESTAMP au moment de l'insert) |
| `valid_to` | TIMESTAMP | Date fin validité (NULL si version courante) |
| `is_current` | BOOLEAN | TRUE = version actuelle, FALSE = historique |

### Critères de Changement Détectés

Un nouveau record est créé si **au moins un** de ces attributs change:
1. `nom_magasin`
2. `latitude`
3. `longitude`
4. `coords_dans_plage_france`

**Attributs NON trackés** (pas de nouvelle version si changement):
- `commune_nom`, `code_postal`, `dep_nom`, `reg_nom` (enrichissement peut changer sans que le magasin change)
- `match_fiable`, `coords_correction_requise` (métadonnées qualité)

### Logique Incrémentale dbt

```sql
-- 1. Détecter changements (INSERT/UPDATE/NO_CHANGE)
changes AS (
    SELECT s.*,
           CASE
               WHEN t.magasin_id IS NULL THEN 'INSERT'
               WHEN t.nom_magasin != s.nom_magasin OR ... THEN 'UPDATE'
               ELSE 'NO_CHANGE'
           END AS change_type
    FROM source s
    LEFT JOIN {{ this }} t ON s.magasin_id = t.magasin_id AND t.is_current = TRUE
)

-- 2. Clore anciennes versions (SET is_current=FALSE, valid_to=NOW())
-- 3. Insérer nouvelles versions (INSERT avec is_current=TRUE)
```

### Requêtage Post-Implémentation

**Version actuelle (usage quotidien):**
```sql
SELECT * FROM dim_magasin WHERE is_current = TRUE;
```

**État historique (analyse temporelle):**
```sql
SELECT * FROM dim_magasin
WHERE '2024-06-01' BETWEEN valid_from AND COALESCE(valid_to, '9999-12-31');
```

**Audit changements d'un magasin:**
```sql
SELECT * FROM dim_magasin
WHERE magasin_id = 123456 AND source_system = 'TH'
ORDER BY valid_from DESC;
```

---

## Conséquences

### Positives ✅

1. **Historique complet** pour analyses métier et conformité
2. **Flexibilité** pour ajouter/retirer attributs trackés sans refonte
3. **Standard industrie** (équipe familière avec pattern Kimball)
4. **Compatible dbt** (matérialisation incremental native)
5. **Performance acceptable** (893s pour 220k lignes en initial load)

### Négatives ⚠️

1. **Volumétrie accrue:**
   - Estimation: 220k lignes actuellement
   - Croissance: ~5% des magasins changent/mois (10k changements/mois)
   - Projection an 1: 220k + 120k = 340k lignes (+55%)

2. **Complexité requêtes:**
   - Analystes doivent **toujours** filtrer `is_current = TRUE`
   - Erreur fréquente: oublier le filtre → doublons apparents
   - **Mitigation:** Créer view `dim_magasin_current` avec filtre

3. **Logique incrémentale complexe:**
   - Maintenance dbt model plus difficile
   - Tests critiques: `assert_scd2_one_current_per_store.sql`

4. **Performance queries:**
   - JOIN sur dimension avec historique plus lent
   - **Mitigation:** Clustering key `(source_system, is_current)`

---

## Métriques de Succès

| Métrique | Cible | Mesure Actuelle |
|----------|-------|-----------------|
| Taux de changement mensuel | <5% | - (TBD) |
| Volumétrie après 1 an | <400k lignes | 220k (baseline) |
| Performance requête (is_current filter) | <1s | - (TBD) |
| Taux d'erreur "oubli is_current" | <5% des requêtes | - (éducation analysts) |

---

## Alternatives Futures

Si volumétrie devient problématique (>10M lignes):

1. **Partitioning Snowflake:** Partitionner par `is_current` + `source_system`
2. **Archivage historique:** Déplacer versions >2 ans vers table archive
3. **Compression attributes:** Stocker changements (delta) au lieu de full row

---

## Références

- [Kimball SCD Types](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/type-2/)
- [dbt Incremental Models](https://docs.getdbt.com/docs/build/incremental-models)
- [Snowflake Time Travel](https://docs.snowflake.com/en/user-guide/data-time-travel)

---

**Approuvé par:** Data Engineering Team

**Implémenté:** 2025-11-08

**Prochaine révision:** 2026-01-31 (après 3 mois production)
