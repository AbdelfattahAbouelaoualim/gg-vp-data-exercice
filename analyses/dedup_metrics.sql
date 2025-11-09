-- Métriques de dédoublonnage avec correction GPS

SELECT
  COUNT(*) as total_stores,
  COUNT(CASE WHEN is_merged_record THEN 1 END) as golden_records,
  COUNT(CASE WHEN is_merged_record = FALSE THEN 1 END) as unique_stores,
  ROUND(COUNT(CASE WHEN is_merged_record THEN 1 END) * 100.0 / COUNT(*), 2) as pct_duplicates,

  -- Calcul réduction vs total original (TH + GI)
  -- Source: TH = 186,992 + GI = 33,841 = 220,833 total
  220833 - COUNT(*) as stores_removed,
  ROUND((220833 - COUNT(*)) * 100.0 / 220833, 2) as pct_reduction
FROM {{ ref('int_magasins_fuzzy_dedup') }}
