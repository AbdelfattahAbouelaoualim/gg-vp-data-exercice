{{
    config(
        materialized='view',
        tags=['intermediate', 'enrichissement']
    )
}}

WITH magasins AS (
    -- Utilise le modèle dédoublonné avec matching fuzzy TH vs GI
    SELECT * FROM {{ ref('int_magasins_fuzzy_dedup') }}
),

communes AS (
    SELECT
        code_insee,
        nom_standard,
        code_postal,
        dep_code,
        dep_nom,
        reg_code,
        reg_nom,
        latitude_centre,
        longitude_centre
    FROM {{ ref('communes-france-2025') }}
    WHERE
        latitude_centre IS NOT NULL
        AND longitude_centre IS NOT NULL
),

magasins_with_best_match AS (
    SELECT
        m.magasin_id,
        m.nom_magasin,
        m.latitude,
        m.longitude,
        m.source_system,
        m.sources_merged,  -- Nouvelle colonne du fuzzy dedup
        m.loaded_at,
        m.is_merged_record,  -- Flag si c'est un golden record
        m.merge_name_similarity,  -- Similarité du merge TH-GI
        m.merge_distance_km,  -- Distance du merge TH-GI
        m.original_th_id,
        m.original_gi_id,

        -- Meilleur match commune (par similarité de nom)
        FIRST_VALUE(c.code_insee) OVER (
            PARTITION BY m.magasin_id
            ORDER BY
                {{ text_similarity('m.nom_magasin', 'c.nom_standard') }} DESC,
                {{ haversine_distance(
                    'm.latitude',
                    'm.longitude',
                    'c.latitude_centre',
                    'c.longitude_centre'
                ) }} ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS matched_code_insee,

        -- Score de similarité du meilleur match
        FIRST_VALUE(
            {{ text_similarity('m.nom_magasin', 'c.nom_standard') }}
        ) OVER (
            PARTITION BY m.magasin_id
            ORDER BY
                {{ text_similarity('m.nom_magasin', 'c.nom_standard') }} DESC,
                {{ haversine_distance(
                    'm.latitude',
                    'm.longitude',
                    'c.latitude_centre',
                    'c.longitude_centre'
                ) }} ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS similarity_score,

        -- Distance du meilleur match
        FIRST_VALUE(
            {{ haversine_distance(
                'm.latitude',
                'm.longitude',
                'c.latitude_centre',
                'c.longitude_centre'
            ) }}
        ) OVER (
            PARTITION BY m.magasin_id
            ORDER BY
                {{ text_similarity('m.nom_magasin', 'c.nom_standard') }} DESC,
                {{ haversine_distance(
                    'm.latitude',
                    'm.longitude',
                    'c.latitude_centre',
                    'c.longitude_centre'
                ) }} ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS distance_km,

        -- Détection coordonnées dans plage France métropolitaine
        CASE
            WHEN m.latitude BETWEEN 41.0 AND 51.5
                AND m.longitude BETWEEN -5.5 AND 10.0
            THEN TRUE
            ELSE FALSE
        END AS coords_dans_plage_france,

        -- Détection coordonnées arrondies (GPS imprécis)
        CASE
            WHEN (m.latitude * 1000) % 10 = 0 OR (m.longitude * 1000) % 10 = 0
            THEN TRUE
            ELSE FALSE
        END AS coords_arrondies

    FROM magasins AS m
    CROSS JOIN communes AS c
    WHERE
        -- Filtre préliminaire : similitude minimale
        {{ text_similarity('m.nom_magasin', 'c.nom_standard') }} > 0.3
),

deduplicated AS (
    SELECT DISTINCT
        magasin_id,
        nom_magasin,
        latitude,
        longitude,
        source_system,
        sources_merged,
        loaded_at,
        is_merged_record,
        merge_name_similarity,
        merge_distance_km,
        original_th_id,
        original_gi_id,
        coords_dans_plage_france,
        coords_arrondies,
        matched_code_insee,
        similarity_score,
        distance_km
    FROM magasins_with_best_match
),

enriched AS (
    SELECT
        d.*,

        -- Enrichissement avec m�tadonn�es communes
        c.nom_standard AS commune_nom,
        c.code_postal,
        c.dep_code,
        c.dep_nom,
        c.reg_code,
        c.reg_nom,
        c.latitude_centre AS commune_latitude,
        c.longitude_centre AS commune_longitude,

        -- Validation cohérence GPS
        (
            d.similarity_score >= 0.7 AND d.distance_km <= 50
        ) AS match_fiable,

        -- Flag correction nécessaire
        (d.distance_km > 50) AS coords_correction_requise

    FROM deduplicated AS d
    LEFT JOIN communes AS c
        ON d.matched_code_insee = c.code_insee
)

SELECT * FROM enriched
