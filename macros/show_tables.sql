{% macro show_tables(schema_name) %}
    {% set query %}
        SHOW TABLES IN {{ target.database }}.{{ schema_name }}
    {% endset %}
    {% do run_query(query) %}
    {{ log("Tables listées dans " ~ target.database ~ "." ~ schema_name, info=True) }}
{% endmacro %}
