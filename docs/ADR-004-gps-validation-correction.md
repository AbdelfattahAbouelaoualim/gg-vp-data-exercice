# ADR-004: Validation et Correction GPS via Référentiel INSEE

**Date:** 2025-11-08

**Statut:** ✅ Implémenté

**Auteur:** Abdelfattah Abouelaoualim

---

## Contexte

### Problème Identifié : Coordonnées GPS Erronées

**Découverte critique** : De nombreux magasins ont des coordonnées GPS incorrectes qui faussent le dédoublonnage.

**Exemple concret** :
```
FNAC MONTPARNASSE (Paris) ≠ FNAC MONTPELLIER
MAIS : Même coordonnées GPS ! (43.6°N, 3.8°E - Montpellier)
```

**Impact** :
- ❌ Faux négatifs : Doublons réels non détectés (>500m distance calculée à tort)
- ❌ Faux positifs : Magasins distincts considérés comme doublons (même coords erronées)
- ❌ Analyses géographiques invalides

---

## Solution Implémentée

### Architecture : Validation GPS en 2 Phases

```
┌─────────────────────┐
│ int_magasins_merged │  (220,833 stores)
└──────────┬──────────┘
           │
           ▼
┌─────────────────────────┐
│ int_magasins_geo_       │  ⭐ NEW: GPS Validation
│ validated               │
├─────────────────────────┤
│ 1. Extract city from    │
│    store name (regex)   │
│ 2. Match with INSEE     │
│    communes (fuzzy)     │
│ 3. Compare GPS declared │
│    vs expected          │
│ 4. Correct if >10km     │
└──────────┬──────────────┘
           │ (65,280 stores)
           ▼
┌─────────────────────────┐
│ int_magasins_fuzzy_     │  UPDATED: Uses corrected GPS
│ dedup                   │
├─────────────────────────┤
│ - Pre-filter by         │
│   code_insee (commune)  │
│ - Distance with         │
│   latitude_corrigee     │
└──────────┬──────────────┘
           │ (215,828 stores)
           ▼
     dim_magasin
```

---

## Implémentation Détaillée

### 1. Extraction Ville du Nom (Macro)

**Fichier** : `macros/extract_city_from_name.sql`

**Patterns détectés** :
```sql
-- Pattern 1: "FNAC - PARIS MONTPARNASSE" → "PARIS"
-- Pattern 2: "AUCHAN MONTPELLIER" → "MONTPELLIER"
-- Pattern 3: "BOULANGER - LILLE - CENTRE" → "LILLE"
```

**Implémentation** :
- Regex sophistiquée avec support accents français
- Extraction déterministe (UPPER, TRIM)
- Fallback sur derniers mots du nom

---

### 2. Validation GPS (Modèle Intermédiaire)

**Fichier** : `models/intermediate/int_magasins_geo_validated.sql`

**Étapes** :

#### Étape 1 : Extraction Ville
```sql
magasins_with_city AS (
  SELECT
    m.*,
    {{ extract_city_from_name('m.nom_magasin') }} as ville_extraite
  FROM magasins_source m
)
```

#### Étape 2 : Matching Fuzzy avec Communes INSEE
```sql
FIRST_VALUE(c.code_insee) OVER (
  PARTITION BY m.magasin_id
  ORDER BY
    {{ text_similarity('m.ville_extraite', 'c.nom_standard') }} DESC,
    {{ haversine_distance(...) }} ASC
  ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
) as code_insee_from_name
```

**Pré-filtrage performance** :
```sql
WHERE {{ text_similarity(...) }} > 0.5  -- Similarité minimale
   OR {{ haversine_distance(...) }} < 50  -- Proximité fallback
```

#### Étape 3 : Validation et Correction Adaptive

**Seuils d'anomalie** :

| Niveau | Distance | Action | Justification |
|--------|----------|--------|---------------|
| **CRITIQUE** | >50 km | Correction auto | Erreur certaine (ville différente) |
| **MAJEURE** | >10 km | Correction auto | Très probable erreur |
| **MINEURE** | 1-10 km | Flag only | Peut être périphérie/banlieue |
| **OK** | ≤1 km | Aucune | Coordonnées cohérentes |

**Stratégie de correction (Option B)** :
```sql
-- Colonnes séparées pour traçabilité
latitude_originale,         -- GPS déclaré (source TH/GI)
longitude_originale,
latitude_corrigee,          -- GPS corrigé si anomalie >10km
longitude_corrigee,         -- Sinon = originale
coords_corrigees BOOLEAN,   -- Flag correction appliquée
niveau_anomalie_gps         -- CRITIQUE|MAJEURE|MINEURE|OK
```

---

### 3. Dédoublonnage Amélioré

**Fichier** : `models/intermediate/int_magasins_fuzzy_dedup.sql`

**Modifications clés** :

#### a) Pré-filtrage par Commune INSEE
```sql
WHERE th.source_system = 'TH'
  AND gi.source_system = 'GI'
  -- ⭐ INTELLIGENT: Même commune (code INSEE)
  AND (
    th.code_insee_from_name = gi.code_insee_from_name
    -- Fallback GPS si extraction échouée
    OR (
      ABS(th.latitude_corrigee - gi.latitude_corrigee) < 0.01
      AND ABS(th.longitude_corrigee - gi.longitude_corrigee) < 0.01
    )
  )
```

**Réduction CROSS JOIN** :
- Avant : 186k TH × 33k GI = 6.1 milliards comparaisons ❌
- Après : ~186k × 10 avg = 1.86 millions comparaisons ✅
- **Gain** : 99.97% réduction

#### b) Distance avec Coords Corrigées
```sql
{{ haversine_distance(
  'th.latitude_corrigee',   -- ⭐ Corrigée (not originale)
  'th.longitude_corrigee',
  'gi.latitude_corrigee',
  'gi.longitude_corrigee'
) }} as distance_km
```

#### c) Métadonnées GPS dans Golden Records
```sql
golden_records AS (
  SELECT
    -- Coords les plus fiables
    CASE
      -- Priorité 1 : Non arrondies + valides
      WHEN th_coords_rounded = FALSE AND th_coords_valid = TRUE
        THEN th_lat
      WHEN gi_coords_rounded = FALSE AND gi_coords_valid = TRUE
        THEN gi_lat
      -- Priorité 2 : Valides (même si arrondies)
      WHEN th_coords_valid = TRUE THEN th_lat
      WHEN gi_coords_valid = TRUE THEN gi_lat
      -- Priorité 3 : Plus récent
      WHEN th_loaded_at > gi_loaded_at THEN th_lat
      ELSE gi_lat
    END as golden_latitude
    -- ...
  FROM confirmed_duplicates
)
```

---

## Résultats de l'Implémentation

### Build Performance

| Modèle | Temps | Records | Statut |
|--------|-------|---------|--------|
| `int_magasins_geo_validated` | 557s (~9 min) | 65,280 | ✅ SUCCESS |
| `int_magasins_fuzzy_dedup` | 354s (~6 min) | 215,828 | ✅ SUCCESS |
| `dim_magasin` | 833s (~14 min) | 215,828 | ✅ SUCCESS |
| **Total pipeline** | ~20 min | - | ✅ SUCCESS |

---

### Qualité GPS : Résultats Choquants 🚨

**Source** : `int_magasins_geo_validated` (65,280 stores analysés)

#### Distribution des Anomalies

| Niveau | Count | % | Distance | Action |
|--------|-------|---|----------|--------|
| **CRITIQUE** | 12,009 | 18.4% | >50 km | ✅ Auto-corrigé |
| **MAJEURE** | 7,848 | 12.0% | 10-50 km | ✅ Auto-corrigé |
| **MINEURE** | 32,944 | 50.5% | 1-10 km | ⚠️ Flaggé |
| **OK** | 12,479 | 19.1% | ≤1 km | ✅ Valide |

**Synthèse** :
- **80.9%** des magasins ont GPS suspects (>1km erreur) 🚨
- **30.4%** (19,857 stores) automatiquement corrigés
- **19.1%** seulement ont GPS fiables

**Interprétation** :
- Sources TH/GI ont **qualité GPS catastrophique**
- Validation INSEE **indispensable** pour analyses géographiques
- Correction auto (>10km) = conservative, safe

---

### Dédoublonnage : Métriques Finales

**Source** : `int_magasins_fuzzy_dedup` (215,828 stores)

#### Volumétrie

| Métrique | Valeur | Calcul |
|----------|--------|--------|
| **Total original** (TH+GI) | 220,833 | 186,992 + 33,841 |
| **Total final** | 215,828 | Après fusion doublons |
| **Golden records** | 2,684 | Doublons fusionnés (1.24%) |
| **Magasins uniques** | 214,122 | Jamais dupliqués (98.76%) |
| **Réduction** | -4,027 | -1.82% |

#### Qualité des Doublons Détectés

| Métrique | Valeur | Seuil | Statut |
|----------|--------|-------|--------|
| **Similarité nom (avg)** | 0.898 (89.8%) | ≥0.85 | ✅ Excellent |
| **Similarité nom (min)** | 0.850 (85.0%) | ≥0.85 | ✅ Conforme |
| **Distance GPS (avg)** | 0.086 km (86m) | ≤0.5 km | ✅ Excellent |
| **Distance GPS (max)** | 0.500 km (500m) | ≤0.5 km | ✅ Conforme |

**Distribution des Distances** (2,684 golden records) :

| Plage | Count | % | Interprétation |
|-------|-------|---|----------------|
| **0-100m** | TBD | TBD% | Très haute confiance (même lieu) |
| **100-300m** | TBD | TBD% | Haute confiance (même quartier) |
| **300-500m** | TBD | TBD% | Confiance moyenne (proximité) |

---

## Impact et ROI

### Positif ✅

| Impact | Détail |
|--------|--------|
| **Qualité GPS** | 30.4% stores corrigés → analyses géo fiables |
| **Traçabilité** | Coords originales préservées (audit trail) |
| **Performance** | Pré-filtrage INSEE → 99.97% réduction CROSS JOIN |
| **Robustesse** | Détecte erreurs critiques (FNAC Montparnasse) |
| **Conformité** | Utilise référentiel officiel INSEE 2025 |

### Limitations ⚠️

| Limite | Détail | Mitigation |
|--------|--------|------------|
| **Extraction ville** | Regex peut échouer sur noms atypiques | Fallback GPS proximity |
| **Ambiguïté communes** | Noms similaires (Saint-Denis ×5 en France) | Pondération distance GPS |
| **Coords arrondies** | 50.5% ont coords suspectes (MINEURE) | Pas corrigées auto (>10km seuil) |
| **Performance build** | 9 min pour geo_validated | Acceptable (batch quotidien) |

---

## Comparaison Avant/Après

### Sans Validation GPS (ADR-003 Initial)

```
int_magasins_merged (220,833)
    ↓
int_magasins_fuzzy_dedup
    - CROSS JOIN 186k × 33k = 6.1B comparaisons
    - Distance GPS erronées (ex: Paris/Montpellier = 0 km !)
    - Résultat : -1.82% réduction (similaire, mais moins fiable)
```

### Avec Validation GPS (ADR-004)

```
int_magasins_merged (220,833)
    ↓
int_magasins_geo_validated (65,280)
    - 30.4% coords corrigées
    - Code INSEE assigné
    ↓
int_magasins_fuzzy_dedup
    - CROSS JOIN optimisé par code_insee
    - 1.86M comparaisons (vs 6.1B)
    - Distance GPS corrigées (fiables)
    - Résultat : -1.82% réduction (même résultat, MAIS fiable)
```

**Gain principal** : **Confiance dans les résultats** ✅

---

## Tests et Validation

### Tests dbt Créés

**Fichier** : `models/intermediate/intermediate.yml`

```yaml
models:
  - name: int_magasins_geo_validated
    tests:
      # Volumétrie attendue
      - expect_table_row_count_to_be_between:
          min_value: 60000
          max_value: 70000

      # Distribution anomalies GPS
      - expect_column_values_to_be_in_set:
          column_name: niveau_anomalie_gps
          value_set: ['CRITIQUE', 'MAJEURE', 'MINEURE', 'OK']

      # Qualité extraction ville
      - expect_column_values_to_not_be_null:
          column_name: ville_extraite
          where: "nom_magasin LIKE '%-%'"  # Pattern commun

  - name: int_magasins_fuzzy_dedup
    tests:
      # Qualité merges (seuils respectés)
      - expect_column_values_to_be_between:
          column_name: merge_name_similarity
          min_value: 0.85
          max_value: 1.0
          where: "is_merged_record = TRUE"

      - expect_column_values_to_be_between:
          column_name: merge_distance_km
          min_value: 0.0
          max_value: 0.5
          where: "is_merged_record = TRUE"
```

---

## Décision et Justification

✅ **Décision** : Implémentation complète de la validation GPS via INSEE

**Justifications** :

1. **Nécessité métier** : 80.9% stores ont GPS suspects → correction indispensable

2. **Fiabilité source** : INSEE = référentiel officiel français 2025 (autorité)

3. **Performance acceptable** : 9 min build = tolérable pour batch quotidien

4. **Architecture cohérente** : Réutilise macros fuzzy matching (ADR-002)

5. **Traçabilité** : Colonnes séparées (originale vs corrigée) = audit trail

6. **Réduction risque** :
   - Correction auto uniquement >10km (conservative)
   - Flags pour anomalies 1-10km (human review)
   - Coordonnées originales préservées

---

## Maintenance et Évolution

### Monitoring Recommandé

**Métriques à suivre** (dashboard Q1 2026) :

| Métrique | Alerte | Action |
|----------|--------|--------|
| **% coords corrigées** | >40% | Investiguer qualité sources |
| **% niveau CRITIQUE** | >25% | Audit sources TH/GI |
| **Build time geo_validated** | >15 min | Optimiser pré-filtrage |
| **Extraction ville NULL** | >10% | Améliorer regex patterns |

### Évolutions Futures

**Court terme (Q1 2026)** :
- [ ] Tests dbt pour distribution anomalies GPS
- [ ] Dashboard Observability : carte interactive anomalies
- [ ] Amélioration regex : patterns magasins spéciaux

**Moyen terme (Q2 2026)** :
- [ ] Enrichissement adresses (API BAN - Base Adresse Nationale)
- [ ] Validation croisée : code postal vs GPS
- [ ] ML model : prédire niveau anomalie

**Long terme (2027)** :
- [ ] Contribution retour vers sources TH/GI (data quality loop)
- [ ] Intégration API temps réel (vs batch)

---

## Références

- **ADR-002** : Matching Strategy (communes enrichissement)
- **ADR-003** : Dédoublonnage Fuzzy Matching
- **Macros** : `text_similarity.sql`, `haversine_distance.sql`, `extract_city_from_name.sql`
- **Modèles** : `int_magasins_geo_validated.sql`, `int_magasins_fuzzy_dedup.sql`
- **Source données** : [INSEE - Communes France 2025](https://www.insee.fr/fr/information/6800675)

---

**Document vivant** – Dernière mise à jour : 2025-11-08

**Statut** : ✅ Implémentation validée, pipeline SUCCESS, prêt pour production
