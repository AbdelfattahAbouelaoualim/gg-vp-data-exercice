{{ config(
    materialized='table',
    schema='intermediate',
    tags=['intermediate', 'geo_validation', 'quality'],
    cluster_by=['source_system', 'code_insee_from_name']
) }}

/*
Validation et correction des coordonnées GPS via référentiel INSEE.

Problème identifié : Certains magasins ont des coords GPS erronées
  Exemple : "FNAC MONTPARNASSE" (Paris) avec coords de Montpellier

Solution : Matcher le nom du magasin avec communes INSEE
  1. Extraire ville du nom (regex)
  2. Fuzzy match avec référentiel communes
  3. Comparer GPS déclaré vs GPS attendu (centre commune)
  4. Corriger si distance > seuils

Seuils de validation :
  - CRITIQUE (>50 km) : Erreur majeure certaine → correction automatique
  - MAJEURE (>10 km)  : Probablement mauvaise ville → correction + flag
  - MINEURE (>1 km)   : Peut-être périphérie → flag seulement
  - OK (≤1 km)        : Coordonnées cohérentes
*/

WITH magasins_source AS (
  SELECT * FROM {{ ref('int_magasins_merged') }}
),

communes AS (
  SELECT
    code_insee,
    nom_standard,
    code_postal,
    dep_code,
    dep_nom,
    reg_code,
    reg_nom,
    latitude_centre,
    longitude_centre
  FROM {{ ref('communes-france-2025') }}
  WHERE latitude_centre IS NOT NULL
    AND longitude_centre IS NOT NULL
),

-- Étape 1 : Extraire la ville du nom du magasin
magasins_with_city AS (
  SELECT
    m.*,
    {{ extract_city_from_name('m.nom_magasin') }} as ville_extraite
  FROM magasins_source m
),

-- Étape 2 : Trouver la commune la plus similaire (par nom)
magasins_matched_by_name AS (
  SELECT
    m.magasin_id,
    m.nom_magasin,
    m.latitude as latitude_originale,
    m.longitude as longitude_originale,
    m.source_system,
    m.loaded_at,
    m.coords_dans_plage_france,
    m.coords_arrondies,
    m.ville_extraite,

    -- Meilleure commune par similarité de nom
    FIRST_VALUE(c.code_insee) OVER (
      PARTITION BY m.magasin_id
      ORDER BY
        {{ text_similarity('m.ville_extraite', 'c.nom_standard') }} DESC,
        {{ haversine_distance('m.latitude', 'm.longitude', 'c.latitude_centre', 'c.longitude_centre') }} ASC
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) as code_insee_from_name,

    FIRST_VALUE(c.nom_standard) OVER (
      PARTITION BY m.magasin_id
      ORDER BY
        {{ text_similarity('m.ville_extraite', 'c.nom_standard') }} DESC,
        {{ haversine_distance('m.latitude', 'm.longitude', 'c.latitude_centre', 'c.longitude_centre') }} ASC
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) as commune_nom_from_name,

    FIRST_VALUE(c.latitude_centre) OVER (
      PARTITION BY m.magasin_id
      ORDER BY
        {{ text_similarity('m.ville_extraite', 'c.nom_standard') }} DESC,
        {{ haversine_distance('m.latitude', 'm.longitude', 'c.latitude_centre', 'c.longitude_centre') }} ASC
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) as lat_insee_from_name,

    FIRST_VALUE(c.longitude_centre) OVER (
      PARTITION BY m.magasin_id
      ORDER BY
        {{ text_similarity('m.ville_extraite', 'c.nom_standard') }} DESC,
        {{ haversine_distance('m.latitude', 'm.longitude', 'c.latitude_centre', 'c.longitude_centre') }} ASC
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) as lon_insee_from_name,

    FIRST_VALUE(c.dep_code) OVER (
      PARTITION BY m.magasin_id
      ORDER BY
        {{ text_similarity('m.ville_extraite', 'c.nom_standard') }} DESC,
        {{ haversine_distance('m.latitude', 'm.longitude', 'c.latitude_centre', 'c.longitude_centre') }} ASC
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) as dep_code_from_name,

    -- Similarité nom (pour diagnostique)
    FIRST_VALUE(
      {{ text_similarity('m.ville_extraite', 'c.nom_standard') }}
    ) OVER (
      PARTITION BY m.magasin_id
      ORDER BY
        {{ text_similarity('m.ville_extraite', 'c.nom_standard') }} DESC,
        {{ haversine_distance('m.latitude', 'm.longitude', 'c.latitude_centre', 'c.longitude_centre') }} ASC
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) as similarity_ville_commune

  FROM magasins_with_city m
  CROSS JOIN communes c
  WHERE
    -- Pré-filtrage : similarité minimale ou proximité GPS
    {{ text_similarity('m.ville_extraite', 'c.nom_standard') }} > 0.5
    OR {{ haversine_distance('m.latitude', 'm.longitude', 'c.latitude_centre', 'c.longitude_centre') }} < 50
),

-- Étape 3 : Dédupliquer (FIRST_VALUE crée des duplicatas)
magasins_matched_dedup AS (
  SELECT DISTINCT
    magasin_id,
    nom_magasin,
    latitude_originale,
    longitude_originale,
    source_system,
    loaded_at,
    coords_dans_plage_france,
    coords_arrondies,
    ville_extraite,
    code_insee_from_name,
    commune_nom_from_name,
    lat_insee_from_name,
    lon_insee_from_name,
    dep_code_from_name,
    similarity_ville_commune
  FROM magasins_matched_by_name
),

-- Étape 4 : Trouver la commune la plus proche (par GPS)
magasins_matched_by_gps AS (
  SELECT
    m.*,

    -- Meilleure commune par proximité GPS
    FIRST_VALUE(c.code_insee) OVER (
      PARTITION BY m.magasin_id
      ORDER BY {{ haversine_distance('m.latitude_originale', 'm.longitude_originale', 'c.latitude_centre', 'c.longitude_centre') }} ASC
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) as code_insee_from_gps,

    FIRST_VALUE(c.nom_standard) OVER (
      PARTITION BY m.magasin_id
      ORDER BY {{ haversine_distance('m.latitude_originale', 'm.longitude_originale', 'c.latitude_centre', 'c.longitude_centre') }} ASC
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) as commune_nom_from_gps,

    -- Distance entre GPS déclaré et centre commune (trouvée par nom)
    {{ haversine_distance('m.latitude_originale', 'm.longitude_originale', 'm.lat_insee_from_name', 'm.lon_insee_from_name') }} as distance_gps_vs_commune

  FROM magasins_matched_dedup m
  CROSS JOIN communes c
  WHERE {{ haversine_distance('m.latitude_originale', 'm.longitude_originale', 'c.latitude_centre', 'c.longitude_centre') }} < 100
),

magasins_gps_dedup AS (
  SELECT DISTINCT
    magasin_id,
    nom_magasin,
    latitude_originale,
    longitude_originale,
    source_system,
    loaded_at,
    coords_dans_plage_france,
    coords_arrondies,
    ville_extraite,
    code_insee_from_name,
    commune_nom_from_name,
    lat_insee_from_name,
    lon_insee_from_name,
    dep_code_from_name,
    similarity_ville_commune,
    code_insee_from_gps,
    commune_nom_from_gps,
    distance_gps_vs_commune
  FROM magasins_matched_by_gps
),

-- Étape 5 : Validation et correction
final AS (
  SELECT
    magasin_id,
    nom_magasin,
    latitude_originale,
    longitude_originale,
    source_system,
    loaded_at,
    coords_dans_plage_france,
    coords_arrondies,

    -- Métadonnées extraction
    ville_extraite,
    code_insee_from_name,
    commune_nom_from_name,
    code_insee_from_gps,
    commune_nom_from_gps,
    dep_code_from_name,
    similarity_ville_commune,
    distance_gps_vs_commune,

    -- Niveau d'anomalie
    CASE
      WHEN distance_gps_vs_commune > 50 THEN 'CRITIQUE'
      WHEN distance_gps_vs_commune > 10 THEN 'MAJEURE'
      WHEN distance_gps_vs_commune > 1 THEN 'MINEURE'
      ELSE 'OK'
    END as niveau_anomalie_gps,

    -- Flag : INSEE et GPS désaccord
    CASE
      WHEN code_insee_from_name != code_insee_from_gps THEN TRUE
      ELSE FALSE
    END as coords_incoherentes,

    -- Coordonnées corrigées (stratégie adaptative)
    CASE
      -- Erreur critique : utiliser coords INSEE
      WHEN distance_gps_vs_commune > 50 THEN lat_insee_from_name
      -- Erreur majeure : utiliser coords INSEE
      WHEN distance_gps_vs_commune > 10 THEN lat_insee_from_name
      -- Sinon : garder originales
      ELSE latitude_originale
    END as latitude_corrigee,

    CASE
      WHEN distance_gps_vs_commune > 50 THEN lon_insee_from_name
      WHEN distance_gps_vs_commune > 10 THEN lon_insee_from_name
      ELSE longitude_originale
    END as longitude_corrigee,

    -- Flag correction appliquée
    CASE
      WHEN distance_gps_vs_commune > 10 THEN TRUE
      ELSE FALSE
    END as coords_corrigees

  FROM magasins_gps_dedup
)

SELECT * FROM final
