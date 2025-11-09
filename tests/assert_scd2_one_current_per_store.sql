-- Test: Ensure only one current version per store in SCD Type 2
-- Description: Each combination of (magasin_id, source_system) should have
--              exactly ONE record with is_current = TRUE
-- Severity: error (critical data integrity)

WITH current_counts AS (
    SELECT
        magasin_id,
        source_system,
        COUNT(*) AS current_count
    FROM {{ ref('dim_magasin') }}
    WHERE is_current = TRUE
    GROUP BY magasin_id, source_system
    HAVING COUNT(*) > 1
)

-- This test fails if any store has more than one current version
SELECT *
FROM current_counts
