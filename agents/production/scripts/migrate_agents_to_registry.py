#!/usr/bin/env python3
"""
Production Agent Migration Script
Migrates all discovered agents to the unified agent registry in Supabase

This script:
1. Reads all agent YAML/JSON files from the repository
2. Standardizes their format
3. Validates production readiness
4. Inserts them into the agent_registry database
"""

import os
import sys
import json
import yaml
import logging
from pathlib import Path
from typing import Dict, List, Optional, Any
from datetime import datetime, timezone
from dataclasses import dataclass
import asyncio

from supabase import create_client, Client
import click

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Agent discovery paths
AGENT_PATHS = [
    "/Users/tbwa/agents",
    "/Users/tbwa/scout-dashboard",
    "/Users/tbwa/scout-analytics-clean/agents",
    "/Users/tbwa/enrichment_engine/agents",
    "/Users/tbwa/ces-jampacked-agentic/agents",
    "/Users/tbwa/dayops-agent/agents",
    "/Users/tbwa/tbwa-expense-clone/agents",
]

@dataclass
class Agent:
    """Agent data structure"""
    name: str
    agent_type: str
    version: str = "1.0.0"
    status: str = "inactive"
    capabilities: List[str] = None
    configuration: Dict[str, Any] = None
    description: str = None
    author: str = None
    owner: str = None
    tags: List[str] = None
    deployment_type: str = None
    health_check_url: str = None
    dependencies: Dict[str, Any] = None
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for database insertion"""
        return {
            'agent_name': self.name,
            'agent_type': self.agent_type,
            'version': self.version,
            'status': self.status,
            'capabilities': json.dumps(self.capabilities or []),
            'configuration': json.dumps(self.configuration or {}),
            'description': self.description,
            'author': self.author,
            'owner': self.owner,
            'tags': self.tags or [],
            'deployment_type': self.deployment_type,
            'health_check_url': self.health_check_url,
            'dependencies': json.dumps(self.dependencies or {})
        }

class AgentMigrator:
    """Handles agent discovery and migration to registry"""
    
    def __init__(self, supabase_url: str, supabase_key: str):
        self.supabase = create_client(supabase_url, supabase_key)
        self.discovered_agents = []
        self.production_agents = []
        
    def discover_agents(self) -> List[Agent]:
        """Discover all agent files in the repository"""
        agents = []
        
        for base_path in AGENT_PATHS:
            if not os.path.exists(base_path):
                logger.warning(f"Path does not exist: {base_path}")
                continue
                
            # Find all agent files
            path = Path(base_path)
            yaml_files = list(path.rglob("*agent*.yaml")) + list(path.rglob("*agent*.yml"))
            
            for file_path in yaml_files:
                try:
                    agent = self._parse_agent_file(file_path)
                    if agent:
                        agents.append(agent)
                        logger.info(f"Discovered agent: {agent.name} from {file_path}")
                except Exception as e:
                    logger.error(f"Error parsing {file_path}: {e}")
        
        # Also check for known agent catalogs
        catalog_files = [
            "/Users/tbwa/agents/agent_catalog.yaml",
            "/Users/tbwa/pulser_agent_registry.yaml"
        ]
        
        for catalog_file in catalog_files:
            if os.path.exists(catalog_file):
                agents.extend(self._parse_catalog_file(catalog_file))
        
        self.discovered_agents = agents
        return agents
    
    def _parse_agent_file(self, file_path: Path) -> Optional[Agent]:
        """Parse a single agent YAML file"""
        try:
            with open(file_path, 'r') as f:
                data = yaml.safe_load(f)
            
            if not data:
                return None
            
            # Handle different YAML structures
            if 'agent' in data:
                agent_data = data['agent']
            elif 'agents' in data:
                # Skip catalog files here
                return None
            else:
                agent_data = data
            
            # Extract agent information
            name = (agent_data.get('name') or 
                   agent_data.get('agent_name') or 
                   agent_data.get('codename') or
                   agent_data.get('id'))
            
            if not name:
                return None
            
            agent_type = (agent_data.get('type') or 
                         agent_data.get('agent_type') or 
                         self._infer_agent_type(agent_data))
            
            return Agent(
                name=name,
                agent_type=agent_type,
                version=agent_data.get('version', '1.0.0'),
                status='inactive',  # Default to inactive, will update later
                capabilities=agent_data.get('capabilities', []),
                configuration=agent_data.get('configuration', agent_data.get('config', {})),
                description=agent_data.get('description'),
                author=agent_data.get('author'),
                owner=agent_data.get('owner'),
                tags=agent_data.get('tags', []),
                deployment_type=self._infer_deployment_type(agent_data),
                dependencies=agent_data.get('dependencies', {})
            )
            
        except Exception as e:
            logger.error(f"Error parsing agent file {file_path}: {e}")
            return None
    
    def _parse_catalog_file(self, file_path: str) -> List[Agent]:
        """Parse agent catalog files"""
        agents = []
        
        try:
            with open(file_path, 'r') as f:
                data = yaml.safe_load(f)
            
            agent_list = data.get('agents', [])
            
            for agent_data in agent_list:
                name = (agent_data.get('name') or 
                       agent_data.get('codename') or 
                       agent_data.get('agent_name'))
                
                if not name:
                    continue
                
                agent = Agent(
                    name=name,
                    agent_type=agent_data.get('type', 'general'),
                    version=agent_data.get('version', '1.0.0'),
                    status='inactive',
                    capabilities=agent_data.get('capabilities', []),
                    configuration=agent_data.get('configuration', {}),
                    description=agent_data.get('description'),
                    author=agent_data.get('author'),
                    owner=agent_data.get('owner'),
                    tags=agent_data.get('tags', [])
                )
                
                agents.append(agent)
                logger.info(f"Discovered agent from catalog: {agent.name}")
                
        except Exception as e:
            logger.error(f"Error parsing catalog file {file_path}: {e}")
        
        return agents
    
    def _infer_agent_type(self, agent_data: Dict) -> str:
        """Infer agent type from capabilities or name"""
        capabilities = agent_data.get('capabilities', [])
        name = agent_data.get('name', '').lower()
        
        # Type inference rules
        if 'orchestration' in capabilities or 'orchestrat' in name:
            return 'orchestrator'
        elif 'ingestion' in capabilities or 'ingest' in name:
            return 'data_ingestion'
        elif 'scraping' in capabilities or 'scrap' in name:
            return 'web_scraping'
        elif 'filter' in name or 'toggle' in name:
            return 'filter_management'
        elif 'schema' in capabilities or 'schema' in name:
            return 'schema_inference'
        elif 'documentation' in capabilities or 'doc' in name:
            return 'documentation'
        elif 'analytics' in capabilities or 'analyt' in name:
            return 'analytics'
        elif 'validation' in capabilities or 'qa' in name:
            return 'validation'
        else:
            return 'general'
    
    def _infer_deployment_type(self, agent_data: Dict) -> Optional[str]:
        """Infer deployment type from agent data"""
        deployment = agent_data.get('deployment', {})
        
        if isinstance(deployment, dict):
            if 'docker' in deployment:
                return 'docker'
            elif 'edge_function' in deployment:
                return 'edge_function'
            elif 'kubernetes' in deployment:
                return 'kubernetes'
        
        # Check for deployment hints in other fields
        if agent_data.get('dockerfile'):
            return 'docker'
        elif agent_data.get('runtime') == 'deno':
            return 'edge_function'
        
        return None
    
    def validate_production_readiness(self, agents: List[Agent]) -> List[Agent]:
        """Validate which agents are production-ready"""
        production_ready = []
        
        # Define production-ready agents (from our implementation)
        production_agent_names = {
            'Iska', 'Lyra-Primary', 'Lyra-Secondary', 'Master-Toggle',
            'Orchestrator', 'Savage', 'Fully', 'Doer', 'Stacey',
            'Gagambi', 'RetailBot', 'KeyKey', 'DayOps', 'Echo',
            'Dash', 'Claudia', 'Maya', 'Caca', 'Basher'
        }
        
        for agent in agents:
            # Check if agent is in production list
            if agent.name in production_agent_names:
                agent.status = 'active'
                production_ready.append(agent)
            else:
                # Check basic production criteria
                if (agent.capabilities and 
                    len(agent.capabilities) > 0 and
                    agent.description):
                    agent.status = 'inactive'  # Ready but not activated
                    production_ready.append(agent)
        
        self.production_agents = production_ready
        return production_ready
    
    async def migrate_to_registry(self, agents: List[Agent], dry_run: bool = False):
        """Migrate agents to the registry database"""
        logger.info(f"Migrating {len(agents)} agents to registry...")
        
        if dry_run:
            logger.info("DRY RUN - No actual database changes will be made")
        
        success_count = 0
        error_count = 0
        
        for agent in agents:
            try:
                agent_data = agent.to_dict()
                
                if dry_run:
                    logger.info(f"Would insert agent: {agent.name} ({agent.agent_type})")
                else:
                    # Check if agent already exists
                    existing = self.supabase.table('agents').select('id').eq('agent_name', agent.name).execute()
                    
                    if existing.data:
                        # Update existing agent
                        result = self.supabase.table('agents').update(agent_data).eq('agent_name', agent.name).execute()
                        logger.info(f"Updated existing agent: {agent.name}")
                    else:
                        # Insert new agent
                        result = self.supabase.table('agents').insert(agent_data).execute()
                        logger.info(f"Inserted new agent: {agent.name}")
                    
                    success_count += 1
                    
            except Exception as e:
                logger.error(f"Error migrating agent {agent.name}: {e}")
                error_count += 1
        
        logger.info(f"Migration complete: {success_count} successful, {error_count} errors")
        
        # Create audit log entry
        if not dry_run and success_count > 0:
            audit_entry = {
                'event_type': 'bulk_agent_migration',
                'event_data': {
                    'total_agents': len(agents),
                    'success_count': success_count,
                    'error_count': error_count,
                    'agent_names': [a.name for a in agents]
                },
                'initiated_by': 'migration_script',
                'success': error_count == 0
            }
            
            try:
                self.supabase.table('audit_log').insert(audit_entry).execute()
                logger.info("Created audit log entry for migration")
            except Exception as e:
                logger.error(f"Failed to create audit log: {e}")
    
    def generate_report(self) -> str:
        """Generate a migration report"""
        report = []
        report.append("=" * 60)
        report.append("AGENT MIGRATION REPORT")
        report.append("=" * 60)
        report.append(f"Generated: {datetime.now(timezone.utc).isoformat()}")
        report.append("")
        
        report.append(f"Total Agents Discovered: {len(self.discovered_agents)}")
        report.append(f"Production-Ready Agents: {len(self.production_agents)}")
        report.append("")
        
        # Group by type
        by_type = {}
        for agent in self.production_agents:
            agent_type = agent.agent_type
            if agent_type not in by_type:
                by_type[agent_type] = []
            by_type[agent_type].append(agent)
        
        report.append("Agents by Type:")
        for agent_type, agents in sorted(by_type.items()):
            report.append(f"\n{agent_type.upper()} ({len(agents)} agents):")
            for agent in sorted(agents, key=lambda a: a.name):
                status_icon = "✓" if agent.status == 'active' else "○"
                report.append(f"  {status_icon} {agent.name} v{agent.version}")
                if agent.description:
                    report.append(f"     {agent.description[:60]}...")
        
        report.append("\n" + "=" * 60)
        
        return "\n".join(report)

@click.command()
@click.option('--supabase-url', envvar='SUPABASE_URL', required=True, help='Supabase project URL')
@click.option('--supabase-key', envvar='SUPABASE_SERVICE_ROLE_KEY', required=True, help='Supabase service role key')
@click.option('--dry-run', is_flag=True, help='Perform dry run without database changes')
@click.option('--report-only', is_flag=True, help='Only generate report without migration')
def main(supabase_url: str, supabase_key: str, dry_run: bool, report_only: bool):
    """Migrate all discovered agents to the unified registry"""
    
    logger.info("Starting agent migration process...")
    
    # Initialize migrator
    migrator = AgentMigrator(supabase_url, supabase_key)
    
    # Discover agents
    logger.info("Discovering agents...")
    agents = migrator.discover_agents()
    logger.info(f"Discovered {len(agents)} total agents")
    
    # Validate production readiness
    logger.info("Validating production readiness...")
    production_agents = migrator.validate_production_readiness(agents)
    logger.info(f"Found {len(production_agents)} production-ready agents")
    
    # Generate report
    report = migrator.generate_report()
    print("\n" + report)
    
    # Save report
    report_path = "/Users/tbwa/agents/production/migration_report.txt"
    os.makedirs(os.path.dirname(report_path), exist_ok=True)
    with open(report_path, 'w') as f:
        f.write(report)
    logger.info(f"Report saved to: {report_path}")
    
    # Perform migration
    if not report_only:
        asyncio.run(migrator.migrate_to_registry(production_agents, dry_run=dry_run))
    
    logger.info("Migration process complete!")

if __name__ == "__main__":
    main()