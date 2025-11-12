{{
    config(
        materialized='incremental',
        unique_key='magasin_key',
        tags=['marts', 'scd_type_2']
    )
}}

WITH source_data AS (
    SELECT
        magasin_id,
        nom_magasin,
        latitude,
        longitude,
        source_system,
        commune_nom,
        code_postal,
        dep_nom,
        reg_nom,
        coords_dans_plage_france,
        match_fiable,
        coords_correction_requise,
        loaded_at
    FROM {{ ref('int_magasins_augmented') }}
)

{% if is_incremental() %}

,

-- Identifier les changements
changes AS (
    SELECT
        s.magasin_id,
        s.source_system,
        s.nom_magasin,
        s.latitude,
        s.longitude,
        s.commune_nom,
        s.code_postal,
        s.dep_nom,
        s.reg_nom,
        s.coords_dans_plage_france,
        s.match_fiable,
        s.coords_correction_requise,
        s.loaded_at,

        -- Vérifier si le magasin existe et a changé
        CASE
            WHEN t.magasin_id IS NULL THEN 'INSERT'
            WHEN
                t.nom_magasin != s.nom_magasin
                OR t.latitude != s.latitude
                OR t.longitude != s.longitude
                OR t.coords_dans_plage_france != s.coords_dans_plage_france
            THEN 'UPDATE'
            ELSE 'NO_CHANGE'
        END AS change_type,

        t.magasin_key AS existing_key

    FROM source_data AS s
    LEFT JOIN {{ this }} AS t
        ON s.magasin_id = t.magasin_id
        AND s.source_system = t.source_system
        AND t.is_current = TRUE
),

-- Clore les anciennes versions (UPDATE)
close_old_versions AS (
    SELECT
        t.magasin_key,
        t.magasin_id,
        t.nom_magasin,
        t.latitude,
        t.longitude,
        t.source_system,
        t.commune_nom,
        t.code_postal,
        t.dep_nom,
        t.reg_nom,
        t.coords_dans_plage_france,
        t.match_fiable,
        t.coords_correction_requise,
        t.valid_from,
        CURRENT_TIMESTAMP() AS valid_to,
        FALSE AS is_current

    FROM {{ this }} AS t
    INNER JOIN changes AS c
        ON t.magasin_id = c.magasin_id
        AND t.source_system = c.source_system
        AND t.is_current = TRUE
    WHERE c.change_type = 'UPDATE'
),

-- Nouvelles versions (INSERT + UPDATE)
new_versions AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key([
            'magasin_id',
            'source_system',
            'CURRENT_TIMESTAMP()'
        ]) }} AS magasin_key,
        magasin_id,
        nom_magasin,
        latitude,
        longitude,
        source_system,
        commune_nom,
        code_postal,
        dep_nom,
        reg_nom,
        coords_dans_plage_france,
        match_fiable,
        coords_correction_requise,
        CURRENT_TIMESTAMP() AS valid_from,
        NULL AS valid_to,
        TRUE AS is_current

    FROM changes
    WHERE change_type IN ('INSERT', 'UPDATE')
),

-- Combiner toutes les modifications
final_incremental AS (
    SELECT * FROM close_old_versions
    UNION ALL
    SELECT * FROM new_versions
)

SELECT * FROM final_incremental

{% else %}

-- Chargement initial complet
SELECT
    {{ dbt_utils.generate_surrogate_key([
        'magasin_id',
        'source_system',
        'CURRENT_TIMESTAMP()'
    ]) }} AS magasin_key,
    magasin_id,
    nom_magasin,
    latitude,
    longitude,
    source_system,
    commune_nom,
    code_postal,
    dep_nom,
    reg_nom,
    coords_dans_plage_france,
    match_fiable,
    coords_correction_requise,
    CURRENT_TIMESTAMP() AS valid_from,
    NULL AS valid_to,
    TRUE AS is_current

FROM source_data

{% endif %}
