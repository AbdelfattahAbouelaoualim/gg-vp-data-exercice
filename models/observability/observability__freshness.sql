{{
    config(
        materialized='view',
        tags=['observability', 'freshness']
    )
}}

WITH dim_magasin AS (
    SELECT * FROM {{ ref('dim_magasin') }}
    WHERE is_current = TRUE
),

freshness_metrics AS (
    SELECT
        'dim_magasin' AS table_name,
        CURRENT_TIMESTAMP() AS measured_at,

        -- Dernière mise à jour
        MAX(valid_from) AS last_updated_at,

        -- Ancienneté en heures
        DATEDIFF(
            'hour',
            MAX(valid_from),
            CURRENT_TIMESTAMP()
        ) AS age_hours,

        -- Ancienneté en jours
        DATEDIFF(
            'day',
            MAX(valid_from),
            CURRENT_TIMESTAMP()
        ) AS age_days,

        -- SLA respecté (<24h)
        CASE
            WHEN DATEDIFF('hour', MAX(valid_from), CURRENT_TIMESTAMP()) < 24
                THEN TRUE
            ELSE FALSE
        END AS sla_met

    FROM dim_magasin
),

freshness_by_source AS (
    SELECT
        'dim_magasin' AS table_name,
        source_system,
        CURRENT_TIMESTAMP() AS measured_at,

        -- Dernière mise à jour par source
        MAX(valid_from) AS last_updated_at,

        -- Ancienneté par source
        DATEDIFF(
            'hour',
            MAX(valid_from),
            CURRENT_TIMESTAMP()
        ) AS age_hours

    FROM dim_magasin
    GROUP BY source_system
),

combined AS (
    SELECT
        *,
        NULL AS source_system
    FROM freshness_metrics

    UNION ALL

    SELECT
        table_name,
        measured_at,
        last_updated_at,
        age_hours,
        NULL AS age_days,
        NULL AS sla_met,
        source_system
    FROM freshness_by_source
)

SELECT * FROM combined
