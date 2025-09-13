#!/usr/bin/env python3
"""
Agent Discovery Script - Discovers all agents without database connection
"""

import os
import sys
import yaml
import logging
from pathlib import Path
from typing import Dict, List, Optional, Any
from datetime import datetime, timezone
from dataclasses import dataclass

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
    file_path: str = None

class AgentDiscoverer:
    """Discovers agents without database connection"""
    
    def __init__(self):
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
                status='inactive',
                capabilities=agent_data.get('capabilities', []),
                configuration=agent_data.get('configuration', agent_data.get('config', {})),
                description=agent_data.get('description'),
                author=agent_data.get('author'),
                owner=agent_data.get('owner'),
                tags=agent_data.get('tags', []),
                deployment_type=self._infer_deployment_type(agent_data),
                file_path=str(file_path)
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
                    tags=agent_data.get('tags', []),
                    file_path=file_path
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
            'Dash', 'Claudia', 'Maya', 'Caca', 'Basher', 'AI Agent Auditor'
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
    
    def generate_report(self) -> str:
        """Generate a discovery report"""
        report = []
        report.append("=" * 60)
        report.append("AGENT DISCOVERY REPORT")
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
        
        report.append("Production Agents by Type:")
        for agent_type, agents in sorted(by_type.items()):
            report.append(f"\n{agent_type.upper()} ({len(agents)} agents):")
            for agent in sorted(agents, key=lambda a: a.name):
                status_icon = "✓" if agent.status == 'active' else "○"
                report.append(f"  {status_icon} {agent.name} v{agent.version}")
                if agent.description:
                    report.append(f"     {agent.description[:80]}...")
        
        report.append("\n" + "=" * 60)
        report.append("ALL DISCOVERED AGENTS:")
        report.append("=" * 60)
        
        # Show all agents
        for agent in sorted(self.discovered_agents, key=lambda a: a.name):
            report.append(f"{agent.name} ({agent.agent_type}) - {agent.file_path}")
        
        report.append("\n" + "=" * 60)
        
        return "\n".join(report)

def main():
    """Discover and report on all agents"""
    
    logger.info("Starting agent discovery process...")
    
    # Initialize discoverer
    discoverer = AgentDiscoverer()
    
    # Discover agents
    logger.info("Discovering agents...")
    agents = discoverer.discover_agents()
    logger.info(f"Discovered {len(agents)} total agents")
    
    # Validate production readiness
    logger.info("Validating production readiness...")
    production_agents = discoverer.validate_production_readiness(agents)
    logger.info(f"Found {len(production_agents)} production-ready agents")
    
    # Generate report
    report = discoverer.generate_report()
    print("\n" + report)
    
    # Save report
    report_path = "/Users/tbwa/agents/production/agent_discovery_report.txt"
    os.makedirs(os.path.dirname(report_path), exist_ok=True)
    with open(report_path, 'w') as f:
        f.write(report)
    logger.info(f"Report saved to: {report_path}")
    
    logger.info("Discovery process complete!")

if __name__ == "__main__":
    main()