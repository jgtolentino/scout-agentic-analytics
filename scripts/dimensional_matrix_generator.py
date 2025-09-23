#!/usr/bin/env python3
"""
Dimensional Matrix Generator for Scout Analytics
Creates all possible permutations and classifications across all dimensions
"""

import json
import itertools
from typing import Dict, List, Tuple, Set, Any
from dataclasses import dataclass
from pathlib import Path
import yaml

@dataclass
class Dimension:
    """Represents a data dimension with its properties"""
    name: str
    display_name: str
    column: str
    data_type: str
    cardinality: str  # low, medium, high
    business_context: str
    aggregable: bool = True
    filterable: bool = True

@dataclass
class DimensionCombination:
    """Represents a combination of dimensions for analysis"""
    dimensions: List[Dimension]
    combination_type: str  # "2-way", "3-way", etc.
    business_question: str
    sql_template: str
    complexity_score: float
    value_proposition: str

class DimensionalMatrixGenerator:
    """Generates all possible dimensional combinations for Scout analytics"""

    def __init__(self):
        self.dimensions = self._initialize_dimensions()
        self.combinations = []
        self.business_contexts = self._initialize_business_contexts()

    def _initialize_dimensions(self) -> List[Dimension]:
        """Initialize all available dimensions from Scout data"""
        return [
            Dimension(
                name="time_hour",
                display_name="Hour of Day",
                column="DATEPART(hour, transactiondate)",
                data_type="int",
                cardinality="medium",
                business_context="Shopping patterns, peak hours, operational efficiency"
            ),
            Dimension(
                name="time_daypart",
                display_name="Day Part",
                column="CASE WHEN DATEPART(hour, transactiondate) BETWEEN 6 AND 11 THEN 'Morning' WHEN DATEPART(hour, transactiondate) BETWEEN 12 AND 17 THEN 'Afternoon' WHEN DATEPART(hour, transactiondate) BETWEEN 18 AND 21 THEN 'Evening' ELSE 'Night' END",
                data_type="varchar",
                cardinality="low",
                business_context="Consumer behavior patterns, staffing optimization"
            ),
            Dimension(
                name="time_weekday",
                display_name="Day of Week",
                column="DATENAME(weekday, transactiondate)",
                data_type="varchar",
                cardinality="low",
                business_context="Weekly patterns, weekend vs weekday behavior"
            ),
            Dimension(
                name="time_date",
                display_name="Date",
                column="CAST(transactiondate AS date)",
                data_type="date",
                cardinality="high",
                business_context="Daily trends, seasonality, campaign tracking"
            ),
            Dimension(
                name="category",
                display_name="Product Category",
                column="category",
                data_type="varchar",
                cardinality="medium",
                business_context="Category performance, cross-selling, inventory planning"
            ),
            Dimension(
                name="brand",
                display_name="Brand",
                column="brand",
                data_type="varchar",
                cardinality="high",
                business_context="Brand loyalty, market share, competitive analysis"
            ),
            Dimension(
                name="product",
                display_name="Product",
                column="product",
                data_type="varchar",
                cardinality="high",
                business_context="SKU performance, product mix optimization"
            ),
            Dimension(
                name="store",
                display_name="Store",
                column="storename",
                data_type="varchar",
                cardinality="low",
                business_context="Store performance comparison, location analysis"
            ),
            Dimension(
                name="store_location",
                display_name="Store Location",
                column="CONCAT(storename, ' (', municipalityname, ')')",
                data_type="varchar",
                cardinality="low",
                business_context="Geographic analysis, regional preferences"
            ),
            Dimension(
                name="payment_method",
                display_name="Payment Method",
                column="payment_method",
                data_type="varchar",
                cardinality="low",
                business_context="Payment preferences, cashless adoption"
            ),
            Dimension(
                name="gender",
                display_name="Customer Gender",
                column="gender",
                data_type="varchar",
                cardinality="low",
                business_context="Gender-based preferences, demographic targeting"
            ),
            Dimension(
                name="age_bracket",
                display_name="Age Bracket",
                column="agebracket",
                data_type="varchar",
                cardinality="low",
                business_context="Age-based behavior, generational preferences"
            ),
            Dimension(
                name="basket_size",
                display_name="Basket Size",
                column="CASE WHEN total_price < 50 THEN 'Small' WHEN total_price < 200 THEN 'Medium' WHEN total_price < 500 THEN 'Large' ELSE 'Premium' END",
                data_type="varchar",
                cardinality="low",
                business_context="Purchase behavior, basket optimization"
            ),
            Dimension(
                name="price_range",
                display_name="Price Range",
                column="CASE WHEN total_price < 25 THEN 'Budget' WHEN total_price < 100 THEN 'Standard' WHEN total_price < 300 THEN 'Premium' ELSE 'Luxury' END",
                data_type="varchar",
                cardinality="low",
                business_context="Price sensitivity, premium positioning"
            ),
            Dimension(
                name="substitute_reason",
                display_name="Substitution Reason",
                column="substitution_reason",
                data_type="varchar",
                cardinality="medium",
                business_context="Inventory management, customer satisfaction"
            )
        ]

    def _initialize_business_contexts(self) -> Dict[str, List[str]]:
        """Initialize business contexts for different combination types"""
        return {
            "temporal_behavior": [
                "When do customers shop for specific categories?",
                "How do shopping patterns vary by time periods?",
                "What are the peak hours for different demographics?"
            ],
            "demographic_preferences": [
                "What do different age groups prefer?",
                "How do gender preferences vary by category?",
                "Which demographics prefer which payment methods?"
            ],
            "location_analysis": [
                "How do store locations perform differently?",
                "What are regional preference variations?",
                "Which stores excel in specific categories?"
            ],
            "product_performance": [
                "Which brands perform best in each category?",
                "What are the top-selling products by segment?",
                "How do substitution patterns affect sales?"
            ],
            "operational_efficiency": [
                "When should staff be optimized for different stores?",
                "What payment methods require operational support?",
                "How do basket sizes correlate with service needs?"
            ],
            "customer_journey": [
                "How do purchase behaviors progress through the day?",
                "What drives customers to different stores?",
                "How do preferences change across demographics?"
            ]
        }

    def generate_all_combinations(self, max_dimensions: int = 4) -> List[DimensionCombination]:
        """Generate all possible dimensional combinations up to max_dimensions"""
        all_combinations = []

        # Generate 2-way through n-way combinations
        for r in range(2, max_dimensions + 1):
            for combo in itertools.combinations(self.dimensions, r):
                combination = self._create_dimension_combination(list(combo), r)
                if combination:
                    all_combinations.append(combination)

        # Sort by business value and complexity
        all_combinations.sort(key=lambda x: (-x.complexity_score, x.combination_type))

        return all_combinations

    def _create_dimension_combination(self, dimensions: List[Dimension], size: int) -> DimensionCombination:
        """Create a specific dimensional combination with business context"""

        # Calculate complexity score based on cardinality and business value
        complexity_score = self._calculate_complexity_score(dimensions)

        # Generate business question
        business_question = self._generate_business_question(dimensions)

        # Generate SQL template
        sql_template = self._generate_sql_template(dimensions)

        # Determine value proposition
        value_proposition = self._determine_value_proposition(dimensions)

        return DimensionCombination(
            dimensions=dimensions,
            combination_type=f"{size}-way",
            business_question=business_question,
            sql_template=sql_template,
            complexity_score=complexity_score,
            value_proposition=value_proposition
        )

    def _calculate_complexity_score(self, dimensions: List[Dimension]) -> float:
        """Calculate complexity score based on dimensions"""
        cardinality_weights = {"low": 1.0, "medium": 2.0, "high": 3.0}

        base_score = sum(cardinality_weights[dim.cardinality] for dim in dimensions)
        size_multiplier = len(dimensions) ** 1.5

        return round(base_score * size_multiplier / 10, 2)

    def _generate_business_question(self, dimensions: List[Dimension]) -> str:
        """Generate relevant business question for dimension combination"""
        dim_names = [dim.display_name for dim in dimensions]

        # Pattern matching for common combinations
        if any("time" in dim.name.lower() for dim in dimensions):
            if any("category" in dim.name.lower() for dim in dimensions):
                return f"When do customers shop for specific {', '.join(dim_names)}?"
            elif any("gender" in dim.name.lower() or "age" in dim.name.lower() for dim in dimensions):
                return f"How do shopping times vary across {', '.join(dim_names)}?"

        if any("gender" in dim.name.lower() for dim in dimensions) and any("category" in dim.name.lower() for dim in dimensions):
            return f"What are the preferences across {', '.join(dim_names)}?"

        if any("store" in dim.name.lower() for dim in dimensions):
            return f"How do stores compare across {', '.join(dim_names)}?"

        if any("payment" in dim.name.lower() for dim in dimensions):
            return f"What payment patterns exist across {', '.join(dim_names)}?"

        # Generic pattern
        return f"How do {', '.join(dim_names)} interact and influence each other?"

    def _generate_sql_template(self, dimensions: List[Dimension]) -> str:
        """Generate SQL template for dimensional combination"""

        # Build SELECT clause
        select_dims = [f"    {dim.column} AS {dim.name}" for dim in dimensions]
        select_clause = ",\n".join(select_dims)

        # Build GROUP BY clause
        group_by_dims = [dim.column for dim in dimensions]
        group_by_clause = ",\n    ".join(group_by_dims)

        # Build business question comment
        business_question = self._generate_business_question(dimensions)

        template = f"""-- Business Question: "{business_question}"
-- Dimensional Analysis: {' × '.join([dim.display_name for dim in dimensions])}
-- Combination Type: {len(dimensions)}-way cross-tabulation

WITH dimensional_analysis AS (
    SELECT
{select_clause},
        COUNT(*) AS transaction_count,
        SUM(total_price) AS total_revenue,
        AVG(total_price) AS avg_transaction_value,
        COUNT(DISTINCT productid) AS unique_products,
        MIN(transactiondate) AS first_transaction,
        MAX(transactiondate) AS last_transaction
    FROM public.scout_gold_transactions_flat t
    WHERE t.transactiondate >= ${{date_from}}
      AND t.transactiondate <= ${{date_to}}
      AND t.latitude BETWEEN 14.0 AND 15.0  -- NCR bounds
      AND t.longitude BETWEEN 120.5 AND 121.5
      {{#store_filter}}AND t.storeid = ${{store_id}}{{/store_filter}}
      {{#category_filter}}AND t.category = '${{category}}'{{/category_filter}}
    GROUP BY
    {group_by_clause}
),
ranked_analysis AS (
    SELECT *,
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
        ROW_NUMBER() OVER (ORDER BY transaction_count DESC) AS volume_rank,
        ROUND(100.0 * total_revenue / SUM(total_revenue) OVER (), 2) AS revenue_share_pct,
        ROUND(100.0 * transaction_count / SUM(transaction_count) OVER (), 2) AS volume_share_pct
    FROM dimensional_analysis
)
SELECT *
FROM ranked_analysis
ORDER BY total_revenue DESC;"""

        return template

    def _determine_value_proposition(self, dimensions: List[Dimension]) -> str:
        """Determine business value proposition for combination"""
        contexts = [dim.business_context for dim in dimensions]

        if any("operational" in context.lower() for context in contexts):
            return "Operational Optimization"
        elif any("behavior" in context.lower() or "pattern" in context.lower() for context in contexts):
            return "Customer Behavior Analysis"
        elif any("performance" in context.lower() for context in contexts):
            return "Performance Analysis"
        elif any("preference" in context.lower() for context in contexts):
            return "Preference Analysis"
        else:
            return "Cross-Dimensional Insights"

    def export_combination_matrix(self, output_path: str):
        """Export complete dimensional combination matrix"""
        combinations = self.generate_all_combinations()

        # Create comprehensive export structure
        export_data = {
            "metadata": {
                "total_dimensions": len(self.dimensions),
                "total_combinations": len(combinations),
                "generation_timestamp": "2025-09-22T00:00:00Z",
                "max_combination_size": 4,
                "coverage": "All possible 2-way through 4-way combinations"
            },
            "dimensions": [
                {
                    "name": dim.name,
                    "display_name": dim.display_name,
                    "column": dim.column,
                    "data_type": dim.data_type,
                    "cardinality": dim.cardinality,
                    "business_context": dim.business_context
                }
                for dim in self.dimensions
            ],
            "combinations": [
                {
                    "id": f"combo_{i+1:03d}",
                    "dimensions": [dim.name for dim in combo.dimensions],
                    "display_names": [dim.display_name for dim in combo.dimensions],
                    "combination_type": combo.combination_type,
                    "business_question": combo.business_question,
                    "value_proposition": combo.value_proposition,
                    "complexity_score": combo.complexity_score,
                    "sql_template": combo.sql_template
                }
                for i, combo in enumerate(combinations)
            ],
            "business_contexts": self.business_contexts,
            "usage_guidelines": {
                "low_complexity": "Complexity score < 5.0 - Suitable for real-time dashboards",
                "medium_complexity": "Complexity score 5.0-10.0 - Good for scheduled reports",
                "high_complexity": "Complexity score > 10.0 - Use for deep analysis sessions",
                "recommended_max_combinations": "Focus on top 50 combinations by business value"
            }
        }

        # Write to JSON file
        with open(output_path, 'w') as f:
            json.dump(export_data, f, indent=2)

        print(f"Exported {len(combinations)} dimensional combinations to {output_path}")
        return export_data

    def generate_priority_combinations(self, limit: int = 50) -> List[DimensionCombination]:
        """Generate top priority combinations based on business value"""
        all_combinations = self.generate_all_combinations()

        # Score combinations by business value
        def business_value_score(combo):
            value_weights = {
                "Customer Behavior Analysis": 10,
                "Performance Analysis": 9,
                "Operational Optimization": 8,
                "Preference Analysis": 7,
                "Cross-Dimensional Insights": 6
            }

            base_score = value_weights.get(combo.value_proposition, 5)

            # Boost score for commonly requested combinations
            dimension_names = [dim.name for dim in combo.dimensions]

            if "time_daypart" in dimension_names and "category" in dimension_names:
                base_score += 3  # High-value combination
            if "gender" in dimension_names and "age_bracket" in dimension_names:
                base_score += 2  # Demographic analysis
            if "store" in dimension_names:
                base_score += 1  # Store analysis always valuable

            # Penalize overly complex combinations
            if combo.complexity_score > 15:
                base_score -= 2

            return base_score

        # Sort by business value score
        all_combinations.sort(key=business_value_score, reverse=True)

        return all_combinations[:limit]

if __name__ == "__main__":
    generator = DimensionalMatrixGenerator()

    # Generate all combinations
    print("Generating comprehensive dimensional matrix...")
    all_combinations = generator.generate_all_combinations()
    print(f"Generated {len(all_combinations)} total combinations")

    # Generate priority list
    priority_combinations = generator.generate_priority_combinations(50)
    print(f"Identified {len(priority_combinations)} priority combinations")

    # Export complete matrix
    output_path = "/Users/tbwa/scout-v7/config/dimensional_matrix_complete.json"
    generator.export_combination_matrix(output_path)

    # Show sample of high-priority combinations
    print("\nTop 10 Priority Combinations:")
    for i, combo in enumerate(priority_combinations[:10], 1):
        dim_names = " × ".join([dim.display_name for dim in combo.dimensions])
        print(f"{i:2d}. {combo.combination_type}: {dim_names}")
        print(f"    Question: {combo.business_question}")
        print(f"    Value: {combo.value_proposition} (Complexity: {combo.complexity_score})")
        print()