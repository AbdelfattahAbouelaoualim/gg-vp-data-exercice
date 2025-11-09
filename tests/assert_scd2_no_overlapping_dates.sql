-- Test: Ensure no overlapping validity periods in SCD Type 2
-- Description: For each store, valid_from/valid_to periods should never overlap
-- Severity: error (critical data integrity)

WITH dim_with_periods AS (
    SELECT
        magasin_id,
        source_system,
        valid_from,
        COALESCE(valid_to, '9999-12-31'::TIMESTAMP) AS valid_to_adjusted
    FROM {{ ref('dim_magasin') }}
),

overlaps AS (
    SELECT
        a.magasin_id,
        a.source_system,
        a.valid_from AS period1_start,
        a.valid_to_adjusted AS period1_end,
        b.valid_from AS period2_start,
        b.valid_to_adjusted AS period2_end
    FROM dim_with_periods AS a
    INNER JOIN dim_with_periods AS b
        ON a.magasin_id = b.magasin_id
        AND a.source_system = b.source_system
        AND a.valid_from != b.valid_from  -- Different records
    WHERE
        -- Check for overlap: period1 overlaps period2
        a.valid_from < b.valid_to_adjusted
        AND b.valid_from < a.valid_to_adjusted
)

-- This test fails if any overlapping periods exist
SELECT *
FROM overlaps
