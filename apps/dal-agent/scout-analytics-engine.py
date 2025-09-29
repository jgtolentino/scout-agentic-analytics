#!/usr/bin/env python3
"""
Scout Analytics Engine - Zero-subscription local analytics with AI
"""

import sqlite3
import json
import pandas as pd
import numpy as np
from typing import Dict, List, Any, Optional
from datetime import datetime, timedelta
import chromadb
from sentence_transformers import SentenceTransformer
import subprocess
import os
from pathlib import Path

class ScoutAnalyticsEngine:
    """Core analytics engine with local AI capabilities"""
    
    def __init__(self, db_path: str = "scout_analytics.db"):
        self.db_path = db_path
        self.conn = sqlite3.connect(db_path)
        self.embedding_model = SentenceTransformer('all-MiniLM-L6-v2')
        self.chroma_client = chromadb.PersistentClient(path="./chroma_db")
        self.collection = self._init_vector_store()
        self._init_database()
        
    def _init_database(self):
        """Initialize SQLite database with Scout schema"""
        cursor = self.conn.cursor()
        
        # Create tables matching Scout production schema
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS transactions (
            TransactionID TEXT PRIMARY KEY,
            StoreCode TEXT,
            StoreName TEXT,
            BrandCode TEXT,
            BrandName TEXT,
            CategoryCode TEXT,
            CategoryName TEXT,
            Quantity INTEGER,
            Value REAL,
            TransactionDate TEXT,
            Region TEXT,
            Province TEXT,
            Municipality TEXT,
            GeoLatitude REAL,
            GeoLongitude REAL
        )
        """)
        
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS brands (
            BrandCode TEXT PRIMARY KEY,
            BrandName TEXT,
            Category TEXT,
            Subcategory TEXT,
            Manufacturer TEXT
        )
        """)
        
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS stores (
            StoreCode TEXT PRIMARY KEY,
            StoreName TEXT,
            Region TEXT,
            Province TEXT,
            Municipality TEXT,
            GeoLatitude REAL,
            GeoLongitude REAL,
            StoreType TEXT
        )
        """)
        
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS analytics_cache (
            query_hash TEXT PRIMARY KEY,
            query TEXT,
            result TEXT,
            created_at TEXT,
            ttl INTEGER
        )
        """)
        
        self.conn.commit()
    
    def _init_vector_store(self):
        """Initialize ChromaDB collection"""
        try:
            return self.chroma_client.get_collection(name="scout_analytics")
        except:
            return self.chroma_client.create_collection(
                name="scout_analytics",
                metadata={"hnsw:space": "cosine"}
            )
    
    def ingest_production_data(self, data_path: str):
        """Ingest production data from JSON/CSV files"""
        if data_path.endswith('.json'):
            with open(data_path, 'r') as f:
                data = json.load(f)
                
            # Handle brand mapping data
            if 'brands' in data:
                df_brands = pd.DataFrame(data['brands'])
                df_brands.to_sql('brands', self.conn, if_exists='replace', index=False)
                
            # Handle transaction data
            if 'transactions' in data:
                df_transactions = pd.DataFrame(data['transactions'])
                df_transactions.to_sql('transactions', self.conn, if_exists='append', index=False)
                
        elif data_path.endswith('.csv'):
            df = pd.read_csv(data_path)
            df.to_sql('transactions', self.conn, if_exists='append', index=False)
            
        # Create embeddings for semantic search
        self._create_embeddings()
        
        return {"status": "success", "message": f"Data ingested from {data_path}"}
    
    def _create_embeddings(self):
        """Create embeddings for semantic search"""
        cursor = self.conn.cursor()
        
        # Get unique brands and categories
        cursor.execute("SELECT DISTINCT BrandName, CategoryName FROM transactions")
        items = cursor.fetchall()
        
        documents = []
        embeddings = []
        ids = []
        
        for i, (brand, category) in enumerate(items):
            doc_text = f"Brand: {brand}, Category: {category}"
            documents.append(doc_text)
            embedding = self.embedding_model.encode(doc_text).tolist()
            embeddings.append(embedding)
            ids.append(f"doc_{i}")
            
        # Add to ChromaDB
        if documents:
            self.collection.add(
                documents=documents,
                embeddings=embeddings,
                ids=ids
            )
    
    def query(self, natural_query: str) -> Dict[str, Any]:
        """Process natural language query"""
        # Check cache first
        query_hash = hash(natural_query)
        cached = self._get_cached_result(str(query_hash))
        if cached:
            return cached
        
        # Convert to SQL
        sql_query = self._natural_to_sql(natural_query)
        
        # Execute query
        try:
            df = pd.read_sql(sql_query, self.conn)
            result = {
                "query": natural_query,
                "sql": sql_query,
                "data": df.to_dict('records'),
                "rows": len(df),
                "columns": list(df.columns)
            }
            
            # Cache result
            self._cache_result(str(query_hash), natural_query, result)
            
            return result
            
        except Exception as e:
            return {"error": str(e), "query": natural_query, "sql": sql_query}
    
    def _natural_to_sql(self, query: str) -> str:
        """Convert natural language to SQL using patterns"""
        query_lower = query.lower()
        
        # Pattern matching for common queries
        if "top" in query_lower and "brand" in query_lower:
            match = re.search(r'top (\d+)', query_lower)
            limit = match.group(1) if match else 10
            return f"""
                SELECT BrandName, SUM(Value) as TotalSales, COUNT(*) as Transactions
                FROM transactions
                GROUP BY BrandName
                ORDER BY TotalSales DESC
                LIMIT {limit}
            """
            
        elif "sales" in query_lower and "month" in query_lower:
            return """
                SELECT strftime('%Y-%m', TransactionDate) as Month,
                       SUM(Value) as TotalSales,
                       COUNT(*) as Transactions
                FROM transactions
                GROUP BY Month
                ORDER BY Month
            """
            
        elif "category" in query_lower:
            return """
                SELECT CategoryName, SUM(Value) as TotalSales,
                       COUNT(DISTINCT BrandName) as UniqueBrands
                FROM transactions
                GROUP BY CategoryName
                ORDER BY TotalSales DESC
            """
            
        elif "store" in query_lower and "performance" in query_lower:
            return """
                SELECT StoreName, Region, 
                       SUM(Value) as TotalSales,
                       COUNT(*) as Transactions,
                       AVG(Value) as AvgTransactionValue
                FROM transactions
                GROUP BY StoreName, Region
                ORDER BY TotalSales DESC
                LIMIT 20
            """
            
        else:
            # Default query
            return "SELECT * FROM transactions LIMIT 100"
    
    def analyze(self, analysis_type: str = "summary") -> Dict[str, Any]:
        """Perform data analysis"""
        cursor = self.conn.cursor()
        
        if analysis_type == "summary":
            # Get summary statistics
            cursor.execute("""
                SELECT 
                    COUNT(*) as total_transactions,
                    COUNT(DISTINCT BrandCode) as unique_brands,
                    COUNT(DISTINCT StoreCode) as unique_stores,
                    SUM(Value) as total_revenue,
                    AVG(Value) as avg_transaction_value,
                    MIN(TransactionDate) as earliest_date,
                    MAX(TransactionDate) as latest_date
                FROM transactions
            """)
            
            summary = dict(zip([d[0] for d in cursor.description], cursor.fetchone()))
            
            # Top categories
            cursor.execute("""
                SELECT CategoryName, SUM(Value) as revenue
                FROM transactions
                GROUP BY CategoryName
                ORDER BY revenue DESC
                LIMIT 5
            """)
            
            top_categories = [dict(zip([d[0] for d in cursor.description], row)) 
                            for row in cursor.fetchall()]
            
            return {
                "summary": summary,
                "top_categories": top_categories,
                "analysis_type": analysis_type
            }
            
        elif analysis_type == "trends":
            # Monthly trends
            cursor.execute("""
                SELECT 
                    strftime('%Y-%m', TransactionDate) as month,
                    SUM(Value) as revenue,
                    COUNT(*) as transactions
                FROM transactions
                GROUP BY month
                ORDER BY month
            """)
            
            trends = [dict(zip([d[0] for d in cursor.description], row)) 
                     for row in cursor.fetchall()]
            
            return {"trends": trends, "analysis_type": analysis_type}
            
        elif analysis_type == "geographic":
            # Geographic distribution
            cursor.execute("""
                SELECT 
                    Region,
                    COUNT(DISTINCT StoreCode) as stores,
                    SUM(Value) as revenue,
                    AVG(Value) as avg_transaction
                FROM transactions
                GROUP BY Region
                ORDER BY revenue DESC
            """)
            
            geographic = [dict(zip([d[0] for d in cursor.description], row)) 
                         for row in cursor.fetchall()]
            
            return {"geographic": geographic, "analysis_type": analysis_type}
    
    def semantic_search(self, query: str, k: int = 5) -> List[Dict]:
        """Perform semantic search using embeddings"""
        # Get query embedding
        query_embedding = self.embedding_model.encode(query).tolist()
        
        # Search in ChromaDB
        results = self.collection.query(
            query_embeddings=[query_embedding],
            n_results=k
        )
        
        if results['documents']:
            return [
                {"document": doc, "distance": dist}
                for doc, dist in zip(results['documents'][0], results['distances'][0])
            ]
        return []
    
    def generate_insights(self, use_ollama: bool = False) -> Dict[str, Any]:
        """Generate AI insights using local LLM"""
        cursor = self.conn.cursor()
        
        # Get data for insights
        cursor.execute("""
            SELECT 
                COUNT(DISTINCT BrandCode) as brands,
                COUNT(DISTINCT CategoryName) as categories,
                SUM(Value) as total_revenue,
                AVG(Value) as avg_transaction
            FROM transactions
        """)
        
        stats = dict(zip([d[0] for d in cursor.description], cursor.fetchone()))
        
        if use_ollama:
            # Use Ollama for local LLM
            prompt = f"""
            Analyze these retail metrics and provide 3 key insights:
            - {stats['brands']} unique brands
            - {stats['categories']} categories
            - Total revenue: {stats['total_revenue']:.2f}
            - Average transaction: {stats['avg_transaction']:.2f}
            
            Provide actionable business insights.
            """
            
            try:
                result = subprocess.run(
                    ['ollama', 'run', 'llama2', prompt],
                    capture_output=True,
                    text=True
                )
                insights = result.stdout
            except:
                insights = "Ollama not available. Using rule-based insights."
        else:
            # Rule-based insights
            insights = self._generate_rule_based_insights(stats)
        
        return {
            "statistics": stats,
            "insights": insights,
            "generated_at": datetime.now().isoformat()
        }
    
    def _generate_rule_based_insights(self, stats: Dict) -> str:
        """Generate insights using rules"""
        insights = []
        
        if stats['avg_transaction'] > 100:
            insights.append("High average transaction value indicates premium product focus")
        else:
            insights.append("Low average transaction value suggests volume-based strategy")
            
        if stats['brands'] > 100:
            insights.append("Wide brand portfolio offers diverse customer choices")
        else:
            insights.append("Focused brand strategy may improve operational efficiency")
            
        if stats['categories'] > 15:
            insights.append("Diverse category mix reduces dependency on single segment")
            
        return "\n".join(insights)
    
    def _cache_result(self, query_hash: str, query: str, result: Dict):
        """Cache query results"""
        cursor = self.conn.cursor()
        cursor.execute("""
            INSERT OR REPLACE INTO analytics_cache 
            (query_hash, query, result, created_at, ttl)
            VALUES (?, ?, ?, ?, ?)
        """, (query_hash, query, json.dumps(result), 
               datetime.now().isoformat(), 3600))
        self.conn.commit()
    
    def _get_cached_result(self, query_hash: str) -> Optional[Dict]:
        """Get cached result if available"""
        cursor = self.conn.cursor()
        cursor.execute("""
            SELECT result, created_at, ttl FROM analytics_cache
            WHERE query_hash = ?
        """, (query_hash,))
        
        row = cursor.fetchone()
        if row:
            result, created_at, ttl = row
            # Check if cache is still valid
            created_time = datetime.fromisoformat(created_at)
            if (datetime.now() - created_time).seconds < ttl:
                return json.loads(result)
        return None
    
    def export_api_response(self, endpoint: str, **kwargs) -> Dict:
        """Format responses for API consumption"""
        if endpoint == "/query":
            return self.query(kwargs.get('q', ''))
        elif endpoint == "/analyze":
            return self.analyze(kwargs.get('type', 'summary'))
        elif endpoint == "/search":
            return {"results": self.semantic_search(kwargs.get('q', ''))}
        elif endpoint == "/insights":
            return self.generate_insights(kwargs.get('ollama', False))
        else:
            return {"error": "Unknown endpoint"}

# Simple API wrapper for existing UI
class ScoutAnalyticsAPI:
    """API wrapper for Scout Analytics Engine"""
    
    def __init__(self, engine: ScoutAnalyticsEngine):
        self.engine = engine
    
    def handle_request(self, method: str, path: str, params: Dict) -> Dict:
        """Handle API requests"""
        if method == "GET":
            if path == "/api/query":
                return self.engine.query(params.get('q', ''))
            elif path == "/api/analyze":
                return self.engine.analyze(params.get('type', 'summary'))
            elif path == "/api/search":
                return {"results": self.engine.semantic_search(params.get('q', ''))}
            elif path == "/api/insights":
                return self.engine.generate_insights()
            elif path == "/api/stats":
                return self.engine.analyze('summary')
        
        elif method == "POST":
            if path == "/api/ingest":
                return self.engine.ingest_production_data(params.get('path', ''))
        
        return {"error": "Invalid request"}

if __name__ == "__main__":
    # Initialize engine
    engine = ScoutAnalyticsEngine()
    
    # Load production data if available
    data_file = "/Users/tbwa/scout-v7/apps/dal-agent/out/complete_brand_mapping.json"
    if os.path.exists(data_file):
        print("Loading production data...")
        engine.ingest_production_data(data_file)
    
    # Example usage
    print("\n=== Scout Analytics Engine ===")
    print("\n1. Summary Analysis:")
    print(json.dumps(engine.analyze('summary'), indent=2))
    
    print("\n2. Natural Language Query:")
    result = engine.query("Show top 5 brands by sales")
    print(f"SQL Generated: {result.get('sql')}")
    print(f"Results: {result.get('rows')} rows returned")
    
    print("\n3. Semantic Search:")
    search_results = engine.semantic_search("beverages coca-cola")
    print(f"Found {len(search_results)} relevant documents")
    
    print("\n4. AI Insights:")
    insights = engine.generate_insights()
    print(insights.get('insights'))
    
    print("\nEngine ready for API integration!")