{{
    config(
        materialized='view',
        tags=['staging', 'gi']
    )
}}

WITH source AS (
    SELECT * FROM {{ source('gi', 'magasins') }}
),

normalized AS (
    SELECT
        -- Identifiants
        id AS magasin_id,
        name AS nom_magasin,

        -- Coordonnées GPS (CAST NUMBER vers FLOAT)
        CAST(latitude AS FLOAT) AS latitude,
        CAST(longitude AS FLOAT) AS longitude,

        -- Métadonnées
        'GI' AS source_system,
        CURRENT_TIMESTAMP() AS loaded_at

    FROM source
    WHERE
        -- Filtrage des 7 magasins avec coordonnées NULL
        latitude IS NOT NULL
        AND longitude IS NOT NULL
),

with_quality_flags AS (
    SELECT
        *,

        -- Flag coordonnées hors plages valides (France)
        CASE
            WHEN latitude < 41.0 OR latitude > 51.5 THEN FALSE
            WHEN longitude < -5.5 OR longitude > 10.0 THEN FALSE
            ELSE TRUE
        END AS coords_dans_plage_france,

        -- Flag coordonnées arrondies (suspectes)
        (
            latitude = ROUND(latitude, 0)
            OR longitude = ROUND(longitude, 0)
        ) AS coords_arrondies

    FROM normalized
)

SELECT * FROM with_quality_flags
