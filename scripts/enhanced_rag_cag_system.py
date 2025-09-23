#!/usr/bin/env python3
"""
Enhanced RAG-CAG System for Scout Analytics
Supports all dimensional permutations and dynamic template generation

Features:
- Dynamic template generation for any dimensional combination
- Comprehensive dimensional analysis (1925+ combinations)
- Evidence-based query processing with validation
- Natural language to dimensional mapping
"""

import os
import json
import yaml
import sqlite3
import logging
import argparse
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Tuple, Set
from dataclasses import dataclass
from pathlib import Path
import re

import psycopg2
import pyodbc
from sentence_transformers import SentenceTransformer
import numpy as np
from sklearn.metrics.pairwise import cosine_similarity

# Import our existing modules
from dimensional_matrix_generator import DimensionalMatrixGenerator, Dimension, DimensionCombination
from dynamic_template_generator import DynamicTemplateGenerator

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

@dataclass
class DimensionalQueryResult:
    """Enhanced result container with dimensional analysis metadata"""
    template_id: str
    dimensions: List[str]
    combination_type: str
    engine: str
    rows: List[Dict[str, Any]]
    row_count: int
    execution_time_ms: int
    validation_passed: bool
    evidence: Dict[str, Any]
    business_question: str
    value_proposition: str
    complexity_score: float
    dynamic_generated: bool = False
    error: Optional[str] = None

@dataclass
class DimensionalQuery:
    """Natural language query with dimensional analysis"""
    raw_query: str
    detected_dimensions: List[str]
    extracted_parameters: Dict[str, Any]
    intent_type: str  # "analyze", "compare", "trends", "patterns"
    confidence: float
    suggested_combinations: List[List[str]]

class NaturalLanguageDimensionMapper:
    """Maps natural language queries to dimensional combinations"""

    def __init__(self):
        self.dimension_keywords = {
            "time_hour": ["hour", "time of day", "hourly", "specific hour"],
            "time_daypart": ["morning", "afternoon", "evening", "night", "daypart", "time period"],
            "time_weekday": ["weekday", "weekend", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "day of week"],
            "time_date": ["date", "daily", "specific day", "day by day"],
            "category": ["category", "categories", "product type", "product group"],
            "brand": ["brand", "brands", "manufacturer", "company"],
            "product": ["product", "products", "item", "items", "sku"],
            "store": ["store", "stores", "location", "branch", "outlet"],
            "store_location": ["municipality", "area", "region", "city"],
            "payment_method": ["payment", "cash", "card", "credit", "debit", "digital", "gcash", "payment method"],
            "gender": ["gender", "male", "female", "men", "women", "boys", "girls"],
            "age_bracket": ["age", "young", "old", "adult", "teen", "senior", "generation"],
            "basket_size": ["basket", "transaction size", "purchase amount", "basket value"],
            "price_range": ["price", "expensive", "cheap", "premium", "budget", "cost"],
            "substitute_reason": ["substitution", "substitute", "replacement", "out of stock", "unavailable"]
        }

        self.intent_patterns = {
            "analyze": ["analyze", "analysis", "understand", "explore", "investigate"],
            "compare": ["compare", "versus", "vs", "difference", "between"],
            "trends": ["trend", "patterns", "over time", "changes", "evolution"],
            "patterns": ["pattern", "behavior", "habits", "preferences", "correlation"]
        }

    def map_query_to_dimensions(self, query: str) -> DimensionalQuery:
        """Map natural language query to dimensional analysis"""
        query_lower = query.lower()

        # Detect dimensions
        detected_dimensions = []
        for dimension, keywords in self.dimension_keywords.items():
            for keyword in keywords:
                if keyword in query_lower:
                    if dimension not in detected_dimensions:
                        detected_dimensions.append(dimension)

        # Detect intent
        intent_type = "analyze"  # default
        for intent, patterns in self.intent_patterns.items():
            for pattern in patterns:
                if pattern in query_lower:
                    intent_type = intent
                    break

        # Extract parameters
        parameters = self._extract_parameters_from_query(query)

        # Generate suggested combinations
        suggested_combinations = self._generate_suggested_combinations(detected_dimensions, intent_type)

        # Calculate confidence
        confidence = min(1.0, len(detected_dimensions) * 0.3 + len(parameters) * 0.2 + 0.5)

        return DimensionalQuery(
            raw_query=query,
            detected_dimensions=detected_dimensions,
            extracted_parameters=parameters,
            intent_type=intent_type,
            confidence=confidence,
            suggested_combinations=suggested_combinations
        )

    def _extract_parameters_from_query(self, query: str) -> Dict[str, Any]:
        """Extract parameters from natural language query"""
        parameters = {}

        # Date extraction patterns
        date_patterns = [
            (r'last (\d+) days?', lambda m: {
                'date_from': (datetime.now() - timedelta(days=int(m.group(1)))).strftime('%Y-%m-%d'),
                'date_to': datetime.now().strftime('%Y-%m-%d')
            }),
            (r'past (\d+) weeks?', lambda m: {
                'date_from': (datetime.now() - timedelta(weeks=int(m.group(1)))).strftime('%Y-%m-%d'),
                'date_to': datetime.now().strftime('%Y-%m-%d')
            }),
            (r'(\d{4}-\d{2}-\d{2})', lambda m: {
                'date_from': m.group(1),
                'date_to': m.group(1)
            })
        ]

        for pattern, extractor in date_patterns:
            match = re.search(pattern, query)
            if match:
                parameters.update(extractor(match))
                break

        # Default date range if none specified
        if 'date_from' not in parameters:
            parameters.update({
                'date_from': (datetime.now() - timedelta(days=30)).strftime('%Y-%m-%d'),
                'date_to': datetime.now().strftime('%Y-%m-%d')
            })

        # Extract specific values
        value_patterns = [
            (r'store (\d+)', 'store_id'),
            (r'category "([^"]+)"', 'category'),
            (r'brand "([^"]+)"', 'brand'),
            (r'gender "([^"]+)"', 'gender'),
            (r'age "([^"]+)"', 'agebracket'),
            (r'payment "([^"]+)"', 'payment_method')
        ]

        for pattern, param_name in value_patterns:
            match = re.search(pattern, query, re.IGNORECASE)
            if match:
                parameters[param_name] = match.group(1)

        return parameters

    def _generate_suggested_combinations(self, detected_dimensions: List[str], intent_type: str) -> List[List[str]]:
        """Generate suggested dimensional combinations based on detected dimensions and intent"""
        if not detected_dimensions:
            # Default high-value combinations
            return [
                ["time_daypart", "category"],
                ["category", "gender", "age_bracket"],
                ["store", "category", "brand"]
            ]

        suggestions = []

        # If only one dimension detected, suggest meaningful combinations
        if len(detected_dimensions) == 1:
            base_dim = detected_dimensions[0]

            if "time" in base_dim:
                suggestions.extend([
                    [base_dim, "category"],
                    [base_dim, "store"],
                    [base_dim, "gender", "age_bracket"]
                ])
            elif base_dim == "category":
                suggestions.extend([
                    [base_dim, "time_daypart"],
                    [base_dim, "brand", "store"],
                    [base_dim, "gender", "age_bracket"]
                ])
            elif base_dim in ["gender", "age_bracket"]:
                suggestions.extend([
                    [base_dim, "category", "brand"],
                    [base_dim, "time_daypart", "category"],
                    [base_dim, "store", "payment_method"]
                ])
            else:
                suggestions.extend([
                    [base_dim, "category"],
                    [base_dim, "time_daypart"],
                    [base_dim, "store"]
                ])

        # If multiple dimensions detected, use them directly and add variants
        elif len(detected_dimensions) >= 2:
            # Use detected dimensions as-is
            suggestions.append(detected_dimensions[:4])  # Limit to 4-way max

            # Add strategic combinations based on intent
            if intent_type == "compare":
                # Add store dimension for comparison
                if "store" not in detected_dimensions:
                    suggestions.append(detected_dimensions[:3] + ["store"])

            elif intent_type == "trends":
                # Ensure time dimension is included
                time_dims = [d for d in detected_dimensions if "time" in d]
                if not time_dims:
                    suggestions.append(["time_date"] + detected_dimensions[:3])

        # Remove duplicates and invalid combinations
        cleaned_suggestions = []
        for combo in suggestions:
            if len(combo) >= 2 and len(combo) <= 4 and combo not in cleaned_suggestions:
                cleaned_suggestions.append(combo)

        return cleaned_suggestions[:5]  # Return top 5 suggestions

class EnhancedRAGCAGAgent:
    """Enhanced RAG-CAG Agent with comprehensive dimensional analysis"""

    def __init__(self):
        self.embeddings_model = SentenceTransformer('all-MiniLM-L6-v2')

        # Core components
        self.matrix_generator = DimensionalMatrixGenerator()
        self.template_generator = DynamicTemplateGenerator()
        self.dimension_mapper = NaturalLanguageDimensionMapper()

        # Load existing components
        self._load_knowledge_base()
        self._load_dimensional_data()

        # Database connection (simplified)
        self.db_config = {
            'postgresql': {
                'host': os.getenv('SUPABASE_HOST', 'aws-0-ap-southeast-1.pooler.supabase.com'),
                'port': int(os.getenv('SUPABASE_PORT', '6543')),
                'database': os.getenv('SUPABASE_DB', 'postgres'),
                'user': os.getenv('SUPABASE_USER', 'postgres.cxzllzyxwpyptfretryc'),
                'password': os.getenv('SUPABASE_PASS', 'Postgres_26')
            }
        }

    def _load_knowledge_base(self):
        """Load existing knowledge base and templates"""
        try:
            # Load original templates
            registry_path = "/Users/tbwa/scout-v7/sql_templates/template_registry.yaml"
            if os.path.exists(registry_path):
                with open(registry_path, 'r') as f:
                    self.original_templates = yaml.safe_load(f)
            else:
                self.original_templates = {"templates": {}}

            logger.info(f"Loaded {len(self.original_templates.get('templates', {}))} original templates")

        except Exception as e:
            logger.error(f"Error loading knowledge base: {e}")
            self.original_templates = {"templates": {}}

    def _load_dimensional_data(self):
        """Load dimensional matrix and dynamic templates"""
        try:
            # Load dimensional matrix
            matrix_path = "/Users/tbwa/scout-v7/config/dimensional_matrix_complete.json"
            if os.path.exists(matrix_path):
                with open(matrix_path, 'r') as f:
                    self.dimensional_matrix = json.load(f)
            else:
                self.dimensional_matrix = {"combinations": []}

            # Load dynamic template registry
            registry_path = "/Users/tbwa/scout-v7/config/dynamic_template_registry.json"
            if os.path.exists(registry_path):
                with open(registry_path, 'r') as f:
                    self.dynamic_registry = json.load(f)
            else:
                self.dynamic_registry = {"templates": {}}

            # Load comprehensive registry
            comp_registry_path = "/Users/tbwa/scout-v7/sql_templates/template_registry_comprehensive.yaml"
            if os.path.exists(comp_registry_path):
                with open(comp_registry_path, 'r') as f:
                    self.comprehensive_registry = yaml.safe_load(f)
            else:
                self.comprehensive_registry = {}

            logger.info(f"Loaded {len(self.dimensional_matrix.get('combinations', []))} dimensional combinations")
            logger.info(f"Loaded {len(self.dynamic_registry.get('templates', {}))} dynamic templates")

        except Exception as e:
            logger.error(f"Error loading dimensional data: {e}")
            self.dimensional_matrix = {"combinations": []}
            self.dynamic_registry = {"templates": {}}
            self.comprehensive_registry = {}

    def process_natural_language_query(self, query: str, engine: str = 'postgresql') -> DimensionalQueryResult:
        """Process natural language query with comprehensive dimensional analysis"""
        logger.info(f"Processing enhanced query: {query}")

        # Step 1: Map query to dimensions
        dimensional_query = self.dimension_mapper.map_query_to_dimensions(query)
        logger.info(f"Detected dimensions: {dimensional_query.detected_dimensions}")
        logger.info(f"Intent: {dimensional_query.intent_type}, Confidence: {dimensional_query.confidence:.3f}")

        # Step 2: Find best dimensional combination
        best_combination = self._select_best_combination(dimensional_query)
        if not best_combination:
            return self._create_error_result("No suitable dimensional combination found", query)

        logger.info(f"Selected combination: {best_combination}")

        # Step 3: Get or generate template
        template_result = self._get_or_generate_template(best_combination, dimensional_query)
        if template_result.get('error'):
            return self._create_error_result(template_result['error'], query)

        # Step 4: Execute query
        try:
            sql_content = template_result['sql_content']
            parameters = dimensional_query.extracted_parameters

            # Execute the SQL
            result = self._execute_sql(sql_content, parameters, engine)

            # Create enhanced result
            return DimensionalQueryResult(
                template_id=template_result['template_id'],
                dimensions=best_combination,
                combination_type=f"{len(best_combination)}-way",
                engine=engine,
                rows=result['rows'],
                row_count=result['row_count'],
                execution_time_ms=result['execution_time_ms'],
                validation_passed=result['success'],
                evidence={
                    'dimensional_query': dimensional_query.__dict__,
                    'template_metadata': template_result.get('metadata', {}),
                    'parameters_used': parameters,
                    'sql_executed': sql_content[:500] + "..." if len(sql_content) > 500 else sql_content
                },
                business_question=template_result.get('business_question', ''),
                value_proposition=template_result.get('value_proposition', ''),
                complexity_score=template_result.get('complexity_score', 0.0),
                dynamic_generated=template_result.get('dynamic_generated', False),
                error=result.get('error')
            )

        except Exception as e:
            logger.error(f"Error executing query: {e}")
            return self._create_error_result(f"Execution error: {str(e)}", query)

    def _select_best_combination(self, dimensional_query: DimensionalQuery) -> Optional[List[str]]:
        """Select the best dimensional combination for the query"""

        # If we have suggested combinations, use the first one
        if dimensional_query.suggested_combinations:
            return dimensional_query.suggested_combinations[0]

        # Fallback to detected dimensions
        if dimensional_query.detected_dimensions:
            return dimensional_query.detected_dimensions[:4]  # Max 4-way

        # Ultimate fallback to high-value default
        return ["time_daypart", "category"]

    def _get_or_generate_template(self, dimension_combination: List[str], dimensional_query: DimensionalQuery) -> Dict[str, Any]:
        """Get existing template or generate new one for dimensional combination"""

        template_name = "_".join(dimension_combination)

        # First, check if we have a dynamic template already generated
        if template_name in self.dynamic_registry.get('templates', {}):
            template_info = self.dynamic_registry['templates'][template_name]

            # Load SQL content from file
            sql_path = template_info.get('filepath')
            if sql_path and os.path.exists(sql_path):
                with open(sql_path, 'r') as f:
                    sql_content = f.read()

                return {
                    'template_id': template_name,
                    'sql_content': sql_content,
                    'business_question': template_info.get('business_question', ''),
                    'value_proposition': template_info.get('value_proposition', ''),
                    'complexity_score': template_info.get('complexity_score', 0.0),
                    'dynamic_generated': False,  # Pre-generated
                    'metadata': template_info
                }

        # Generate template dynamically
        try:
            logger.info(f"Generating dynamic template for: {dimension_combination}")
            sql_content = self.template_generator.generate_template_for_dimensions(
                dimension_combination, template_name
            )

            # Get business context from matrix
            business_question = f"How do {', '.join(dimension_combination)} interact and influence each other?"
            value_proposition = "Cross-Dimensional Insights"
            complexity_score = len(dimension_combination) * 2.0

            # Look up in dimensional matrix for better context
            for combo in self.dimensional_matrix.get('combinations', []):
                if set(combo.get('dimensions', [])) == set(dimension_combination):
                    business_question = combo.get('business_question', business_question)
                    value_proposition = combo.get('value_proposition', value_proposition)
                    complexity_score = combo.get('complexity_score', complexity_score)
                    break

            return {
                'template_id': template_name,
                'sql_content': sql_content,
                'business_question': business_question,
                'value_proposition': value_proposition,
                'complexity_score': complexity_score,
                'dynamic_generated': True,
                'metadata': {
                    'generated_at': datetime.now().isoformat(),
                    'dimensions': dimension_combination,
                    'query_intent': dimensional_query.intent_type
                }
            }

        except Exception as e:
            logger.error(f"Error generating template: {e}")
            return {'error': f"Template generation failed: {str(e)}"}

    def _execute_sql(self, sql_content: str, parameters: Dict[str, Any], engine: str) -> Dict[str, Any]:
        """Execute SQL with parameters"""
        start_time = datetime.now()

        try:
            # Simple parameter replacement (in a real system, use proper parameterization)
            sql_with_params = sql_content
            for param, value in parameters.items():
                if isinstance(value, str):
                    sql_with_params = sql_with_params.replace(f"${{{param}}}", f"'{value}'")
                else:
                    sql_with_params = sql_with_params.replace(f"${{{param}}}", str(value))

            # Replace any remaining parameter placeholders with defaults
            sql_with_params = re.sub(r'\$\{([^}]+):=([^}]+)\}', r'\2', sql_with_params)
            sql_with_params = re.sub(r'\$\{([^}]+)\}', r'NULL', sql_with_params)

            # Connect and execute
            if engine == 'postgresql':
                conn = psycopg2.connect(**self.db_config[engine])
                cursor = conn.cursor()
                cursor.execute(sql_with_params)

                # Fetch results
                rows = cursor.fetchall()
                columns = [desc[0] for desc in cursor.description]

                # Convert to dict format
                result_rows = [dict(zip(columns, row)) for row in rows]

                cursor.close()
                conn.close()

            execution_time = int((datetime.now() - start_time).total_seconds() * 1000)

            return {
                'success': True,
                'rows': result_rows,
                'row_count': len(result_rows),
                'execution_time_ms': execution_time
            }

        except Exception as e:
            execution_time = int((datetime.now() - start_time).total_seconds() * 1000)
            logger.error(f"SQL execution error: {e}")
            return {
                'success': False,
                'rows': [],
                'row_count': 0,
                'execution_time_ms': execution_time,
                'error': str(e)
            }

    def _create_error_result(self, error_message: str, original_query: str) -> DimensionalQueryResult:
        """Create error result"""
        return DimensionalQueryResult(
            template_id="",
            dimensions=[],
            combination_type="error",
            engine="",
            rows=[],
            row_count=0,
            execution_time_ms=0,
            validation_passed=False,
            evidence={'original_query': original_query},
            business_question="",
            value_proposition="",
            complexity_score=0.0,
            dynamic_generated=False,
            error=error_message
        )

    def list_available_combinations(self) -> Dict[str, Any]:
        """List all available dimensional combinations"""
        return {
            'total_combinations': len(self.dimensional_matrix.get('combinations', [])),
            'dynamic_templates_available': len(self.dynamic_registry.get('templates', {})),
            'original_templates': len(self.original_templates.get('templates', {})),
            'sample_combinations': [
                combo['dimensions'] for combo in
                self.dimensional_matrix.get('combinations', [])[:10]
            ],
            'high_value_combinations': [
                ["time_daypart", "category", "gender", "age_bracket"],
                ["time_daypart", "category", "brand", "store"],
                ["category", "brand", "gender", "age_bracket"],
                ["store", "category", "payment_method", "basket_size"]
            ]
        }

def main():
    """Command line interface for enhanced RAG-CAG system"""
    parser = argparse.ArgumentParser(description='Enhanced RAG-CAG Analytics for Scout')
    parser.add_argument('--query', type=str, help='Natural language query')
    parser.add_argument('--engine', type=str, default='postgresql', choices=['postgresql', 'azuresql'])
    parser.add_argument('--list-combinations', action='store_true', help='List available combinations')
    parser.add_argument('--dimensions', type=str, help='Specific dimensions (comma-separated)')

    args = parser.parse_args()

    agent = EnhancedRAGCAGAgent()

    if args.list_combinations:
        combinations = agent.list_available_combinations()
        print(json.dumps(combinations, indent=2))
        return

    if args.query:
        result = agent.process_natural_language_query(args.query, args.engine)

        print(f"\n=== Enhanced RAG-CAG Analysis Results ===")
        print(f"Query: {args.query}")
        print(f"Template: {result.template_id}")
        print(f"Dimensions: {' × '.join(result.dimensions)}")
        print(f"Business Question: {result.business_question}")
        print(f"Combination Type: {result.combination_type}")
        print(f"Value Proposition: {result.value_proposition}")
        print(f"Dynamic Generated: {result.dynamic_generated}")
        print(f"Execution Time: {result.execution_time_ms}ms")
        print(f"Rows Returned: {result.row_count}")

        if result.error:
            print(f"Error: {result.error}")
        else:
            print(f"Validation Passed: {result.validation_passed}")

            if result.rows and len(result.rows) > 0:
                print(f"\nSample Results (first 3 rows):")
                for i, row in enumerate(result.rows[:3], 1):
                    print(f"  Row {i}: {dict(list(row.items())[:5])}")  # Show first 5 columns

        print(f"\nEvidence:")
        print(json.dumps(result.evidence, indent=2, default=str))

    elif args.dimensions:
        dimension_list = [d.strip() for d in args.dimensions.split(',')]
        print(f"Generating template for dimensions: {dimension_list}")

        template_sql = agent.template_generator.generate_template_for_dimensions(dimension_list)
        print("\nGenerated SQL Template:")
        print(template_sql)

    else:
        print("Please provide --query or --list-combinations")

if __name__ == "__main__":
    main()