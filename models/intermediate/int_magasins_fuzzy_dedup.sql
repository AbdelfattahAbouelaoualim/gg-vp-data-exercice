{{ config(
    materialized='table',
    schema='intermediate',
    tags=['intermediate', 'deduplication', 'fuzzy_matching'],
    cluster_by=['source_system', 'is_merged_record']
) }}

/*
Dédoublonnage fuzzy des magasins TH et GI avec validation géographique.

Amélioration v2 : Utilise coords GPS corrigées via référentiel INSEE
  - Problème : Certains magasins ont coords erronées (ex: FNAC MONTPARNASSE avec coords de Montpellier)
  - Solution : Validation GPS via int_magasins_geo_validated
  - Pré-filtrage : Même code_insee (même commune) pour réduire CROSS JOIN

Algorithme :
1. Pré-filtrage par code_insee (même commune suspectée par nom)
2. Calcul similarité nom (EDITDISTANCE)
3. Calcul distance GPS avec COORDONNÉES CORRIGÉES (Haversine)

Seuils de détection doublons:
- Similarité >= 0.85 (85% similarité nom)
- Distance <= 0.5 km (500 mètres avec coords corrigées)

Pour chaque groupe de doublons, on crée un "golden record" :
- Nom le plus détaillé (plus long)
- Coordonnées corrigées les plus fiables
- Source la plus fiable (TH > GI si coords valides)
- Timestamp le plus récent
*/

WITH all_stores AS (
  -- Utilise coords GPS validées et corrigées via INSEE
  SELECT * FROM {{ ref('int_magasins_geo_validated') }}
),

-- Étape 1 : Trouver les paires de doublons potentiels
-- On compare uniquement TH vs GI (pas TH vs TH ou GI vs GI)
potential_duplicates AS (
  SELECT
    th.magasin_id as th_id,
    gi.magasin_id as gi_id,
    th.nom_magasin as th_nom,
    gi.nom_magasin as gi_nom,

    -- Coords corrigées (priorité) ou originales (fallback)
    th.latitude_corrigee as th_lat,
    th.longitude_corrigee as th_lon,
    gi.latitude_corrigee as gi_lat,
    gi.longitude_corrigee as gi_lon,

    -- Métadonnées coords
    th.latitude_originale as th_lat_orig,
    th.longitude_originale as th_lon_orig,
    gi.latitude_originale as gi_lat_orig,
    gi.longitude_originale as gi_lon_orig,
    th.coords_corrigees as th_coords_were_corrected,
    gi.coords_corrigees as gi_coords_were_corrected,
    th.niveau_anomalie_gps as th_anomalie,
    gi.niveau_anomalie_gps as gi_anomalie,

    th.loaded_at as th_loaded_at,
    gi.loaded_at as gi_loaded_at,
    th.coords_dans_plage_france as th_coords_valid,
    gi.coords_dans_plage_france as gi_coords_valid,
    th.coords_arrondies as th_coords_rounded,
    gi.coords_arrondies as gi_coords_rounded,

    -- Métadonnées géographiques INSEE
    th.code_insee_from_name as th_code_insee,
    gi.code_insee_from_name as gi_code_insee,
    th.commune_nom_from_name as th_commune,
    gi.commune_nom_from_name as gi_commune,

    -- Calcul similarité et distance (avec coords CORRIGÉES)
    {{ text_similarity('th.nom_magasin', 'gi.nom_magasin') }} as name_similarity,
    {{ haversine_distance('th.latitude_corrigee', 'th.longitude_corrigee', 'gi.latitude_corrigee', 'gi.longitude_corrigee') }} as distance_km

  FROM all_stores th
  CROSS JOIN all_stores gi
  WHERE th.source_system = 'TH'
    AND gi.source_system = 'GI'

    -- ⭐ PRÉ-FILTRAGE INTELLIGENT par code_insee (même commune)
    -- Réduit drastiquement le CROSS JOIN (220k × 220k → ~220k × 10)
    AND (
      -- Même commune (critère principal)
      th.code_insee_from_name = gi.code_insee_from_name

      -- OU proximité GPS brute (fallback si extraction ville échouée)
      OR (
        ABS(th.latitude_corrigee - gi.latitude_corrigee) < 0.01
        AND ABS(th.longitude_corrigee - gi.longitude_corrigee) < 0.01
      )
    )
),

-- Étape 2 : Filtrer les vrais doublons (seuils stricts)
confirmed_duplicates AS (
  SELECT
    th_id,
    gi_id,
    th_nom,
    gi_nom,
    th_lat,
    th_lon,
    gi_lat,
    gi_lon,
    th_loaded_at,
    gi_loaded_at,
    th_coords_valid,
    gi_coords_valid,
    th_coords_rounded,
    gi_coords_rounded,
    name_similarity,
    distance_km
  FROM potential_duplicates
  WHERE name_similarity >= 0.85  -- 85% similarité minimum
    AND distance_km <= 0.5  -- 500 mètres maximum
),

-- Étape 3 : Créer les "golden records" pour chaque doublon
golden_records AS (
  SELECT
    -- Choisir le meilleur nom (le plus long = le plus détaillé)
    CASE
      WHEN LENGTH(th_nom) >= LENGTH(gi_nom) THEN th_nom
      ELSE gi_nom
    END as golden_nom,

    -- Choisir les meilleures coordonnées
    CASE
      -- Priorité 1 : Coordonnées non arrondies + valides
      WHEN th_coords_rounded = FALSE AND th_coords_valid = TRUE THEN th_lat
      WHEN gi_coords_rounded = FALSE AND gi_coords_valid = TRUE THEN gi_lat
      -- Priorité 2 : Coordonnées valides (même si arrondies)
      WHEN th_coords_valid = TRUE THEN th_lat
      WHEN gi_coords_valid = TRUE THEN gi_lat
      -- Priorité 3 : Plus récent
      WHEN th_loaded_at > gi_loaded_at THEN th_lat
      ELSE gi_lat
    END as golden_latitude,

    CASE
      WHEN th_coords_rounded = FALSE AND th_coords_valid = TRUE THEN th_lon
      WHEN gi_coords_rounded = FALSE AND gi_coords_valid = TRUE THEN gi_lon
      WHEN th_coords_valid = TRUE THEN th_lon
      WHEN gi_coords_valid = TRUE THEN gi_lon
      WHEN th_loaded_at > gi_loaded_at THEN th_lon
      ELSE gi_lon
    END as golden_longitude,

    -- Choisir la source principale (pour traçabilité)
    CASE
      -- Priorité 1 : Source avec coords valides + non arrondies
      WHEN th_coords_rounded = FALSE AND th_coords_valid = TRUE THEN 'TH'
      WHEN gi_coords_rounded = FALSE AND gi_coords_valid = TRUE THEN 'GI'
      -- Priorité 2 : TH par défaut (convention)
      ELSE 'TH'
    END as golden_source,

    -- Conserver les deux sources pour traçabilité
    ARRAY_CONSTRUCT('TH', 'GI') as sources_merged,

    -- Timestamp le plus récent
    GREATEST(th_loaded_at, gi_loaded_at) as golden_loaded_at,

    -- Flag indiquant que c'est un golden record (doublon mergé)
    TRUE as is_merged_record,

    -- Métadonnées de qualité du merge
    name_similarity as merge_name_similarity,
    distance_km as merge_distance_km,

    -- IDs originaux pour traçabilité (convertis en VARCHAR pour cohérence)
    CAST(th_id AS VARCHAR) as original_th_id,
    CAST(gi_id AS VARCHAR) as original_gi_id

  FROM confirmed_duplicates
),

-- Étape 4 : Récupérer tous les magasins NON-doublons (uniques)
non_duplicates AS (
  SELECT
    -- Convertir magasin_id en VARCHAR pour compatibilité avec golden_records
    CAST(s.magasin_id AS VARCHAR) as magasin_id,
    s.nom_magasin,
    s.latitude_corrigee as latitude,
    s.longitude_corrigee as longitude,
    s.source_system,
    ARRAY_CONSTRUCT(s.source_system) as sources_merged,
    s.loaded_at,
    FALSE as is_merged_record,
    NULL::FLOAT as merge_name_similarity,
    NULL::FLOAT as merge_distance_km,
    CAST(CASE WHEN s.source_system = 'TH' THEN s.magasin_id ELSE NULL END AS VARCHAR) as original_th_id,
    CAST(CASE WHEN s.source_system = 'GI' THEN s.magasin_id ELSE NULL END AS VARCHAR) as original_gi_id
  FROM all_stores s
  WHERE NOT EXISTS (
    -- Exclure les magasins TH qui ont un doublon GI
    SELECT 1 FROM confirmed_duplicates cd
    WHERE s.magasin_id = cd.th_id
  )
  AND NOT EXISTS (
    -- Exclure les magasins GI qui ont un doublon TH
    SELECT 1 FROM confirmed_duplicates cd
    WHERE s.magasin_id = cd.gi_id
  )
),

-- Étape 5a : Ajouter le hash MD5 aux golden records AVANT le GROUP BY
golden_records_with_id AS (
  SELECT
    {{ dbt_utils.generate_surrogate_key(['golden_nom', 'golden_latitude', 'golden_longitude']) }} as magasin_id,
    golden_nom,
    golden_latitude,
    golden_longitude,
    golden_source,
    golden_loaded_at,
    merge_name_similarity,
    merge_distance_km,
    original_th_id,
    original_gi_id
  FROM golden_records
),

-- Étape 5b : Dédoublonner les golden records (plusieurs paires peuvent produire le même golden record)
golden_records_dedup AS (
  SELECT
    magasin_id,
    MAX(golden_nom) as nom_magasin,  -- Prendre le nom le plus long (MAX alphabétique)
    MAX(golden_latitude) as latitude,  -- Prendre les coordonnées les plus récentes
    MAX(golden_longitude) as longitude,
    MIN(golden_source) as source_system,  -- Prendre la première source alphabétiquement (déterministe)
    ARRAY_CONSTRUCT('TH', 'GI') as sources_merged,  -- Constant pour golden records
    MAX(golden_loaded_at) as loaded_at,  -- Timestamp le plus récent parmi les doublons
    TRUE as is_merged_record,  -- Constant pour golden records
    -- Pour les doublons de golden records, on garde les métriques moyennes
    AVG(merge_name_similarity) as merge_name_similarity,
    AVG(merge_distance_km) as merge_distance_km,
    -- Concaténer tous les IDs originaux (pour traçabilité complète)
    LISTAGG(DISTINCT original_th_id, ',') WITHIN GROUP (ORDER BY original_th_id) as original_th_id,
    LISTAGG(DISTINCT original_gi_id, ',') WITHIN GROUP (ORDER BY original_gi_id) as original_gi_id
  FROM golden_records_with_id
  GROUP BY
    magasin_id
),

-- Étape 6 : Combiner golden records dédoublonnés + non-doublons
final AS (
  -- Golden records (doublons mergés et dédoublonnés)
  SELECT * FROM golden_records_dedup

  UNION ALL

  -- Magasins uniques (pas de doublon détecté)
  SELECT
    magasin_id,
    nom_magasin,
    latitude,
    longitude,
    source_system,
    sources_merged,
    loaded_at,
    is_merged_record,
    merge_name_similarity,
    merge_distance_km,
    original_th_id,
    original_gi_id
  FROM non_duplicates
)

SELECT * FROM final
