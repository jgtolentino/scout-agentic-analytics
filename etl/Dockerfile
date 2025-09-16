# Production ETL Worker Dockerfile
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    build-essential \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Install dbt
RUN pip install --no-cache-dir dbt-postgres==1.7.4

# Copy requirements and install Python dependencies
COPY etl/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY etl/ ./etl/
COPY dbt-scout/ ./dbt-scout/

# Set environment variables
ENV PYTHONPATH=/app
ENV DBT_PROFILES_DIR=/app/dbt-scout
ENV TEMPORAL_NAMESPACE=scout-analytics

# Create non-root user
RUN useradd --create-home --shell /bin/bash bruno
RUN chown -R bruno:bruno /app
USER bruno

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
  CMD python -c "import temporalio; print('OK')" || exit 1

# Default command
CMD ["python", "etl/bruno_executor.py", "worker"]