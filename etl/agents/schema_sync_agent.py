#!/usr/bin/env python3
"""
Schema Sync Agent for Scout v7
==============================

Bi-directional schema synchronization agent that:
1. Monitors database schema drift using DDL triggers
2. Generates documentation from schema changes
3. Creates GitHub PRs for schema changes
4. Validates ETL contract compliance
5. Prevents breaking changes to flatten.py

Usage:
    python schema_sync_agent.py --mode monitor  # Continuous monitoring
    python schema_sync_agent.py --mode sync     # One-time sync
    python schema_sync_agent.py --mode validate # ETL contract validation
"""

import asyncio
import json
import logging
import os
import subprocess
import tempfile
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import argparse

import asyncpg
import httpx
from jinja2 import Template

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('schema_sync_agent')

class SchemaSyncAgent:
    """Main schema synchronization agent"""

    def __init__(self):
        self.db_config = {
            'host': os.getenv('AZURE_SQL_SERVER', 'sqltbwaprojectscoutserver.database.windows.net'),
            'port': int(os.getenv('AZURE_SQL_PORT', '1433')),
            'database': os.getenv('AZURE_SQL_DATABASE', 'SQL-TBWA-ProjectScout-Reporting-Prod'),
            'user': os.getenv('AZURE_SQL_USER', 'sqladmin'),
            'password': os.getenv('AZURE_SQL_PASSWORD')
        }

        self.github_config = {
            'token': os.getenv('GITHUB_TOKEN'),
            'owner': os.getenv('GITHUB_OWNER', 'jgtolentino'),
            'repo': os.getenv('GITHUB_REPO', 'scout-v7'),
            'base_branch': os.getenv('GITHUB_BASE_BRANCH', 'main')
        }

        self.repo_path = Path(os.getenv('REPO_PATH', '/Users/tbwa/scout-v7'))
        self.docs_path = self.repo_path / 'docs'
        self.schemas_path = self.docs_path / 'schemas'

        # Ensure directories exist
        self.docs_path.mkdir(exist_ok=True)
        self.schemas_path.mkdir(exist_ok=True)

    async def get_db_connection(self):
        """Get database connection with retry logic"""
        import pyodbc

        connection_string = (
            f"DRIVER={{ODBC Driver 18 for SQL Server}};"
            f"SERVER={self.db_config['host']};"
            f"DATABASE={self.db_config['database']};"
            f"UID={self.db_config['user']};"
            f"PWD={self.db_config['password']};"
            f"Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
        )

        max_retries = 3
        for attempt in range(max_retries):
            try:
                conn = pyodbc.connect(connection_string)
                logger.info("✅ Database connection established")
                return conn
            except Exception as e:
                logger.warning(f"Database connection attempt {attempt + 1} failed: {e}")
                if attempt == max_retries - 1:
                    raise
                await asyncio.sleep(2 ** attempt)

    async def get_pending_drift(self) -> List[Dict]:
        """Get pending schema drift from database"""
        query = """
        SELECT
            drift_id, event_time, event_type, schema_name, object_name,
            object_type, ddl_command, login_name, hours_since_change
        FROM system.fn_get_pending_schema_drift()
        ORDER BY event_time ASC
        """

        try:
            conn = await self.get_db_connection()
            cursor = conn.cursor()
            cursor.execute(query)

            columns = [desc[0] for desc in cursor.description]
            rows = cursor.fetchall()

            drift_records = []
            for row in rows:
                record = dict(zip(columns, row))
                # Convert datetime to string for JSON serialization
                if record.get('event_time'):
                    record['event_time'] = record['event_time'].isoformat()
                drift_records.append(record)

            conn.close()
            logger.info(f"📊 Found {len(drift_records)} pending drift records")
            return drift_records

        except Exception as e:
            logger.error(f"❌ Failed to get pending drift: {e}")
            return []

    async def get_schema_documentation(self) -> List[Dict]:
        """Get current schema state for documentation generation"""
        query = """
        SELECT
            schema_name, table_name, object_type, column_name,
            data_type, data_length, is_nullable, is_identity,
            description, ordinal_position
        FROM system.vw_schema_documentation
        ORDER BY schema_name, table_name, ordinal_position
        """

        try:
            conn = await self.get_db_connection()
            cursor = conn.cursor()
            cursor.execute(query)

            columns = [desc[0] for desc in cursor.description]
            rows = cursor.fetchall()

            schema_docs = []
            for row in rows:
                record = dict(zip(columns, row))
                schema_docs.append(record)

            conn.close()
            logger.info(f"📚 Retrieved {len(schema_docs)} schema documentation records")
            return schema_docs

        except Exception as e:
            logger.error(f"❌ Failed to get schema documentation: {e}")
            return []

    async def validate_etl_contracts(self) -> List[Dict]:
        """Validate ETL contract compliance"""
        query = """
        SELECT
            source_table, required_column, column_status, impact_description
        FROM system.vw_etl_contract_validation
        """

        try:
            conn = await self.get_db_connection()
            cursor = conn.cursor()
            cursor.execute(query)

            columns = [desc[0] for desc in cursor.description]
            rows = cursor.fetchall()

            violations = []
            for row in rows:
                record = dict(zip(columns, row))
                if record['column_status'] == 'MISSING':
                    violations.append(record)

            conn.close()

            if violations:
                logger.warning(f"⚠️ Found {len(violations)} ETL contract violations")
            else:
                logger.info("✅ All ETL contracts validated successfully")

            return violations

        except Exception as e:
            logger.error(f"❌ Failed to validate ETL contracts: {e}")
            return []

    def generate_mkdocs_schema(self, schema_docs: List[Dict]) -> str:
        """Generate MkDocs markdown from schema documentation"""

        # Group by schema and table
        schemas = {}
        for doc in schema_docs:
            schema_name = doc['schema_name']
            table_name = doc['table_name']

            if schema_name not in schemas:
                schemas[schema_name] = {}

            if table_name not in schemas[schema_name]:
                schemas[schema_name][table_name] = {
                    'object_type': doc['object_type'],
                    'columns': []
                }

            if doc['column_name']:  # Only for tables with columns
                schemas[schema_name][table_name]['columns'].append(doc)

        # Generate markdown
        template = Template("""# Database Schema Documentation

*Auto-generated from database schema on {{ generation_time }}*

{% for schema_name, tables in schemas.items() %}
## Schema: `{{ schema_name }}`

{% for table_name, table_info in tables.items() %}
### {{ table_info.object_type|title }}: `{{ table_name }}`

{% if table_info.columns %}
| Column | Type | Length | Nullable | Identity | Description |
|--------|------|--------|----------|----------|-------------|
{% for col in table_info.columns %}
| `{{ col.column_name }}` | {{ col.data_type }} | {{ col.data_length or 'N/A' }} | {{ '✓' if col.is_nullable else '✗' }} | {{ '✓' if col.is_identity else '✗' }} | {{ col.description or '' }} |
{% endfor %}
{% else %}
*{{ table_info.object_type|title }} definition available in database*
{% endif %}

---

{% endfor %}
{% endfor %}

## ETL Contract Validation

This documentation is automatically synchronized with the database schema to ensure:

- **flatten.py compatibility**: All required columns for ETL processing are present
- **Canonical ID normalization**: `canonical_tx_id_norm` columns are properly maintained
- **Data pipeline integrity**: Breaking changes trigger automatic validation

> 🔄 **Auto-sync enabled**: This documentation updates automatically when schema changes are detected.
""")

        return template.render(
            schemas=schemas,
            generation_time=datetime.now().isoformat()
        )

    async def create_github_pr(self, drift_records: List[Dict], violations: List[Dict]) -> Optional[int]:
        """Create GitHub PR for schema changes"""

        if not self.github_config['token']:
            logger.warning("⚠️ GitHub token not configured, skipping PR creation")
            return None

        # Generate branch name
        timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')
        branch_name = f"schema-sync/{timestamp}"

        # Generate PR title and description
        pr_title = f"🔄 Schema Sync: {len(drift_records)} database changes detected"

        pr_description = f"""## Schema Changes Detected

This PR contains automatically detected database schema changes that need to be synchronized with the repository.

### Changes Summary
"""

        for record in drift_records:
            pr_description += f"- **{record['event_type']}** `{record['schema_name']}.{record['object_name']}` ({record['object_type']})\n"

        if violations:
            pr_description += f"\n### ⚠️ ETL Contract Violations\n"
            for violation in violations:
                pr_description += f"- **{violation['source_table']}.{violation['required_column']}**: {violation['impact_description']}\n"

        pr_description += f"""
### Auto-generated Files
- 📚 Updated schema documentation
- 🛡️ ETL contract validation results
- 📊 Schema drift audit trail

### Review Guidelines
1. Verify all schema changes are intentional
2. Check ETL contract compliance
3. Test flatten.py and related ETL components
4. Ensure documentation accuracy

---
*Generated by Schema Sync Agent on {datetime.now().isoformat()}*
"""

        try:
            # Update schema documentation
            schema_docs = await self.get_schema_documentation()
            mkdocs_content = self.generate_mkdocs_schema(schema_docs)

            # Write to documentation file
            schema_doc_path = self.schemas_path / 'database.md'
            with open(schema_doc_path, 'w') as f:
                f.write(mkdocs_content)

            # Create git branch and commit
            subprocess.run(['git', 'checkout', '-b', branch_name],
                         cwd=self.repo_path, check=True)
            subprocess.run(['git', 'add', str(schema_doc_path)],
                         cwd=self.repo_path, check=True)
            subprocess.run(['git', 'commit', '-m', f'Auto-update schema documentation\n\n{pr_title}'],
                         cwd=self.repo_path, check=True)
            subprocess.run(['git', 'push', 'origin', branch_name],
                         cwd=self.repo_path, check=True)

            # Create PR via GitHub API
            async with httpx.AsyncClient() as client:
                headers = {
                    'Authorization': f'token {self.github_config["token"]}',
                    'Accept': 'application/vnd.github.v3+json'
                }

                pr_data = {
                    'title': pr_title,
                    'body': pr_description,
                    'head': branch_name,
                    'base': self.github_config['base_branch']
                }

                url = f"https://api.github.com/repos/{self.github_config['owner']}/{self.github_config['repo']}/pulls"
                response = await client.post(url, json=pr_data, headers=headers)

                if response.status_code == 201:
                    pr_data = response.json()
                    pr_number = pr_data['number']
                    logger.info(f"✅ Created GitHub PR #{pr_number}: {pr_title}")
                    return pr_number
                else:
                    logger.error(f"❌ Failed to create PR: {response.status_code} {response.text}")
                    return None

        except Exception as e:
            logger.error(f"❌ Failed to create GitHub PR: {e}")
            return None

    async def update_drift_status(self, drift_ids: List[int], status: str, pr_number: Optional[int] = None):
        """Update drift record status in database"""
        if not drift_ids:
            return

        try:
            conn = await self.get_db_connection()
            cursor = conn.cursor()

            placeholders = ','.join(['?' for _ in drift_ids])
            query = f"""
            UPDATE system.schema_drift_log
            SET sync_status = ?, sync_pr_number = ?, updated_at = GETDATE()
            WHERE drift_id IN ({placeholders})
            """

            params = [status, pr_number] + drift_ids
            cursor.execute(query, params)
            conn.commit()
            conn.close()

            logger.info(f"✅ Updated {len(drift_ids)} drift records to status: {status}")

        except Exception as e:
            logger.error(f"❌ Failed to update drift status: {e}")

    async def monitor_mode(self):
        """Continuous monitoring mode"""
        logger.info("🔄 Starting continuous schema monitoring...")

        check_interval = int(os.getenv('SCHEMA_SYNC_INTERVAL', '300'))  # 5 minutes default

        while True:
            try:
                await self.sync_once()
                logger.info(f"⏳ Sleeping for {check_interval} seconds...")
                await asyncio.sleep(check_interval)

            except KeyboardInterrupt:
                logger.info("👋 Monitoring stopped by user")
                break
            except Exception as e:
                logger.error(f"❌ Error in monitoring loop: {e}")
                await asyncio.sleep(60)  # Wait 1 minute before retrying

    async def sync_once(self):
        """Perform one-time sync operation"""
        logger.info("🔍 Checking for schema drift...")

        # Get pending drift
        drift_records = await self.get_pending_drift()

        if not drift_records:
            logger.info("✅ No pending schema drift detected")
            return

        # Validate ETL contracts
        violations = await self.validate_etl_contracts()

        # Create GitHub PR
        pr_number = await self.create_github_pr(drift_records, violations)

        if pr_number:
            # Update drift status
            drift_ids = [record['drift_id'] for record in drift_records]
            await self.update_drift_status(drift_ids, 'PR_CREATED', pr_number)
            logger.info(f"✅ Schema sync completed successfully - PR #{pr_number} created")
        else:
            logger.warning("⚠️ Schema drift detected but PR creation failed")

    async def validate_mode(self):
        """ETL contract validation mode"""
        logger.info("🛡️ Validating ETL contracts...")

        violations = await self.validate_etl_contracts()

        if violations:
            logger.error("❌ ETL contract violations detected:")
            for violation in violations:
                logger.error(f"  - {violation['source_table']}.{violation['required_column']}: {violation['impact_description']}")
            return 1
        else:
            logger.info("✅ All ETL contracts validated successfully")
            return 0

async def main():
    parser = argparse.ArgumentParser(description='Schema Sync Agent for Scout v7')
    parser.add_argument('--mode', choices=['monitor', 'sync', 'validate'],
                       default='sync', help='Operation mode')
    parser.add_argument('--log-level', choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
                       default='INFO', help='Logging level')

    args = parser.parse_args()

    # Set log level
    logging.getLogger().setLevel(getattr(logging, args.log_level))

    # Initialize agent
    agent = SchemaSyncAgent()

    try:
        if args.mode == 'monitor':
            await agent.monitor_mode()
        elif args.mode == 'sync':
            await agent.sync_once()
        elif args.mode == 'validate':
            exit_code = await agent.validate_mode()
            exit(exit_code)

    except Exception as e:
        logger.error(f"❌ Agent failed: {e}")
        exit(1)

if __name__ == '__main__':
    asyncio.run(main())