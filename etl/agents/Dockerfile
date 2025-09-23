FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# System deps for msodbcsql18 / unixODBC
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    curl gnupg apt-transport-https ca-certificates \
    unixodbc unixodbc-dev build-essential git \
 && rm -rf /var/lib/apt/lists/*

# Microsoft ODBC Driver 18 for SQL Server
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/debian/12/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update -y && ACCEPT_EULA=Y apt-get install -y msodbcsql18 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python deps first (better layer cache)
COPY etl/agents/requirements.txt /app/etl/agents/requirements.txt
RUN pip install --no-cache-dir -r /app/etl/agents/requirements.txt

# Copy code
COPY etl /app/etl
COPY database /app/database

# Default environment (all overridden by runtime secrets)
ENV OUTDIR="/app/exports" \
    SYNC_INTERVAL="60" \
    LOG_LEVEL="INFO"

# Make output dir
RUN mkdir -p /app/exports

# Healthcheck via /healthz
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -fsS http://127.0.0.1:8080/healthz || exit 1

# Entrypoint
CMD ["python","etl/agents/auto_sync_tracked.py"]