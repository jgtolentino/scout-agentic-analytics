#!/usr/bin/env python3
"""
Scout Analytics - Observability Integration
App Insights telemetry for Flask & Azure Functions
"""

import logging
import os
import time
from functools import wraps
from typing import Dict, Any, Optional

# Try to import Azure monitoring
try:
    from opencensus.ext.azure.log_exporter import AzureLogHandler
    from opencensus.ext.azure.trace_exporter import AzureExporter
    from opencensus.trace.tracer import Tracer
    from opencensus.trace import config_integration
    from opencensus.ext.flask.flask_middleware import FlaskMiddleware
    AZURE_MONITORING_AVAILABLE = True
except ImportError:
    AZURE_MONITORING_AVAILABLE = False

class ScoutTelemetry:
    """Scout Analytics telemetry and observability"""

    def __init__(self, app=None):
        self.app = app
        self.logger = None
        self.tracer = None
        self.connection_string = os.getenv("APPINSIGHTS_CONNECTION_STRING")

        if self.connection_string and AZURE_MONITORING_AVAILABLE:
            self._setup_azure_monitoring()
        else:
            self._setup_local_logging()

        if app:
            self.init_app(app)

    def _setup_azure_monitoring(self):
        """Setup Azure Application Insights monitoring"""
        try:
            # Setup logging
            self.logger = logging.getLogger("scout")
            azure_handler = AzureLogHandler(connection_string=self.connection_string)
            azure_handler.setLevel(logging.INFO)

            formatter = logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
            azure_handler.setFormatter(formatter)

            self.logger.addHandler(azure_handler)
            self.logger.setLevel(logging.INFO)

            # Setup tracing
            config_integration.trace_integrations(['requests', 'sqlalchemy'])
            self.tracer = Tracer(exporter=AzureExporter(connection_string=self.connection_string))

            self.logger.info("✅ Azure Application Insights initialized")

        except Exception as e:
            print(f"⚠️ Azure monitoring setup failed: {e}")
            self._setup_local_logging()

    def _setup_local_logging(self):
        """Setup local logging fallback"""
        self.logger = logging.getLogger("scout")
        handler = logging.StreamHandler()
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        handler.setFormatter(formatter)
        self.logger.addHandler(handler)
        self.logger.setLevel(logging.INFO)

        print("ℹ️ Using local logging (Azure App Insights not available)")

    def init_app(self, app):
        """Initialize Flask app with telemetry"""
        self.app = app

        if AZURE_MONITORING_AVAILABLE and self.connection_string:
            # Add Flask middleware for automatic request tracing
            FlaskMiddleware(app, exporter=AzureExporter(connection_string=self.connection_string))

    def log_sql_execution(self, sql: str, params: Optional[Dict] = None,
                         rows_returned: int = 0, execution_time_ms: float = 0,
                         cache_hit: bool = False):
        """Log SQL execution with telemetry"""
        log_data = {
            "sql_query": sql[:200] + "..." if len(sql) > 200 else sql,  # Truncate long queries
            "parameters": str(params) if params else None,
            "rows_returned": rows_returned,
            "execution_time_ms": round(execution_time_ms, 2),
            "cache_hit": cache_hit,
            "operation": "sql_execution"
        }

        if cache_hit:
            self.logger.info("SQL Cache Hit", extra=log_data)
        else:
            self.logger.info("SQL Execution", extra=log_data)

    def log_api_request(self, endpoint: str, method: str, query_params: Dict,
                       response_time_ms: float, status_code: int,
                       rows_returned: int = 0):
        """Log API request with telemetry"""
        log_data = {
            "endpoint": endpoint,
            "method": method,
            "query_params": str(query_params),
            "response_time_ms": round(response_time_ms, 2),
            "status_code": status_code,
            "rows_returned": rows_returned,
            "operation": "api_request"
        }

        if status_code >= 400:
            self.logger.error("API Error", extra=log_data)
        else:
            self.logger.info("API Request", extra=log_data)

    def log_ai_operation(self, operation_type: str, model: str,
                        tokens_used: int = 0, operation_time_ms: float = 0,
                        success: bool = True, error_message: str = None):
        """Log AI operations (OpenAI, local embeddings, etc.)"""
        log_data = {
            "operation_type": operation_type,  # 'openai_completion', 'embedding_generation', etc.
            "model": model,
            "tokens_used": tokens_used,
            "operation_time_ms": round(operation_time_ms, 2),
            "success": success,
            "error_message": error_message,
            "operation": "ai_operation"
        }

        if success:
            self.logger.info("AI Operation", extra=log_data)
        else:
            self.logger.error("AI Operation Failed", extra=log_data)

    def log_cache_operation(self, operation: str, cache_type: str,
                           hit_rate: float = 0.0, cache_size: int = 0):
        """Log caching operations"""
        log_data = {
            "cache_operation": operation,  # 'hit', 'miss', 'clear', 'stats'
            "cache_type": cache_type,  # 'query_cache', 'embedding_cache', etc.
            "hit_rate": round(hit_rate, 3),
            "cache_size": cache_size,
            "operation": "cache_operation"
        }

        self.logger.info("Cache Operation", extra=log_data)

def track_sql_execution(telemetry: ScoutTelemetry):
    """Decorator to track SQL execution"""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            start_time = time.time()
            sql_query = kwargs.get('sql', args[0] if args else 'unknown')

            try:
                result = func(*args, **kwargs)
                execution_time = (time.time() - start_time) * 1000

                rows_returned = 0
                if hasattr(result, 'get') and 'rows' in result:
                    rows_returned = result['rows']
                elif hasattr(result, '__len__'):
                    rows_returned = len(result)

                cache_hit = kwargs.get('cache_hit', False)

                telemetry.log_sql_execution(
                    sql=str(sql_query),
                    rows_returned=rows_returned,
                    execution_time_ms=execution_time,
                    cache_hit=cache_hit
                )

                return result

            except Exception as e:
                execution_time = (time.time() - start_time) * 1000
                telemetry.log_sql_execution(
                    sql=str(sql_query),
                    execution_time_ms=execution_time,
                    cache_hit=False
                )
                telemetry.logger.error(f"SQL execution failed: {e}")
                raise

        return wrapper
    return decorator

def track_api_request(telemetry: ScoutTelemetry):
    """Decorator to track API requests"""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            start_time = time.time()

            # Extract request info (works for Flask request context)
            try:
                from flask import request
                endpoint = request.endpoint or func.__name__
                method = request.method
                query_params = dict(request.args)
            except:
                endpoint = func.__name__
                method = "UNKNOWN"
                query_params = {}

            try:
                result = func(*args, **kwargs)
                response_time = (time.time() - start_time) * 1000

                # Extract response info
                status_code = 200
                rows_returned = 0

                if hasattr(result, 'status_code'):
                    status_code = result.status_code

                if hasattr(result, 'get_json'):
                    try:
                        json_data = result.get_json()
                        if json_data and 'rows' in json_data:
                            rows_returned = json_data['rows']
                    except:
                        pass

                telemetry.log_api_request(
                    endpoint=endpoint,
                    method=method,
                    query_params=query_params,
                    response_time_ms=response_time,
                    status_code=status_code,
                    rows_returned=rows_returned
                )

                return result

            except Exception as e:
                response_time = (time.time() - start_time) * 1000
                telemetry.log_api_request(
                    endpoint=endpoint,
                    method=method,
                    query_params=query_params,
                    response_time_ms=response_time,
                    status_code=500
                )
                telemetry.logger.error(f"API request failed: {e}")
                raise

        return wrapper
    return decorator

# Global telemetry instance
telemetry = ScoutTelemetry()

# Convenience functions for direct usage
def log_sql(sql: str, rows: int = 0, time_ms: float = 0, cached: bool = False):
    """Direct SQL logging"""
    telemetry.log_sql_execution(sql, rows_returned=rows, execution_time_ms=time_ms, cache_hit=cached)

def log_ai(operation: str, model: str, tokens: int = 0, time_ms: float = 0, success: bool = True):
    """Direct AI operation logging"""
    telemetry.log_ai_operation(operation, model, tokens_used=tokens, operation_time_ms=time_ms, success=success)

def log_cache(operation: str, cache_type: str, hit_rate: float = 0.0, size: int = 0):
    """Direct cache logging"""
    telemetry.log_cache_operation(operation, cache_type, hit_rate=hit_rate, cache_size=size)

# Usage example for Flask app
def init_telemetry_for_flask(app):
    """Initialize telemetry for Flask application"""
    global telemetry
    telemetry.init_app(app)
    return telemetry

if __name__ == "__main__":
    # Test telemetry
    print("🧪 Testing Scout Telemetry...")

    # Test logging
    telemetry.logger.info("Test log message")

    # Test SQL logging
    log_sql("SELECT * FROM test", rows=100, time_ms=50.5)

    # Test AI logging
    log_ai("openai_completion", "gpt-4", tokens=150, time_ms=1200.0)

    # Test cache logging
    log_cache("stats", "query_cache", hit_rate=0.85, size=50)

    print("✅ Telemetry test complete")