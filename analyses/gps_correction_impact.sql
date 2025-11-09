-- Analyse de l'impact de la correction GPS sur le dédoublonnage

WITH duplicate_analysis AS (
  SELECT
    -- Doublons par niveau d'anomalie GPS
    COUNT(CASE WHEN is_merged_record THEN 1 END) as total_duplicates,

    -- Quelle source a été corrigée dans les golden records ?
    -- (on ne peut pas savoir directement dans fuzzy_dedup, mais on peut analyser les patterns)

    -- Distribution des scores de similarité
    ROUND(AVG(CASE WHEN is_merged_record THEN merge_name_similarity END), 3) as avg_name_similarity,
    ROUND(MIN(CASE WHEN is_merged_record THEN merge_name_similarity END), 3) as min_name_similarity,
    ROUND(MAX(CASE WHEN is_merged_record THEN merge_name_similarity END), 3) as max_name_similarity,

    -- Distribution des distances GPS
    ROUND(AVG(CASE WHEN is_merged_record THEN merge_distance_km END), 3) as avg_distance_km,
    ROUND(MIN(CASE WHEN is_merged_record THEN merge_distance_km END), 3) as min_distance_km,
    ROUND(MAX(CASE WHEN is_merged_record THEN merge_distance_km END), 3) as max_distance_km,

    -- Doublons par plage de distance (indique qualité GPS)
    COUNT(CASE WHEN is_merged_record AND merge_distance_km <= 0.1 THEN 1 END) as duplicates_0_100m,
    COUNT(CASE WHEN is_merged_record AND merge_distance_km > 0.1 AND merge_distance_km <= 0.3 THEN 1 END) as duplicates_100_300m,
    COUNT(CASE WHEN is_merged_record AND merge_distance_km > 0.3 AND merge_distance_km <= 0.5 THEN 1 END) as duplicates_300_500m

  FROM {{ ref('int_magasins_fuzzy_dedup') }}
)

SELECT
  *,
  ROUND(duplicates_0_100m * 100.0 / total_duplicates, 2) as pct_very_close,
  ROUND(duplicates_100_300m * 100.0 / total_duplicates, 2) as pct_close,
  ROUND(duplicates_300_500m * 100.0 / total_duplicates, 2) as pct_far
FROM duplicate_analysis
