-- Test: Ensure all source stores are present in dimension
-- Description: Verify that every store from staging appears in dim_magasin
--              with is_current = TRUE
-- Severity: error (critical data completeness)

WITH source_stores AS (
    SELECT DISTINCT
        magasin_id,
        source_system
    FROM {{ ref('int_magasins_merged') }}
),

dim_current_stores AS (
    SELECT DISTINCT
        magasin_id,
        source_system
    FROM {{ ref('dim_magasin') }}
    WHERE is_current = TRUE
),

missing_stores AS (
    SELECT
        s.magasin_id,
        s.source_system
    FROM source_stores AS s
    LEFT JOIN dim_current_stores AS d
        ON s.magasin_id = d.magasin_id
        AND s.source_system = d.source_system
    WHERE d.magasin_id IS NULL
)

-- This test fails if any source store is missing from dimension
SELECT *
FROM missing_stores
