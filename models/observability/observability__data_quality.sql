{{
    config(
        materialized='view',
        tags=['observability', 'quality']
    )
}}

WITH dim_magasin AS (
    SELECT * FROM {{ ref('dim_magasin') }}
    WHERE is_current = TRUE
),

quality_metrics AS (
    SELECT
        'dim_magasin' AS table_name,
        CURRENT_TIMESTAMP() AS measured_at,

        -- Volumétrie
        COUNT(*) AS total_records,
        COUNT(DISTINCT magasin_id) AS distinct_magasins,
        COUNT(DISTINCT source_system) AS distinct_sources,

        -- Complétude (colonnes critiques)
        SUM(CASE WHEN magasin_id IS NULL THEN 1 ELSE 0 END) AS null_magasin_id,
        SUM(CASE WHEN nom_magasin IS NULL THEN 1 ELSE 0 END) AS null_nom_magasin,
        SUM(
            CASE WHEN latitude IS NULL THEN 1 ELSE 0 END
        ) AS null_latitude,
        SUM(
            CASE WHEN longitude IS NULL THEN 1 ELSE 0 END
        ) AS null_longitude,

        -- Cohérence GPS
        SUM(
            CASE WHEN coords_dans_plage_france = FALSE THEN 1 ELSE 0 END
        ) AS coords_hors_plage,
        SUM(
            CASE WHEN match_fiable = FALSE THEN 1 ELSE 0 END
        ) AS match_non_fiable,

        -- Taux de complétude (%)
        ROUND(
            100.0 * (COUNT(*) - SUM(
                CASE WHEN magasin_id IS NULL THEN 1 ELSE 0 END
            )) / NULLIF(COUNT(*), 0),
            2
        ) AS completeness_magasin_id_pct,

        ROUND(
            100.0 * (COUNT(*) - SUM(
                CASE WHEN nom_magasin IS NULL THEN 1 ELSE 0 END
            )) / NULLIF(COUNT(*), 0),
            2
        ) AS completeness_nom_magasin_pct,

        -- Taux de cohérence GPS (%)
        ROUND(
            100.0 * SUM(
                CASE WHEN coords_dans_plage_france = TRUE THEN 1 ELSE 0 END
            ) / NULLIF(COUNT(*), 0),
            2
        ) AS coords_valid_pct,

        -- Taux de match fiable (%)
        ROUND(
            100.0 * SUM(
                CASE WHEN match_fiable = TRUE THEN 1 ELSE 0 END
            ) / NULLIF(COUNT(*), 0),
            2
        ) AS match_fiable_pct

    FROM dim_magasin
),

quality_by_source AS (
    SELECT
        'dim_magasin' AS table_name,
        source_system,
        CURRENT_TIMESTAMP() AS measured_at,

        -- Volumétrie par source
        COUNT(*) AS total_records,

        -- Qualité GPS par source
        SUM(
            CASE WHEN coords_dans_plage_france = TRUE THEN 1 ELSE 0 END
        ) AS coords_valid,
        SUM(
            CASE WHEN coords_dans_plage_france = FALSE THEN 1 ELSE 0 END
        ) AS coords_invalid,

        ROUND(
            100.0 * SUM(
                CASE WHEN coords_dans_plage_france = TRUE THEN 1 ELSE 0 END
            ) / NULLIF(COUNT(*), 0),
            2
        ) AS coords_valid_pct

    FROM dim_magasin
    GROUP BY source_system
),

combined AS (
    SELECT
        *,
        NULL AS source_system
    FROM quality_metrics

    UNION ALL

    SELECT
        table_name,
        measured_at,
        total_records,
        NULL AS distinct_magasins,
        NULL AS distinct_sources,
        NULL AS null_magasin_id,
        NULL AS null_nom_magasin,
        NULL AS null_latitude,
        NULL AS null_longitude,
        NULL AS coords_hors_plage,
        NULL AS match_non_fiable,
        NULL AS completeness_magasin_id_pct,
        NULL AS completeness_nom_magasin_pct,
        coords_valid_pct,
        NULL AS match_fiable_pct,
        source_system
    FROM quality_by_source
)

SELECT * FROM combined
