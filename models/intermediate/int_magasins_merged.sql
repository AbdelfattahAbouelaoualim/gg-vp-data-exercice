{{
    config(
        materialized='view',
        tags=['intermediate']
    )
}}

WITH th_magasins AS (
    SELECT * FROM {{ ref('stg_th_magasins') }}
),

gi_magasins AS (
    SELECT * FROM {{ ref('stg_gi_magasins') }}
),

merged AS (
    SELECT * FROM th_magasins
    UNION ALL
    SELECT * FROM gi_magasins
)

SELECT * FROM merged
