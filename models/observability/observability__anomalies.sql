{{
    config(
        materialized='view',
        tags=['observability', 'anomalies']
    )
}}

WITH dim_magasin AS (
    SELECT * FROM {{ ref('dim_magasin') }}
    WHERE is_current = TRUE
),

volumetry_stats AS (
    SELECT
        source_system,
        COUNT(*) AS record_count,
        AVG(COUNT(*)) OVER () AS avg_record_count,
        STDDEV(COUNT(*)) OVER () AS stddev_record_count
    FROM dim_magasin
    GROUP BY source_system
),

volumetry_anomalies AS (
    SELECT
        'volumetry' AS anomaly_type,
        source_system,
        record_count,
        avg_record_count,
        stddev_record_count,

        -- Détection anomalie (> 2 écarts-types)
        CASE
            WHEN ABS(record_count - avg_record_count) >
                2 * COALESCE(stddev_record_count, 0)
                THEN TRUE
            ELSE FALSE
        END AS is_anomaly,

        CURRENT_TIMESTAMP() AS detected_at

    FROM volumetry_stats
),

quality_anomalies AS (
    SELECT
        'quality' AS anomaly_type,
        source_system,
        COUNT(*) AS total_records,

        -- Taux de coordonnées invalides
        ROUND(
            100.0 * SUM(
                CASE WHEN coords_dans_plage_france = FALSE THEN 1 ELSE 0 END
            ) / NULLIF(COUNT(*), 0),
            2
        ) AS coords_invalid_pct,

        -- Seuil d'alerte : > 10% invalides
        CASE
            WHEN ROUND(
                100.0 * SUM(
                    CASE WHEN coords_dans_plage_france = FALSE THEN 1 ELSE 0 END
                ) / NULLIF(COUNT(*), 0),
                2
            ) > 10.0 THEN TRUE
            ELSE FALSE
        END AS is_anomaly,

        CURRENT_TIMESTAMP() AS detected_at

    FROM dim_magasin
    GROUP BY source_system
),

combined_anomalies AS (
    SELECT
        anomaly_type,
        source_system,
        record_count AS metric_value,
        avg_record_count,
        stddev_record_count,
        NULL AS coords_invalid_pct,
        is_anomaly,
        detected_at
    FROM volumetry_anomalies

    UNION ALL

    SELECT
        anomaly_type,
        source_system,
        total_records AS metric_value,
        NULL AS avg_record_count,
        NULL AS stddev_record_count,
        coords_invalid_pct,
        is_anomaly,
        detected_at
    FROM quality_anomalies
)

SELECT * FROM combined_anomalies
WHERE is_anomaly = TRUE
