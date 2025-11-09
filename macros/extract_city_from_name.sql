{% macro extract_city_from_name(store_name) %}
    {#
        Extrait le nom de ville d'un nom de magasin.

        Patterns courants :
        - "FNAC - PARIS MONTPARNASSE" → "PARIS"
        - "AUCHAN MONTPELLIER" → "MONTPELLIER"
        - "BOULANGER - LILLE - CENTRE" → "LILLE"
        - "CARREFOUR ST-ETIENNE" → "ST-ETIENNE" ou "SAINT-ETIENNE"

        Args:
            store_name: Nom du magasin (colonne SQL)

        Returns:
            Ville extraite (VARCHAR) ou NULL si non trouvée
    #}
    CASE
        -- Pattern 1: "MARQUE - VILLE ..." (le plus commun)
        WHEN REGEXP_LIKE({{ store_name }}, '- ([A-ZÀ-ÿ][A-ZÀ-ÿ \\-'']+)') THEN
            UPPER(TRIM(REGEXP_SUBSTR({{ store_name }}, '- ([A-ZÀ-ÿ][A-ZÀ-ÿ \\-'']+)', 1, 1, 'e', 1)))

        -- Pattern 2: "MARQUE VILLE" (sans tiret)
        WHEN REGEXP_LIKE({{ store_name }}, '^[A-Z]+ ([A-ZÀ-ÿ][A-ZÀ-ÿ \\-'']+)$') THEN
            UPPER(TRIM(REGEXP_SUBSTR({{ store_name }}, '^[A-Z]+ ([A-ZÀ-ÿ][A-ZÀ-ÿ \\-'']+)$', 1, 1, 'e', 1)))

        -- Pattern 3: Derniers mots (fallback)
        WHEN REGEXP_LIKE({{ store_name }}, '([A-ZÀ-ÿ][A-ZÀ-ÿ \\-'']+)$') THEN
            UPPER(TRIM(REGEXP_SUBSTR({{ store_name }}, '([A-ZÀ-ÿ][A-ZÀ-ÿ \\-'']+)$', 1, 1, 'e', 1)))

        ELSE NULL
    END
{% endmacro %}
