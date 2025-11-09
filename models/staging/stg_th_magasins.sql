{{
    config(
        materialized='view',
        tags=['staging', 'th']
    )
}}

WITH source AS (
    SELECT * FROM {{ source('th', 'magasins') }}
),

normalized AS (
    SELECT
        -- Identifiants
        id AS magasin_id,
        name AS nom_magasin,

        -- Coordonn�es GPS (d�j� en FLOAT)
        latitude,
        longitude,

        -- M�tadonn�es
        'TH' AS source_system,
        CURRENT_TIMESTAMP() AS loaded_at

    FROM source
    WHERE
        -- Filtrage des coordonn�es NULL
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
