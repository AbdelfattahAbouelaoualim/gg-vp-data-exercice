-- Simple query to get all metrics in readable format

SELECT
  -- Métriques générales
  COUNT(*) as total_stores,
  COUNT(CASE WHEN is_merged_record THEN 1 END) as golden_records,
  COUNT(CASE WHEN is_merged_record = FALSE THEN 1 END) as unique_stores,

  -- Réduction
  220833 - COUNT(*) as stores_removed,

  -- Qualité des doublons détectés
  ROUND(AVG(CASE WHEN is_merged_record THEN merge_name_similarity END), 3) as avg_name_sim,
  ROUND(AVG(CASE WHEN is_merged_record THEN merge_distance_km END), 3) as avg_distance_km,
  ROUND(MAX(CASE WHEN is_merged_record THEN merge_distance_km END), 3) as max_distance_km,

  -- Distribution par distance (indicateur qualité GPS)
  COUNT(CASE WHEN is_merged_record AND merge_distance_km <= 0.1 THEN 1 END) as dup_0_100m,
  COUNT(CASE WHEN is_merged_record AND merge_distance_km BETWEEN 0.1 AND 0.3 THEN 1 END) as dup_100_300m,
  COUNT(CASE WHEN is_merged_record AND merge_distance_km > 0.3 THEN 1 END) as dup_300_500m

FROM {{ ref('int_magasins_fuzzy_dedup') }}
