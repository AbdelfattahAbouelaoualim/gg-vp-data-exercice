{% macro generate_schema_name(custom_schema_name, node) -%}
    {#- Si un schema custom est spécifié, on l'utilise directement sans concaténation -#}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
