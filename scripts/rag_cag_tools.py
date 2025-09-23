#!/usr/bin/env python3
"""
RAG-CAG Tools for Scout Analytics
Evidence-based query execution with template validation

Usage:
    python rag_cag_tools.py --query "time analysis last 14 days"
    python rag_cag_tools.py --template time_of_day_category --params '{"date_from": "2025-09-01"}'
"""

import os
import json
import yaml
import sqlite3
import logging
import argparse
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Tuple
from dataclasses import dataclass
from pathlib import Path
import re

import psycopg2
import pyodbc
from sentence_transformers import SentenceTransformer
import numpy as np
from sklearn.metrics.pairwise import cosine_similarity

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

@dataclass
class QueryResult:
    """Result container for executed queries"""
    template_id: str
    engine: str
    rows: List[Dict[str, Any]]
    row_count: int
    execution_time_ms: int
    validation_passed: bool
    evidence: Dict[str, Any]
    error: Optional[str] = None

@dataclass
class Template:
    """SQL template definition"""
    id: str
    name: str
    description: str
    business_question: str
    sql_content: str
    parameters: Dict[str, Any]
    validation_rules: List[str]
    performance_metrics: Dict[str, Any]

class RAGKnowledgeBase:
    """RAG knowledge corpus for Scout analytics"""

    def __init__(self, data_dir: str = "/Users/tbwa/scout-v7"):
        self.data_dir = Path(data_dir)
        self.embeddings_model = SentenceTransformer('all-MiniLM-L6-v2')
        self.knowledge_db = None
        self.templates = {}
        self.load_templates()

    def load_templates(self):
        """Load SQL templates from registry"""
        registry_path = self.data_dir / "sql_templates" / "template_registry.yaml"
        if registry_path.exists():
            with open(registry_path, 'r') as f:
                registry = yaml.safe_load(f)

            for template_id, template_data in registry['templates'].items():
                # Load SQL content
                sql_path = self.data_dir / "sql_templates" / f"{template_id}.sql"
                if sql_path.exists():
                    with open(sql_path, 'r') as f:
                        sql_content = f.read()

                    self.templates[template_id] = Template(
                        id=template_id,
                        name=template_data['name'],
                        description=template_data['description'],
                        business_question=template_data['business_question'],
                        sql_content=sql_content,
                        parameters=template_data['parameters'],
                        validation_rules=template_data.get('validation', []),
                        performance_metrics=template_data.get('performance', {})
                    )

        logger.info(f"Loaded {len(self.templates)} SQL templates")

    def create_knowledge_corpus(self):
        """Create embeddings for knowledge corpus"""
        corpus = []
        metadata = []

        # Add template descriptions and business questions
        for template_id, template in self.templates.items():
            corpus.append(f"{template.business_question} {template.description}")
            metadata.append({
                'type': 'template',
                'template_id': template_id,
                'name': template.name
            })

            # Add use cases
            for use_case in template.parameters.get('use_cases', []):
                corpus.append(use_case)
                metadata.append({
                    'type': 'use_case',
                    'template_id': template_id,
                    'use_case': use_case
                })

        # Generate embeddings
        embeddings = self.embeddings_model.encode(corpus)

        # Store in simple in-memory structure (could be enhanced with vector DB)
        self.knowledge_corpus = {
            'corpus': corpus,
            'embeddings': embeddings,
            'metadata': metadata
        }

        logger.info(f"Created knowledge corpus with {len(corpus)} entries")

    def search_templates(self, query: str, top_k: int = 3) -> List[Tuple[str, float]]:
        """Search for relevant templates using semantic similarity"""
        if not hasattr(self, 'knowledge_corpus'):
            self.create_knowledge_corpus()

        # Generate query embedding
        query_embedding = self.embeddings_model.encode([query])

        # Calculate similarities
        similarities = cosine_similarity(query_embedding, self.knowledge_corpus['embeddings'])[0]

        # Get top-k results
        top_indices = np.argsort(similarities)[::-1][:top_k]

        results = []
        seen_templates = set()

        for idx in top_indices:
            metadata = self.knowledge_corpus['metadata'][idx]
            if metadata['type'] == 'template' and metadata['template_id'] not in seen_templates:
                results.append((metadata['template_id'], similarities[idx]))
                seen_templates.add(metadata['template_id'])

        return results

class SQLCertifier:
    """SQL execution validator and security checker"""

    @staticmethod
    def validate_template(template_id: str, parameters: Dict[str, Any]) -> Tuple[bool, str]:
        """Validate template and parameters before execution"""
        # Check for SQL injection patterns
        for param_name, param_value in parameters.items():
            if isinstance(param_value, str):
                # Basic SQL injection detection
                dangerous_patterns = [
                    r';\s*drop\s+table',
                    r';\s*delete\s+from',
                    r';\s*insert\s+into',
                    r';\s*update\s+.*\s+set',
                    r'union\s+select',
                    r'exec\s*\(',
                    r'xp_cmdshell'
                ]

                for pattern in dangerous_patterns:
                    if re.search(pattern, param_value.lower()):
                        return False, f"Dangerous SQL pattern detected in parameter {param_name}"

        # Validate parameter types and ranges
        if 'date_from' in parameters:
            try:
                if isinstance(parameters['date_from'], str):
                    datetime.strptime(parameters['date_from'], '%Y-%m-%d')
            except ValueError:
                return False, "Invalid date_from format. Use YYYY-MM-DD"

        if 'date_to' in parameters:
            try:
                if isinstance(parameters['date_to'], str):
                    datetime.strptime(parameters['date_to'], '%Y-%m-%d')
            except ValueError:
                return False, "Invalid date_to format. Use YYYY-MM-DD"

        return True, "Validation passed"

class DatabaseExecutor:
    """Multi-engine database execution with fallback"""

    def __init__(self):
        self.connections = {}

    def get_connection(self, engine: str):
        """Get database connection for specified engine"""
        if engine in self.connections:
            return self.connections[engine]

        if engine == 'postgresql':
            # Supabase PostgreSQL connection
            conn = psycopg2.connect(
                host=os.getenv('SUPABASE_HOST', 'aws-0-ap-southeast-1.pooler.supabase.com'),
                port=int(os.getenv('SUPABASE_PORT', '6543')),
                database=os.getenv('SUPABASE_DB', 'postgres'),
                user=os.getenv('SUPABASE_USER', 'postgres.cxzllzyxwpyptfretryc'),
                password=os.getenv('SUPABASE_PASS', 'Postgres_26')
            )
        elif engine == 'azuresql':
            # Azure SQL connection
            conn_str = (
                f"DRIVER={{ODBC Driver 18 for SQL Server}};"
                f"SERVER={os.getenv('AZURE_SQL_SERVER', 'sql-tbwa-projectscout-reporting-prod.database.windows.net')};"
                f"DATABASE={os.getenv('AZURE_SQL_DB', 'SQL-TBWA-ProjectScout-Reporting-Prod')};"
                f"UID={os.getenv('AZURE_SQL_USER', 'scout_reader')};"
                f"PWD={os.getenv('AZURE_SQL_PASS', 'Scout_Analytics_2025!')};"
                "TrustServerCertificate=yes;"
            )
            conn = pyodbc.connect(conn_str, timeout=60)
        else:
            raise ValueError(f"Unsupported database engine: {engine}")

        self.connections[engine] = conn
        return conn

    def execute_query(self, sql: str, engine: str = 'postgresql') -> QueryResult:
        """Execute SQL query with timing and validation"""
        start_time = datetime.now()

        try:
            conn = self.get_connection(engine)
            cursor = conn.cursor()

            # Execute query
            cursor.execute(sql)

            # Fetch results
            if cursor.description:
                columns = [desc[0] for desc in cursor.description]
                rows = [dict(zip(columns, row)) for row in cursor.fetchall()]
            else:
                rows = []

            execution_time_ms = int((datetime.now() - start_time).total_seconds() * 1000)

            return QueryResult(
                template_id="",
                engine=engine,
                rows=rows,
                row_count=len(rows),
                execution_time_ms=execution_time_ms,
                validation_passed=True,
                evidence={
                    'execution_time_ms': execution_time_ms,
                    'row_count': len(rows),
                    'engine': engine,
                    'query_hash': hash(sql)
                }
            )

        except Exception as e:
            execution_time_ms = int((datetime.now() - start_time).total_seconds() * 1000)
            logger.error(f"Query execution failed: {e}")

            return QueryResult(
                template_id="",
                engine=engine,
                rows=[],
                row_count=0,
                execution_time_ms=execution_time_ms,
                validation_passed=False,
                evidence={},
                error=str(e)
            )

class ParityValidator:
    """Validates query results against expected patterns"""

    @staticmethod
    def validate_result(result: QueryResult, template: Template) -> Tuple[bool, List[str]]:
        """Validate query result against template expectations"""
        issues = []

        # Check row count expectations
        expected_range = template.performance_metrics.get('expected_rows', '1-1000')
        if '-' in expected_range:
            min_rows, max_rows = map(int, expected_range.split('-'))
            if not (min_rows <= result.row_count <= max_rows):
                issues.append(f"Row count {result.row_count} outside expected range {expected_range}")

        # Check for required columns
        if result.rows:
            first_row = result.rows[0]
            for rule in template.validation_rules:
                if 'should =' in rule and '%' in rule:
                    # Percentage validation
                    column_name = rule.split()[0].replace('SUM(', '').replace(')', '')
                    if column_name in first_row:
                        # Would need aggregation logic for full validation
                        pass

        # Check execution time
        max_time = template.performance_metrics.get('avg_execution_time', '1000ms')
        max_time_ms = int(max_time.replace('ms', ''))
        if result.execution_time_ms > max_time_ms * 2:  # 2x tolerance
            issues.append(f"Execution time {result.execution_time_ms}ms exceeds 2x expected {max_time}")

        return len(issues) == 0, issues

class RAGCAGAgent:
    """Main RAG-CAG agent for Scout analytics"""

    def __init__(self):
        self.knowledge_base = RAGKnowledgeBase()
        self.certifier = SQLCertifier()
        self.executor = DatabaseExecutor()
        self.validator = ParityValidator()

    def process_query(self, user_query: str, engine: str = 'postgresql') -> QueryResult:
        """Process natural language query through RAG-CAG pipeline"""
        logger.info(f"Processing query: {user_query}")

        # Step 1: RAG - Find relevant template
        template_matches = self.knowledge_base.search_templates(user_query)
        if not template_matches:
            return QueryResult(
                template_id="",
                engine=engine,
                rows=[],
                row_count=0,
                execution_time_ms=0,
                validation_passed=False,
                evidence={},
                error="No matching templates found"
            )

        template_id, confidence = template_matches[0]
        template = self.knowledge_base.templates[template_id]

        logger.info(f"Selected template: {template_id} (confidence: {confidence:.3f})")

        # Step 2: Parameter extraction (simplified)
        parameters = self._extract_parameters(user_query, template)

        # Step 3: SQL Certifier validation
        is_valid, validation_message = self.certifier.validate_template(template_id, parameters)
        if not is_valid:
            return QueryResult(
                template_id=template_id,
                engine=engine,
                rows=[],
                row_count=0,
                execution_time_ms=0,
                validation_passed=False,
                evidence={},
                error=f"Validation failed: {validation_message}"
            )

        # Step 4: Execute SQL
        sql = self._build_sql(template, parameters)
        result = self.executor.execute_query(sql, engine)
        result.template_id = template_id

        # Step 5: Validate results
        if result.validation_passed:
            parity_passed, parity_issues = self.validator.validate_result(result, template)
            result.validation_passed = parity_passed
            if parity_issues:
                result.evidence['parity_issues'] = parity_issues

        # Step 6: Generate evidence
        result.evidence.update({
            'template_id': template_id,
            'template_name': template.name,
            'confidence': confidence,
            'parameters': parameters,
            'business_question': template.business_question
        })

        return result

    def _extract_parameters(self, query: str, template: Template) -> Dict[str, Any]:
        """Extract parameters from natural language query"""
        parameters = {}

        # Simple date extraction
        date_patterns = [
            (r'last (\d+) days?', lambda m: {
                'date_from': (datetime.now() - timedelta(days=int(m.group(1)))).strftime('%Y-%m-%d'),
                'date_to': datetime.now().strftime('%Y-%m-%d')
            }),
            (r'(\d{4}-\d{2}-\d{2})', lambda m: {
                'date_from': m.group(1)
            })
        ]

        for pattern, extractor in date_patterns:
            match = re.search(pattern, query.lower())
            if match:
                parameters.update(extractor(match))
                break

        # Simple category/brand extraction
        if 'snacks' in query.lower():
            parameters['category'] = 'Snacks'
        elif 'beverages' in query.lower():
            parameters['category'] = 'Beverages'

        # Store extraction
        store_match = re.search(r'store (\d+)', query.lower())
        if store_match:
            parameters['store_id'] = int(store_match.group(1))

        return parameters

    def _build_sql(self, template: Template, parameters: Dict[str, Any]) -> str:
        """Build executable SQL with parameter substitution"""
        sql = template.sql_content

        # Handle parameter declarations
        param_declarations = []
        for param_name, param_value in parameters.items():
            if isinstance(param_value, str):
                param_declarations.append(f"DECLARE @{param_name} nvarchar(100) = '{param_value}';")
            elif isinstance(param_value, int):
                param_declarations.append(f"DECLARE @{param_name} int = {param_value};")
            elif isinstance(param_value, float):
                param_declarations.append(f"DECLARE @{param_name} float = {param_value};")

        # Add declarations at the beginning
        if param_declarations:
            sql = '\n'.join(param_declarations) + '\n\n' + sql

        return sql

def main():
    """CLI interface for RAG-CAG tools"""
    parser = argparse.ArgumentParser(description="Scout RAG-CAG Analytics Tool")
    parser.add_argument('--query', type=str, help="Natural language query")
    parser.add_argument('--template', type=str, help="Specific template ID")
    parser.add_argument('--params', type=str, help="JSON parameters")
    parser.add_argument('--engine', type=str, default='postgresql', choices=['postgresql', 'azuresql'])
    parser.add_argument('--validate-only', action='store_true', help="Only validate, don't execute")

    args = parser.parse_args()

    agent = RAGCAGAgent()

    if args.query:
        # Natural language query
        result = agent.process_query(args.query, args.engine)

        print(f"\n🎯 Template: {result.evidence.get('template_name', 'Unknown')}")
        print(f"📊 Engine: {result.engine}")
        print(f"⏱️ Execution: {result.execution_time_ms}ms")
        print(f"📈 Rows: {result.row_count}")
        print(f"✅ Valid: {result.validation_passed}")

        if result.error:
            print(f"❌ Error: {result.error}")
        else:
            print(f"\n📋 Sample Results:")
            for i, row in enumerate(result.rows[:5]):
                print(f"  {i+1}. {dict(list(row.items())[:3])}")

        print(f"\n📝 Evidence: {json.dumps(result.evidence, indent=2)}")

    elif args.template:
        # Direct template execution
        parameters = json.loads(args.params) if args.params else {}

        if args.validate_only:
            is_valid, message = agent.certifier.validate_template(args.template, parameters)
            print(f"Validation: {'✅ PASSED' if is_valid else '❌ FAILED'}")
            print(f"Message: {message}")
        else:
            template = agent.knowledge_base.templates.get(args.template)
            if template:
                sql = agent._build_sql(template, parameters)
                result = agent.executor.execute_query(sql, args.engine)
                print(f"Results: {result.row_count} rows in {result.execution_time_ms}ms")
            else:
                print(f"Template '{args.template}' not found")

    else:
        # List available templates
        print("📚 Available Templates:")
        for template_id, template in agent.knowledge_base.templates.items():
            print(f"  • {template_id}: {template.name}")
            print(f"    {template.business_question}")

if __name__ == "__main__":
    main()