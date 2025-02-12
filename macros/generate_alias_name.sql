{% macro generate_alias_name(custom_alias_name=none, node=none) -%}

    {%- if custom_alias_name -%}
        {%- if custom_alias_name.startswith('_') and target.type == 'athena' -%}

            {{ log(custom_alias_name ~ '->' ~ custom_alias_name[1:],True) }}
            {{ custom_alias_name[1:] }}
        {%- else -%}
            {{ custom_alias_name | trim }}
        {%- endif -%}

    {%- elif node.version -%}

        {{ return(node.name ~ "_v" ~ (node.version | replace(".", "_"))) }}

    {%- else -%}
        {%- if node.name.startswith('_') and target.type == 'athena' -%}
            {{ log(node.name ~ '->' ~ node.name[1:],True) }}
            {{ node.name[1:] }}
        {%- else -%}
            {{ node.name }}
        {%- endif -%}

    {%- endif -%}

{%- endmacro %}

