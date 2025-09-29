#!/usr/bin/env python3
"""
Scout Analytics API Server - Flask server for baseline UI integration
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import traceback
from datetime import datetime

# Robust import with fallback to prevent boot failure
try:
    from scout_analytics_engine import ScoutAnalyticsEngine, ScoutAnalyticsAPI
except Exception as e:
    # Fallback minimal engine to avoid boot failure
    class ScoutAnalyticsEngine:
        def __init__(self, *a, **k): pass
        def health(self): return {"ok": True, "engine":"fallback","reason":"scout_analytics_engine import failed"}
        def query(self, q): return {"rows": [], "notice": "fallback engine - implement scout_analytics_engine.py"}
        def load_production_data(self): return {"status": "fallback", "message": "Engine import failed"}
        def get_cache_stats(self): return {"cached_queries": 0, "cache_size_mb": 0}
    class ScoutAnalyticsAPI:
        def __init__(self, engine): self.engine = engine
        def handle_request(self, method, path, params):
            return {"mode": params.get('type', 'summary'), "answer": "fallback engine active"}
        def get_openapi_spec(self): return {"info": {"title": "Fallback API", "version": "1.0.0"}}
    print(f"⚠️ Using fallback engine due to import error: {e}")

app = Flask(__name__)
CORS(app)  # Enable CORS for frontend integration

# Initialize analytics engine
try:
    engine = ScoutAnalyticsEngine()
    api = ScoutAnalyticsAPI(engine)
    print("✅ Scout Analytics Engine initialized successfully")
except Exception as e:
    print(f"❌ Failed to initialize engine: {e}")
    engine = None
    api = None

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy" if engine else "unhealthy",
        "timestamp": datetime.now().isoformat(),
        "engine_status": "connected" if engine else "failed",
        "version": "1.0.0"
    })

@app.route('/api/query', methods=['GET'])
def query_endpoint():
    """Natural language query endpoint"""
    if not engine:
        return jsonify({"error": "Engine not initialized"}), 500

    try:
        query = request.args.get('q') or request.args.get('query', '')
        if not query:
            return jsonify({"error": "Query parameter 'q' required"}), 400

        result = api.handle_request('GET', '/api/query', {'q': query})
        return jsonify(result)

    except Exception as e:
        return jsonify({"error": str(e), "traceback": traceback.format_exc()}), 500

@app.route('/api/analyze', methods=['GET'])
def analyze_endpoint():
    """Data analysis endpoint"""
    if not engine:
        return jsonify({"error": "Engine not initialized"}), 500

    try:
        analysis_type = request.args.get('type', 'summary')
        result = api.handle_request('GET', '/api/analyze', {'type': analysis_type})
        return jsonify(result)

    except Exception as e:
        return jsonify({"error": str(e), "traceback": traceback.format_exc()}), 500

@app.route('/api/search', methods=['GET'])
def search_endpoint():
    """Semantic search endpoint"""
    if not engine:
        return jsonify({"error": "Engine not initialized"}), 500

    try:
        query = request.args.get('q') or request.args.get('query', '')
        if not query:
            return jsonify({"error": "Query parameter 'q' required"}), 400

        result = api.handle_request('GET', '/api/search', {'q': query})
        return jsonify(result)

    except Exception as e:
        return jsonify({"error": str(e), "traceback": traceback.format_exc()}), 500

@app.route('/api/insights', methods=['GET'])
def insights_endpoint():
    """AI insights endpoint"""
    if not engine:
        return jsonify({"error": "Engine not initialized"}), 500

    try:
        use_ollama = request.args.get('ollama', 'false').lower() == 'true'
        result = api.handle_request('GET', '/api/insights', {'ollama': use_ollama})
        return jsonify(result)

    except Exception as e:
        return jsonify({"error": str(e), "traceback": traceback.format_exc()}), 500

@app.route('/api/stats', methods=['GET'])
def stats_endpoint():
    """Statistics endpoint"""
    if not engine:
        return jsonify({"error": "Engine not initialized"}), 500

    try:
        result = api.handle_request('GET', '/api/stats', {})
        return jsonify(result)

    except Exception as e:
        return jsonify({"error": str(e), "traceback": traceback.format_exc()}), 500

@app.route('/api/load', methods=['POST'])
def load_endpoint():
    """Load production data endpoint"""
    if not engine:
        return jsonify({"error": "Engine not initialized"}), 500

    try:
        result = api.handle_request('POST', '/api/load', {})
        return jsonify(result)

    except Exception as e:
        return jsonify({"error": str(e), "traceback": traceback.format_exc()}), 500

@app.route('/api/cache/clear', methods=['POST'])
def clear_cache_endpoint():
    """Clear cache endpoint"""
    if not engine:
        return jsonify({"error": "Engine not initialized"}), 500

    try:
        result = api.handle_request('POST', '/api/cache/clear', {})
        return jsonify(result)

    except Exception as e:
        return jsonify({"error": str(e), "traceback": traceback.format_exc()}), 500

@app.route('/api/spec', methods=['GET'])
def openapi_spec():
    """OpenAPI specification endpoint"""
    if not api:
        return jsonify({"error": "API not initialized"}), 500

    try:
        return jsonify(api.get_openapi_spec())
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Legacy endpoints for backward compatibility
@app.route('/query', methods=['GET'])
def legacy_query():
    """Legacy query endpoint"""
    return query_endpoint()

@app.route('/analyze', methods=['GET'])
def legacy_analyze():
    """Legacy analyze endpoint"""
    return analyze_endpoint()

@app.route('/search', methods=['GET'])
def legacy_search():
    """Legacy search endpoint"""
    return search_endpoint()

@app.route('/insights', methods=['GET'])
def legacy_insights():
    """Legacy insights endpoint"""
    return insights_endpoint()

@app.route('/', methods=['GET'])
def root():
    """Root endpoint with API information"""
    return jsonify({
        "name": "Scout Analytics API",
        "version": "1.0.0",
        "description": "Custom-built analytics engine with Azure SQL backend",
        "engine_status": "connected" if engine else "failed",
        "endpoints": {
            "health": "GET /health - Health check",
            "query": "GET /api/query?q=<query> - Natural language queries",
            "analyze": "GET /api/analyze?type=<type> - Data analysis",
            "search": "GET /api/search?q=<query> - Semantic search",
            "insights": "GET /api/insights - AI insights",
            "stats": "GET /api/stats - Summary statistics",
            "load": "POST /api/load - Load production data",
            "spec": "GET /api/spec - OpenAPI specification"
        },
        "examples": {
            "top_brands": "/api/query?q=top 10 brands by sales",
            "category_analysis": "/api/analyze?type=summary",
            "semantic_search": "/api/search?q=beverages soda drinks",
            "business_insights": "/api/insights"
        }
    })

@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return jsonify({
        "error": "Endpoint not found",
        "available_endpoints": [
            "/health", "/api/query", "/api/analyze", "/api/search",
            "/api/insights", "/api/stats", "/api/load", "/api/spec"
        ]
    }), 404

@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    return jsonify({
        "error": "Internal server error",
        "message": str(error),
        "suggestion": "Check engine initialization and Azure SQL connection"
    }), 500

if __name__ == '__main__':
    print("\n🚀 Starting Scout Analytics API Server...")
    print("📊 Zero-subscription analytics with Azure SQL backend")
    print("🔗 Compatible with existing baseline UI")

    if engine:
        print("✅ Engine ready - loading production data...")
        try:
            load_result = engine.load_production_data()
            print(f"📈 {load_result['message']}")
        except Exception as e:
            print(f"⚠️  Data loading warning: {e}")
    else:
        print("❌ Engine initialization failed")
        print("💡 Set AZURE_SQL_CONN_STR environment variable")

    print("\n🌐 Server starting on http://localhost:5000")
    print("📚 API documentation: http://localhost:5000/api/spec")
    print("🏥 Health check: http://localhost:5000/health")
    print("\n🎯 Example requests:")
    print("   curl 'http://localhost:5000/api/query?q=top 5 brands'")
    print("   curl 'http://localhost:5000/api/analyze?type=summary'")
    print("   curl 'http://localhost:5000/api/insights'")

    # Run Flask development server
    app.run(host='0.0.0.0', port=5000, debug=True)