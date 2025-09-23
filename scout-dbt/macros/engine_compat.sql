-- Engine-portable macros for cross-platform compatibility

{% macro current_timestamp_tz() -%}
  {%- if target.type in ['postgres', 'postgresql'] -%}
    CURRENT_TIMESTAMP
  {%- elif target.type == 'sqlserver' -%}
    SYSDATETIMEOFFSET()
  {%- else -%}
    CURRENT_TIMESTAMP
  {%- endif -%}
{%- endmacro %}

{% macro json_extract(obj, path) -%}
  {%- if target.type in ['postgres', 'postgresql'] -%}
    {{ obj }}::jsonb #>> '{{"{{" }}{{ path.split('.') | join(',') }}{{ "}}" }}'
  {%- elif target.type == 'sqlserver' -%}
    JSON_VALUE({{ obj }}, '$.{{ path }}')
  {%- endif -%}
{%- endmacro %}

{% macro json_get(obj, key) -%}
  {%- if target.type in ['postgres', 'postgresql'] -%}
    {{ obj }}->>'{{ key }}'
  {%- elif target.type == 'sqlserver' -%}
    JSON_VALUE({{ obj }}, '$.{{ key }}')
  {%- endif -%}
{%- endmacro %}

{% macro date_trunc_day(column) -%}
  {%- if target.type in ['postgres', 'postgresql'] -%}
    DATE_TRUNC('day', {{ column }})
  {%- elif target.type == 'sqlserver' -%}
    CAST({{ column }} AS DATE)
  {%- endif -%}
{%- endmacro %}

{% macro date_trunc_month(column) -%}
  {%- if target.type in ['postgres', 'postgresql'] -%}
    DATE_TRUNC('month', {{ column }})
  {%- elif target.type == 'sqlserver' -%}
    DATEFROMPARTS(YEAR({{ column }}), MONTH({{ column }}), 1)
  {%- endif -%}
{%- endmacro %}

{% macro md5_hash(columns) -%}
  {%- if target.type in ['postgres', 'postgresql'] -%}
    MD5(CONCAT({{ columns | join(', ') }}))
  {%- elif target.type == 'sqlserver' -%}
    CONVERT(VARCHAR(32), HASHBYTES('MD5', CONCAT({{ columns | join(', ') }})), 2)
  {%- endif -%}
{%- endmacro %}

{% macro validate_coordinates(lat, lon) -%}
  {%- if target.type in ['postgres', 'postgresql'] -%}
  CASE
    WHEN {{ lat }} IS NULL OR {{ lon }} IS NULL THEN FALSE
    WHEN {{ lat }} < {{ var('ncr_lat_min') }} OR {{ lat }} > {{ var('ncr_lat_max') }} THEN FALSE
    WHEN {{ lon }} < {{ var('ncr_lon_min') }} OR {{ lon }} > {{ var('ncr_lon_max') }} THEN FALSE
    ELSE TRUE
  END
  {%- elif target.type == 'sqlserver' -%}
  CASE
    WHEN {{ lat }} IS NULL OR {{ lon }} IS NULL THEN 0
    WHEN {{ lat }} < {{ var('ncr_lat_min') }} OR {{ lat }} > {{ var('ncr_lat_max') }} THEN 0
    WHEN {{ lon }} < {{ var('ncr_lon_min') }} OR {{ lon }} > {{ var('ncr_lon_max') }} THEN 0
    ELSE 1
  END
  {%- endif -%}
{%- endmacro %}

{% macro create_index(table_name, columns, unique=false) -%}
  {%- if target.type in ['postgres', 'postgresql'] -%}
    CREATE {% if unique %}UNIQUE {% endif %}INDEX IF NOT EXISTS idx_{{ table_name }}_{{ columns | join('_') }}
    ON {{ table_name }} ({{ columns | join(', ') }});
  {%- elif target.type == 'sqlserver' -%}
    IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_{{ table_name }}_{{ columns | join('_') }}')
    CREATE {% if unique %}UNIQUE {% endif %}INDEX idx_{{ table_name }}_{{ columns | join('_') }}
    ON {{ table_name }} ({{ columns | join(', ') }});
  {%- endif -%}
{%- endmacro %}
