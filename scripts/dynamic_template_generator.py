#!/usr/bin/env python3
"""
Dynamic SQL Template Generator for Scout Analytics
Generates SQL templates for any combination of dimensions on-demand
"""

import json
import os
from typing import Dict, List, Any, Optional
from pathlib import Path
from dimensional_matrix_generator import DimensionalMatrixGenerator, Dimension, DimensionCombination

class DynamicTemplateGenerator:
    """Generates SQL templates dynamically for any dimensional combination"""

    def __init__(self):
        self.matrix_generator = DimensionalMatrixGenerator()
        self.dimensions = {dim.name: dim for dim in self.matrix_generator.dimensions}
        self.base_template_dir = Path("/Users/tbwa/scout-v7/sql_templates")
        self.dynamic_template_dir = Path("/Users/tbwa/scout-v7/sql_templates/dynamic")
        self.dynamic_template_dir.mkdir(exist_ok=True)

    def generate_template_for_dimensions(self, dimension_names: List[str],
                                       template_name: Optional[str] = None) -> str:
        """Generate SQL template for specific combination of dimensions"""

        # Validate dimension names
        invalid_dims = [name for name in dimension_names if name not in self.dimensions]
        if invalid_dims:
            raise ValueError(f"Invalid dimension names: {invalid_dims}")

        # Get dimension objects
        dimensions = [self.dimensions[name] for name in dimension_names]

        # Create combination object
        combination = self.matrix_generator._create_dimension_combination(dimensions, len(dimensions))

        # Generate template name if not provided
        if not template_name:
            template_name = "_".join(dimension_names)

        # Generate enhanced SQL template
        sql_template = self._generate_enhanced_sql_template(combination, template_name)

        return sql_template

    def _generate_enhanced_sql_template(self, combination: DimensionCombination,
                                      template_name: str) -> str:
        """Generate enhanced SQL template with advanced analytics"""

        dimensions = combination.dimensions
        business_question = combination.business_question

        # Build dimension selections with aliases
        select_dims = []
        for dim in dimensions:
            if "CASE WHEN" in dim.column:
                # For calculated dimensions, use full expression
                select_dims.append(f"    {dim.column} AS {dim.name}")
            else:
                # For simple columns, use direct reference
                select_dims.append(f"    {dim.column} AS {dim.name}")

        select_clause = ",\n".join(select_dims)

        # Build GROUP BY clause (use column expressions, not aliases)
        group_by_dims = [dim.column for dim in dimensions]
        group_by_clause = ",\n    ".join(group_by_dims)

        # Build ORDER BY clause for ranking
        order_by_dims = [f"{dim.name}" for dim in dimensions]
        order_by_clause = ", ".join(order_by_dims)

        # Generate parameter definitions
        param_definitions = self._generate_parameter_definitions(dimensions)

        # Generate validation rules
        validation_rules = self._generate_validation_rules(dimensions)

        # Create comprehensive template
        template = f'''-- Template: {template_name}
-- Business Question: "{business_question}"
-- Dimensional Analysis: {' × '.join([dim.display_name for dim in dimensions])}
-- Combination Type: {len(dimensions)}-way cross-tabulation
-- Generated: 2025-09-22

{param_definitions}

WITH dimensional_base AS (
    SELECT
{select_clause},
        COUNT(*) AS transaction_count,
        SUM(total_price) AS total_revenue,
        AVG(total_price) AS avg_transaction_value,
        COUNT(DISTINCT productid) AS unique_products,
        COUNT(DISTINCT CAST(transactiondate AS date)) AS active_days,
        MIN(transactiondate) AS first_transaction,
        MAX(transactiondate) AS last_transaction,
        STDDEV(total_price) AS price_stddev
    FROM public.scout_gold_transactions_flat t
    WHERE t.transactiondate >= ${{date_from}}
      AND t.transactiondate <= ${{date_to}}
      AND t.latitude BETWEEN 14.0 AND 15.0  -- NCR bounds
      AND t.longitude BETWEEN 120.5 AND 121.5
      {{#store_filter}}AND t.storeid = ${{store_id}}{{/store_filter}}
      {{#category_filter}}AND t.category = '${{category}}'{{/category_filter}}
      {{#brand_filter}}AND t.brand = '${{brand}}'{{/brand_filter}}
      {{#payment_filter}}AND t.payment_method = '${{payment_method}}'{{/payment_filter}}
      {{#gender_filter}}AND t.gender = '${{gender}}'{{/gender_filter}}
      {{#age_filter}}AND t.agebracket = '${{agebracket}}'{{/age_filter}}
    GROUP BY
    {group_by_clause}
    HAVING COUNT(*) >= 1  -- Minimum transaction threshold
),
dimensional_metrics AS (
    SELECT *,
        -- Ranking metrics
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
        ROW_NUMBER() OVER (ORDER BY transaction_count DESC) AS volume_rank,
        ROW_NUMBER() OVER (ORDER BY avg_transaction_value DESC) AS value_rank,

        -- Share metrics
        ROUND(100.0 * total_revenue / SUM(total_revenue) OVER (), 2) AS revenue_share_pct,
        ROUND(100.0 * transaction_count / SUM(transaction_count) OVER (), 2) AS volume_share_pct,

        -- Performance metrics
        ROUND(total_revenue / active_days, 2) AS daily_avg_revenue,
        ROUND(transaction_count / active_days, 2) AS daily_avg_transactions,

        -- Efficiency metrics
        CASE
            WHEN avg_transaction_value > AVG(avg_transaction_value) OVER () THEN 'Above Average'
            WHEN avg_transaction_value < AVG(avg_transaction_value) OVER () THEN 'Below Average'
            ELSE 'Average'
        END AS value_tier
    FROM dimensional_base
),
dimensional_insights AS (
    SELECT *,
        -- Trend indicators
        CASE
            WHEN revenue_rank <= CEILING(COUNT(*) OVER () * 0.2) THEN 'Top 20%'
            WHEN revenue_rank <= CEILING(COUNT(*) OVER () * 0.5) THEN 'Top 50%'
            ELSE 'Bottom 50%'
        END AS performance_tier,

        -- Concentration analysis
        LAG(revenue_share_pct) OVER (ORDER BY revenue_rank) AS prev_revenue_share,
        LEAD(revenue_share_pct) OVER (ORDER BY revenue_rank) AS next_revenue_share

    FROM dimensional_metrics
)
SELECT
    -- Dimension columns
{select_clause},

    -- Core metrics
    transaction_count,
    total_revenue,
    avg_transaction_value,
    unique_products,
    active_days,

    -- Performance indicators
    revenue_rank,
    volume_rank,
    value_rank,
    revenue_share_pct,
    volume_share_pct,

    -- Business insights
    performance_tier,
    value_tier,
    daily_avg_revenue,
    daily_avg_transactions,

    -- Statistical measures
    price_stddev,
    first_transaction,
    last_transaction

FROM dimensional_insights
ORDER BY total_revenue DESC, {order_by_clause}
LIMIT ${{limit:=100}};

{validation_rules}'''

        return template

    def _generate_parameter_definitions(self, dimensions: List[Dimension]) -> str:
        """Generate parameter definitions section"""

        params = [
            "-- Parameters:",
            "-- ${{date_from}} - Start date (YYYY-MM-DD format)",
            "-- ${{date_to}} - End date (YYYY-MM-DD format)",
            "-- ${{limit}} - Maximum rows to return (default: 100)"
        ]

        # Add dimension-specific parameters
        for dim in dimensions:
            if "store" in dim.name.lower():
                params.append("-- ${{store_id}} - Optional store filter")
            elif "category" in dim.name.lower():
                params.append("-- ${{category}} - Optional category filter")
            elif "brand" in dim.name.lower():
                params.append("-- ${{brand}} - Optional brand filter")
            elif "payment" in dim.name.lower():
                params.append("-- ${{payment_method}} - Optional payment method filter")
            elif "gender" in dim.name.lower():
                params.append("-- ${{gender}} - Optional gender filter")
            elif "age" in dim.name.lower():
                params.append("-- ${{agebracket}} - Optional age bracket filter")

        return "\n".join(params) + "\n"

    def _generate_validation_rules(self, dimensions: List[Dimension]) -> str:
        """Generate validation rules section"""

        rules = [
            "",
            "-- Validation Rules:",
            "-- 1. Date range should not exceed 1 year for performance",
            "-- 2. Results are limited to NCR geographic bounds",
            "-- 3. Minimum 1 transaction required per combination",
            "-- 4. All monetary values in Philippine Pesos (₱)"
        ]

        # Add dimension-specific validation
        time_dims = [dim for dim in dimensions if "time" in dim.name.lower()]
        if time_dims:
            rules.append("-- 5. Time-based analysis may show patterns across different time zones")

        demo_dims = [dim for dim in dimensions if dim.name in ["gender", "age_bracket"]]
        if demo_dims:
            rules.append("-- 6. Demographic data may have null values - results show available data only")

        return "\n".join(rules)

    def generate_template_batch(self, dimension_combinations: List[List[str]]) -> Dict[str, str]:
        """Generate multiple templates for different dimension combinations"""
        templates = {}

        for combination in dimension_combinations:
            template_name = "_".join(combination)
            try:
                template_sql = self.generate_template_for_dimensions(combination, template_name)
                templates[template_name] = template_sql
            except Exception as e:
                print(f"Error generating template for {combination}: {e}")

        return templates

    def save_template_to_file(self, template_sql: str, template_name: str) -> str:
        """Save generated template to file"""
        filename = f"{template_name}.sql"
        filepath = self.dynamic_template_dir / filename

        with open(filepath, 'w') as f:
            f.write(template_sql)

        print(f"Saved template: {filepath}")
        return str(filepath)

    def generate_top_priority_templates(self, count: int = 50) -> Dict[str, str]:
        """Generate SQL templates for top priority dimensional combinations"""

        # Get priority combinations from matrix generator
        priority_combinations = self.matrix_generator.generate_priority_combinations(count)

        generated_templates = {}

        for i, combination in enumerate(priority_combinations, 1):
            # Extract dimension names
            dimension_names = [dim.name for dim in combination.dimensions]
            template_name = "_".join(dimension_names)

            print(f"Generating template {i}/{count}: {template_name}")

            try:
                # Generate SQL template
                template_sql = self.generate_template_for_dimensions(dimension_names, template_name)

                # Save to file
                filepath = self.save_template_to_file(template_sql, template_name)

                generated_templates[template_name] = {
                    "sql": template_sql,
                    "filepath": filepath,
                    "business_question": combination.business_question,
                    "value_proposition": combination.value_proposition,
                    "complexity_score": combination.complexity_score
                }

            except Exception as e:
                print(f"Error generating template {template_name}: {e}")

        return generated_templates

    def create_template_registry(self, templates: Dict[str, str]) -> Dict[str, Any]:
        """Create comprehensive template registry with metadata"""

        registry = {
            "metadata": {
                "total_templates": len(templates),
                "generation_timestamp": "2025-09-22T00:00:00Z",
                "generator_version": "1.0.0",
                "coverage": "Dynamic dimensional combinations"
            },
            "templates": {}
        }

        for template_name, template_data in templates.items():
            if isinstance(template_data, dict):
                registry["templates"][template_name] = {
                    "name": template_name,
                    "filepath": template_data.get("filepath", ""),
                    "business_question": template_data.get("business_question", ""),
                    "value_proposition": template_data.get("value_proposition", ""),
                    "complexity_score": template_data.get("complexity_score", 0.0),
                    "dimensions": template_name.split("_"),
                    "parameters": self._extract_parameters_from_sql(template_data.get("sql", "")),
                    "usage_notes": "Dynamically generated template for dimensional analysis"
                }

        return registry

    def _extract_parameters_from_sql(self, sql: str) -> List[str]:
        """Extract parameters from SQL template"""
        import re

        # Find all ${parameter} patterns
        params = re.findall(r'\$\{([^}]+)\}', sql)

        # Clean up parameters (remove defaults)
        clean_params = []
        for param in params:
            if ':=' in param:
                param = param.split(':=')[0]
            clean_params.append(param)

        return list(set(clean_params))  # Remove duplicates

if __name__ == "__main__":
    generator = DynamicTemplateGenerator()

    print("Generating top priority SQL templates...")

    # Generate top 50 priority templates
    templates = generator.generate_top_priority_templates(50)

    print(f"\nGenerated {len(templates)} templates successfully")

    # Create template registry
    registry = generator.create_template_registry(templates)

    # Save registry
    registry_path = "/Users/tbwa/scout-v7/config/dynamic_template_registry.json"
    with open(registry_path, 'w') as f:
        json.dump(registry, f, indent=2)

    print(f"Template registry saved to: {registry_path}")

    # Show sample of generated templates
    print("\nGenerated Templates Sample:")
    for i, (name, data) in enumerate(list(templates.items())[:10], 1):
        if isinstance(data, dict):
            print(f"{i:2d}. {name}")
            print(f"    Question: {data.get('business_question', 'N/A')}")
            print(f"    Value: {data.get('value_proposition', 'N/A')}")
            print(f"    File: {data.get('filepath', 'N/A')}")
            print()