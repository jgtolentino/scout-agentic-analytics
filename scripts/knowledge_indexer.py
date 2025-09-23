#!/usr/bin/env python3
"""
Scout Knowledge Corpus Indexer
Creates embeddings for RAG system knowledge base

Usage:
    python knowledge_indexer.py --create
    python knowledge_indexer.py --search "time analysis by category"
    python knowledge_indexer.py --update --source templates
"""

import os
import json
import yaml
import sqlite3
import logging
import argparse
from datetime import datetime
from typing import Dict, List, Optional, Any, Tuple
from pathlib import Path
import hashlib

import numpy as np
from sentence_transformers import SentenceTransformer
import pandas as pd

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class KnowledgeCorpus:
    """Knowledge corpus management for Scout RAG system"""

    def __init__(self, data_dir: str = "/Users/tbwa/scout-v7"):
        self.data_dir = Path(data_dir)
        self.db_path = self.data_dir / "knowledge_corpus.db"
        self.embeddings_model = SentenceTransformer('all-MiniLM-L6-v2')
        self.init_database()

    def init_database(self):
        """Initialize SQLite database for knowledge storage"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        # Create tables
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS documents (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                doc_id TEXT UNIQUE NOT NULL,
                content TEXT NOT NULL,
                doc_type TEXT NOT NULL,
                metadata TEXT NOT NULL,
                content_hash TEXT NOT NULL,
                embedding BLOB,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')

        cursor.execute('''
            CREATE TABLE IF NOT EXISTS templates (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                template_id TEXT UNIQUE NOT NULL,
                name TEXT NOT NULL,
                business_question TEXT NOT NULL,
                description TEXT NOT NULL,
                use_cases TEXT NOT NULL,
                parameters TEXT NOT NULL,
                performance_metrics TEXT NOT NULL,
                sql_content TEXT NOT NULL,
                embedding BLOB,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')

        cursor.execute('''
            CREATE TABLE IF NOT EXISTS kpi_definitions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                kpi_id TEXT UNIQUE NOT NULL,
                name TEXT NOT NULL,
                definition TEXT NOT NULL,
                calculation TEXT NOT NULL,
                business_context TEXT NOT NULL,
                embedding BLOB,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')

        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_documents_type ON documents(doc_type)
        ''')

        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_documents_hash ON documents(content_hash)
        ''')

        conn.commit()
        conn.close()

        logger.info(f"Knowledge database initialized at {self.db_path}")

    def index_sql_templates(self):
        """Index SQL templates from registry"""
        registry_path = self.data_dir / "sql_templates" / "template_registry.yaml"
        if not registry_path.exists():
            logger.error(f"Template registry not found at {registry_path}")
            return

        with open(registry_path, 'r') as f:
            registry = yaml.safe_load(f)

        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        templates_indexed = 0

        for template_id, template_data in registry['templates'].items():
            # Load SQL content
            sql_path = self.data_dir / "sql_templates" / f"{template_id}.sql"
            sql_content = ""
            if sql_path.exists():
                with open(sql_path, 'r') as f:
                    sql_content = f.read()

            # Prepare embedding text
            embedding_text = f"""
            {template_data['name']}
            {template_data['business_question']}
            {template_data['description']}
            Use cases: {', '.join(template_data.get('use_cases', []))}
            Parameters: {', '.join([p['name'] for p in template_data.get('parameters', {}).get('optional', [])])}
            """.strip()

            # Generate embedding
            embedding = self.embeddings_model.encode(embedding_text)
            embedding_blob = embedding.tobytes()

            # Insert or update template
            cursor.execute('''
                INSERT OR REPLACE INTO templates (
                    template_id, name, business_question, description, use_cases,
                    parameters, performance_metrics, sql_content, embedding
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                template_id,
                template_data['name'],
                template_data['business_question'],
                template_data['description'],
                json.dumps(template_data.get('use_cases', [])),
                json.dumps(template_data.get('parameters', {})),
                json.dumps(template_data.get('performance', {})),
                sql_content,
                embedding_blob
            ))

            templates_indexed += 1

        conn.commit()
        conn.close()

        logger.info(f"Indexed {templates_indexed} SQL templates")

    def index_kpi_definitions(self):
        """Index KPI definitions and business metrics"""
        kpis = [
            {
                'kpi_id': 'total_transactions',
                'name': 'Total Transactions',
                'definition': 'Count of all completed transactions in the specified time period',
                'calculation': 'COUNT(*) FROM scout_gold_transactions_flat WHERE conditions',
                'business_context': 'Primary volume metric for store performance and customer activity'
            },
            {
                'kpi_id': 'total_revenue',
                'name': 'Total Revenue',
                'definition': 'Sum of all transaction amounts in Philippine Pesos',
                'calculation': 'SUM(total_price) FROM scout_gold_transactions_flat WHERE conditions',
                'business_context': 'Key financial performance indicator for store and overall business performance'
            },
            {
                'kpi_id': 'average_transaction_value',
                'name': 'Average Transaction Value',
                'definition': 'Mean transaction amount across all transactions',
                'calculation': 'AVG(total_price) FROM scout_gold_transactions_flat WHERE conditions',
                'business_context': 'Indicator of customer spending behavior and basket composition'
            },
            {
                'kpi_id': 'unique_customers',
                'name': 'Unique Customers',
                'definition': 'Estimated count of distinct customers based on facial recognition',
                'calculation': 'COUNT(DISTINCT CONCAT(storeid, facialid)) WHERE conditions',
                'business_context': 'Customer base size and repeat visit analysis'
            },
            {
                'kpi_id': 'conversion_rate',
                'name': 'Conversion Rate',
                'definition': 'Percentage of customer interactions that result in purchases',
                'calculation': '100.0 * successful_transactions / total_interactions',
                'business_context': 'Effectiveness of store layout, pricing, and customer experience'
            },
            {
                'kpi_id': 'basket_size',
                'name': 'Average Basket Size',
                'definition': 'Average number of items per transaction',
                'calculation': 'AVG(item_count) FROM transactions GROUP BY transaction_id',
                'business_context': 'Customer purchase behavior and cross-selling effectiveness'
            },
            {
                'kpi_id': 'peak_hour_performance',
                'name': 'Peak Hour Performance',
                'definition': 'Transaction volume during highest activity periods',
                'calculation': 'MAX(hourly_transactions) FROM hourly_aggregation',
                'business_context': 'Staffing optimization and inventory planning for high-demand periods'
            },
            {
                'kpi_id': 'category_mix',
                'name': 'Category Mix',
                'definition': 'Distribution of sales across product categories',
                'calculation': 'COUNT(*) / total_transactions GROUP BY category',
                'business_context': 'Product portfolio performance and inventory allocation decisions'
            },
            {
                'kpi_id': 'payment_method_adoption',
                'name': 'Payment Method Adoption',
                'definition': 'Usage distribution across different payment methods',
                'calculation': 'COUNT(*) / total_transactions GROUP BY payment_method',
                'business_context': 'Digital payment adoption and customer payment preferences'
            },
            {
                'kpi_id': 'substitution_rate',
                'name': 'Product Substitution Rate',
                'definition': 'Percentage of transactions involving product substitutions',
                'calculation': 'COUNT(substitution_events) / COUNT(total_transactions) * 100',
                'business_context': 'Inventory availability and customer satisfaction with product alternatives'
            }
        ]

        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        for kpi in kpis:
            # Prepare embedding text
            embedding_text = f"""
            {kpi['name']}
            {kpi['definition']}
            {kpi['business_context']}
            Calculation: {kpi['calculation']}
            """.strip()

            # Generate embedding
            embedding = self.embeddings_model.encode(embedding_text)
            embedding_blob = embedding.tobytes()

            # Insert KPI definition
            cursor.execute('''
                INSERT OR REPLACE INTO kpi_definitions (
                    kpi_id, name, definition, calculation, business_context, embedding
                ) VALUES (?, ?, ?, ?, ?, ?)
            ''', (
                kpi['kpi_id'],
                kpi['name'],
                kpi['definition'],
                kpi['calculation'],
                kpi['business_context'],
                embedding_blob
            ))

        conn.commit()
        conn.close()

        logger.info(f"Indexed {len(kpis)} KPI definitions")

    def index_data_dictionary(self):
        """Index data dictionary and field definitions"""
        # Scout data schema documentation
        schema_docs = [
            {
                'doc_id': 'schema_transactions_flat',
                'content': '''
                scout_gold_transactions_flat - Primary analytics table
                Fields: date_ph (transaction date), time_ph (transaction time), storename (store name),
                category (product category), brand (product brand), product (product name),
                total_price (transaction amount in PHP), payment_method (payment type),
                gender (customer gender), agebracket (customer age group), location (store location),
                transaction_id (unique transaction identifier), storeid (store identifier)
                ''',
                'doc_type': 'schema',
                'metadata': {'table': 'scout_gold_transactions_flat', 'layer': 'gold'}
            },
            {
                'doc_id': 'schema_stores',
                'content': '''
                dbo.Stores - Store master data with geographic information
                Fields: StoreID (unique identifier), StoreName (store name), Location (address),
                MunicipalityName (city/municipality), BarangayName (barangay),
                GeoLatitude (latitude coordinate), GeoLongitude (longitude coordinate),
                StorePolygon (GeoJSON polygon for choropleth mapping), Region (NCR),
                psgc_citymun (PSGC city code), DeviceID (Scout device identifier)
                ''',
                'doc_type': 'schema',
                'metadata': {'table': 'dbo.Stores', 'layer': 'dimension'}
            },
            {
                'doc_id': 'governance_ncr_bounds',
                'content': '''
                NCR Geographic Bounds Governance
                All Scout stores must be within Metro Manila (NCR) bounds:
                Latitude: 14.20 to 14.90 degrees North
                Longitude: 120.90 to 121.20 degrees East
                Region must be 'NCR', Province must be 'Metro Manila'
                This ensures data quality and regional compliance for Scout operations
                ''',
                'doc_type': 'governance',
                'metadata': {'rule_type': 'geographic', 'compliance': 'mandatory'}
            },
            {
                'doc_id': 'business_rules_dayparts',
                'content': '''
                Daypart Classification Rules for Time Analysis
                Morning: 6:00 AM - 11:59 AM (peak breakfast and early shopping)
                Afternoon: 12:00 PM - 5:59 PM (lunch and afternoon shopping)
                Evening: 6:00 PM - 9:59 PM (dinner and evening shopping)
                Night: 10:00 PM - 5:59 AM (late night and early morning)
                Used for time-based analytics and staffing optimization
                ''',
                'doc_type': 'business_rule',
                'metadata': {'rule_type': 'temporal', 'usage': 'analytics'}
            },
            {
                'doc_id': 'data_quality_standards',
                'content': '''
                Scout Data Quality Standards
                Minimum transaction amount: ₱1.00 (no zero or negative transactions)
                Required fields: StoreID, TransactionDate, TotalPrice, Category
                Geographic compliance: All coordinates within NCR bounds
                Statistical significance: Minimum 3-5 transactions for analysis inclusion
                Data freshness: Maximum 60 minutes delay for real-time reporting
                ''',
                'doc_type': 'governance',
                'metadata': {'rule_type': 'quality', 'enforcement': 'automatic'}
            }
        ]

        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        for doc in schema_docs:
            # Generate content hash
            content_hash = hashlib.md5(doc['content'].encode()).hexdigest()

            # Check if content has changed
            cursor.execute('SELECT content_hash FROM documents WHERE doc_id = ?', (doc['doc_id'],))
            existing = cursor.fetchone()

            if existing and existing[0] == content_hash:
                continue  # Skip if unchanged

            # Generate embedding
            embedding = self.embeddings_model.encode(doc['content'])
            embedding_blob = embedding.tobytes()

            # Insert or update document
            cursor.execute('''
                INSERT OR REPLACE INTO documents (
                    doc_id, content, doc_type, metadata, content_hash, embedding, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            ''', (
                doc['doc_id'],
                doc['content'],
                doc['doc_type'],
                json.dumps(doc['metadata']),
                content_hash,
                embedding_blob
            ))

        conn.commit()
        conn.close()

        logger.info(f"Indexed {len(schema_docs)} data dictionary documents")

    def search_knowledge(self, query: str, doc_types: List[str] = None, top_k: int = 5) -> List[Dict]:
        """Search knowledge corpus for relevant information"""
        # Generate query embedding
        query_embedding = self.embeddings_model.encode(query)

        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        results = []

        # Search templates
        if not doc_types or 'template' in doc_types:
            cursor.execute('SELECT template_id, name, business_question, description, embedding FROM templates')
            for row in cursor.fetchall():
                template_id, name, business_question, description, embedding_blob = row
                if embedding_blob:
                    embedding = np.frombuffer(embedding_blob, dtype=np.float32)
                    similarity = np.dot(query_embedding, embedding) / (
                        np.linalg.norm(query_embedding) * np.linalg.norm(embedding)
                    )
                    results.append({
                        'type': 'template',
                        'id': template_id,
                        'title': name,
                        'content': f"{business_question}\n{description}",
                        'similarity': float(similarity)
                    })

        # Search KPI definitions
        if not doc_types or 'kpi' in doc_types:
            cursor.execute('SELECT kpi_id, name, definition, business_context, embedding FROM kpi_definitions')
            for row in cursor.fetchall():
                kpi_id, name, definition, business_context, embedding_blob = row
                if embedding_blob:
                    embedding = np.frombuffer(embedding_blob, dtype=np.float32)
                    similarity = np.dot(query_embedding, embedding) / (
                        np.linalg.norm(query_embedding) * np.linalg.norm(embedding)
                    )
                    results.append({
                        'type': 'kpi',
                        'id': kpi_id,
                        'title': name,
                        'content': f"{definition}\n{business_context}",
                        'similarity': float(similarity)
                    })

        # Search documents
        if not doc_types or any(dt in ['schema', 'governance', 'business_rule'] for dt in doc_types):
            type_filter = ""
            if doc_types:
                type_filter = " WHERE doc_type IN ({})".format(','.join(f"'{dt}'" for dt in doc_types))

            cursor.execute(f'SELECT doc_id, content, doc_type, metadata, embedding FROM documents{type_filter}')
            for row in cursor.fetchall():
                doc_id, content, doc_type, metadata_json, embedding_blob = row
                if embedding_blob:
                    embedding = np.frombuffer(embedding_blob, dtype=np.float32)
                    similarity = np.dot(query_embedding, embedding) / (
                        np.linalg.norm(query_embedding) * np.linalg.norm(embedding)
                    )
                    metadata = json.loads(metadata_json)
                    results.append({
                        'type': doc_type,
                        'id': doc_id,
                        'title': metadata.get('table', doc_id),
                        'content': content,
                        'similarity': float(similarity)
                    })

        conn.close()

        # Sort by similarity and return top-k
        results.sort(key=lambda x: x['similarity'], reverse=True)
        return results[:top_k]

    def get_stats(self) -> Dict[str, int]:
        """Get knowledge corpus statistics"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        stats = {}

        cursor.execute('SELECT COUNT(*) FROM templates')
        stats['templates'] = cursor.fetchone()[0]

        cursor.execute('SELECT COUNT(*) FROM kpi_definitions')
        stats['kpis'] = cursor.fetchone()[0]

        cursor.execute('SELECT COUNT(*) FROM documents')
        stats['documents'] = cursor.fetchone()[0]

        cursor.execute('SELECT doc_type, COUNT(*) FROM documents GROUP BY doc_type')
        stats['documents_by_type'] = {doc_type: count for doc_type, count in cursor.fetchall()}

        conn.close()

        return stats

    def export_corpus(self, output_path: str):
        """Export knowledge corpus to JSON for backup/analysis"""
        conn = sqlite3.connect(self.db_path)

        # Export to DataFrames
        templates_df = pd.read_sql_query('SELECT * FROM templates', conn)
        kpis_df = pd.read_sql_query('SELECT * FROM kpi_definitions', conn)
        documents_df = pd.read_sql_query('SELECT * FROM documents', conn)

        conn.close()

        # Convert to dict and save
        export_data = {
            'templates': templates_df.to_dict('records'),
            'kpis': kpis_df.to_dict('records'),
            'documents': documents_df.to_dict('records'),
            'exported_at': datetime.now().isoformat(),
            'stats': self.get_stats()
        }

        with open(output_path, 'w') as f:
            json.dump(export_data, f, indent=2, default=str)

        logger.info(f"Knowledge corpus exported to {output_path}")

def main():
    """CLI interface for knowledge indexer"""
    parser = argparse.ArgumentParser(description="Scout Knowledge Corpus Indexer")
    parser.add_argument('--create', action='store_true', help="Create complete knowledge corpus")
    parser.add_argument('--update', action='store_true', help="Update existing corpus")
    parser.add_argument('--source', type=str, choices=['templates', 'kpis', 'docs', 'all'], default='all',
                       help="Source to update")
    parser.add_argument('--search', type=str, help="Search query")
    parser.add_argument('--export', type=str, help="Export corpus to JSON file")
    parser.add_argument('--stats', action='store_true', help="Show corpus statistics")

    args = parser.parse_args()

    corpus = KnowledgeCorpus()

    if args.create or args.update:
        logger.info("Building knowledge corpus...")

        if args.source in ['templates', 'all']:
            corpus.index_sql_templates()

        if args.source in ['kpis', 'all']:
            corpus.index_kpi_definitions()

        if args.source in ['docs', 'all']:
            corpus.index_data_dictionary()

        logger.info("Knowledge corpus indexing complete")

    if args.search:
        logger.info(f"Searching for: {args.search}")
        results = corpus.search_knowledge(args.search)

        print(f"\n🔍 Search Results for '{args.search}':")
        print("=" * 60)

        for i, result in enumerate(results, 1):
            print(f"\n{i}. [{result['type'].upper()}] {result['title']}")
            print(f"   Similarity: {result['similarity']:.3f}")
            print(f"   Content: {result['content'][:200]}...")

    if args.stats:
        stats = corpus.get_stats()
        print(f"\n📊 Knowledge Corpus Statistics:")
        print(f"Templates: {stats['templates']}")
        print(f"KPIs: {stats['kpis']}")
        print(f"Documents: {stats['documents']}")
        print(f"By Type: {stats['documents_by_type']}")

    if args.export:
        corpus.export_corpus(args.export)

if __name__ == "__main__":
    main()