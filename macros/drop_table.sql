{% macro drop_table(schema_name, table_name) %}
    {% set query %}
        DROP TABLE IF EXISTS {{ target.database }}.{{ schema_name }}.{{ table_name }}
    {% endset %}
    {% set result = run_query(query) %}
    {{ log("Table supprimée: " ~ target.database ~ "." ~ schema_name ~ "." ~ table_name, info=True) }}
{% endmacro %}
