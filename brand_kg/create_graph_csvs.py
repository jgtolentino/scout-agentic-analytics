#!/usr/bin/env python3
"""
Neo4j Graph CSV Generator
Creates nodes.csv and edges.csv from processed brand knowledge graph data
"""

import csv
import json
from pathlib import Path
from typing import List, Dict, Set

class GraphCSVGenerator:
    def __init__(self):
        self.out_dir = Path("/Users/tbwa/scout-v7/brand_kg")
        self.nodes = []
        self.edges = []
        self.processed_nodes = set()
        
    def extract_from_jsonld(self, brand_dir: Path):
        """Extract nodes and edges from brand JSON-LD file"""
        jsonld_file = brand_dir / "kg.jsonld" 
        if not jsonld_file.exists():
            return
            
        with open(jsonld_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
            
        graph = data.get('@graph', [])
        
        for entity in graph:
            entity_id = entity.get('@id')
            entity_type = entity.get('@type')
            
            if not entity_id or entity_id in self.processed_nodes:
                continue
                
            self.processed_nodes.add(entity_id)
            
            # Create node
            node = {
                ':ID': entity_id,
                ':LABEL': entity_type,
                'name': entity.get('schema:name', ''),
                'type': self._get_entity_type(entity_type),
                'iso2': entity.get('schema:addressCountry', ''),
                'ticker': entity.get('schema:tickerSymbol', ''),
                'slug': self._create_slug(entity.get('schema:name', ''))
            }
            
            # Remove empty values
            node = {k: v for k, v in node.items() if v}
            self.nodes.append(node)
            
            # Create edges based on relationships
            self._extract_edges(entity)
            
    def _get_entity_type(self, schema_type: str) -> str:
        """Map schema type to entity type"""
        type_mapping = {
            'Brand': 'brand',
            'Organization': 'organization', 
            'schema:Place': 'place',
            'Place': 'place',
            'schema:CategoryCode': 'category',
            'CategoryCode': 'category',
            'kg:MarketShare': 'metric'
        }
        return type_mapping.get(schema_type, 'unknown')
        
    def _create_slug(self, name: str) -> str:
        """Create slug from name"""
        if not name:
            return ''
        return name.lower().replace(' ', '-').replace('&', 'and').replace('.', '').replace(',', '')
        
    def _extract_edges(self, entity: Dict):
        """Extract relationships as edges"""
        entity_id = entity.get('@id')
        
        # Standard relationships
        relationships = {
            'kg:hasCategory': 'IN_CATEGORY',
            'kg:hasParent': 'HAS_PARENT', 
            'kg:soldIn': 'SOLD_IN'
        }
        
        for prop, edge_type in relationships.items():
            target = entity.get(prop)
            if target:
                edge = {
                    ':START_ID': entity_id,
                    ':TYPE': edge_type,
                    ':END_ID': target,
                    'asOf': '',
                    'value': '',
                    'unit': '', 
                    'source_id': '',
                    'confidence': ''
                }
                self.edges.append(edge)
                
        # Market share as separate metric entity
        if entity.get('@type') == 'kg:MarketShare':
            market_share = entity.get('kg:marketShare')
            as_of = entity.get('kg:asOf')
            source = entity.get('schema:citation')
            confidence = entity.get('kg:confidence')
            
            # Find the brand this metric belongs to
            brand_id = entity_id.replace('_:ms_', 'kg:brand/')
            
            edge = {
                ':START_ID': brand_id,
                ':TYPE': 'MARKET_SHARE',
                ':END_ID': 'kg:place/ph',
                'asOf': as_of or '',
                'value': str(market_share) if market_share else '',
                'unit': 'share',
                'source_id': source or '',
                'confidence': str(confidence) if confidence else ''
            }
            self.edges.append(edge)
            
    def add_competitive_edges(self):
        """Add competitive relationships between brands in same category"""
        # Group brands by category
        brand_categories = {}
        
        for node in self.nodes:
            if node.get(':LABEL') == 'Brand':
                brand_id = node[':ID']
                # Find category from edges
                for edge in self.edges:
                    if edge[':START_ID'] == brand_id and edge[':TYPE'] == 'IN_CATEGORY':
                        category = edge[':END_ID']
                        if category not in brand_categories:
                            brand_categories[category] = []
                        brand_categories[category].append(brand_id)
                        break
        
        # Add competitive edges within categories
        for category, brands in brand_categories.items():
            if len(brands) > 1:
                for i, brand1 in enumerate(brands):
                    for brand2 in brands[i+1:]:
                        # Add bidirectional competitive relationship
                        self.edges.append({
                            ':START_ID': brand1,
                            ':TYPE': 'COMPETES_WITH',
                            ':END_ID': brand2,
                            'asOf': '',
                            'value': '',
                            'unit': '',
                            'source_id': '',
                            'confidence': ''
                        })
                        self.edges.append({
                            ':START_ID': brand2,
                            ':TYPE': 'COMPETES_WITH', 
                            ':END_ID': brand1,
                            'asOf': '',
                            'value': '',
                            'unit': '',
                            'source_id': '',
                            'confidence': ''
                        })
                        
    def write_csvs(self):
        """Write nodes and edges to CSV files"""
        
        # Write nodes.csv
        nodes_file = self.out_dir / "graph" / "nodes.csv"
        if self.nodes:
            fieldnames = [':ID', ':LABEL', 'name', 'type', 'iso2', 'ticker', 'slug']
            
            with open(nodes_file, 'w', newline='', encoding='utf-8') as f:
                writer = csv.DictWriter(f, fieldnames=fieldnames)
                writer.writeheader()
                for node in self.nodes:
                    # Only write fields that exist and have values
                    filtered_node = {k: v for k, v in node.items() if k in fieldnames and v}
                    writer.writerow(filtered_node)
        
        # Write edges.csv  
        edges_file = self.out_dir / "graph" / "edges.csv"
        if self.edges:
            fieldnames = [':START_ID', ':TYPE', ':END_ID', 'asOf', 'value', 'unit', 'source_id', 'confidence']
            
            with open(edges_file, 'w', newline='', encoding='utf-8') as f:
                writer = csv.DictWriter(f, fieldnames=fieldnames)
                writer.writeheader()
                for edge in self.edges:
                    writer.writerow(edge)
                    
        print(f"✓ Created graph/nodes.csv ({len(self.nodes)} nodes)")
        print(f"✓ Created graph/edges.csv ({len(self.edges)} edges)")
        
    def process_all_brands(self):
        """Process all brand directories to extract graph data"""
        brand_base_dir = self.out_dir / "brand"
        
        if not brand_base_dir.exists():
            print(f"No brand directory found at {brand_base_dir}")
            return
            
        brand_dirs = [d for d in brand_base_dir.iterdir() if d.is_dir()]
        
        print(f"Processing {len(brand_dirs)} brand directories...")
        
        for brand_dir in brand_dirs:
            self.extract_from_jsonld(brand_dir)
            
        # Add competitive relationships
        self.add_competitive_edges()
        
        # Write CSV files
        self.write_csvs()
        
        return len(self.nodes), len(self.edges)

def main():
    generator = GraphCSVGenerator()
    
    print("=== Neo4j Graph CSV Generation ===")
    nodes_count, edges_count = generator.process_all_brands()
    
    print(f"\n✓ Graph CSV generation complete!")
    print(f"  Nodes: {nodes_count}")
    print(f"  Edges: {edges_count}")
    
    # Validate CSV structure
    nodes_file = generator.out_dir / "graph" / "nodes.csv"
    edges_file = generator.out_dir / "graph" / "edges.csv"
    
    if nodes_file.exists() and edges_file.exists():
        print(f"  Files created: nodes.csv, edges.csv")
        print(f"  Ready for Neo4j import with: neo4j-admin database import")
    else:
        print("  ⚠️  CSV files not created properly")

if __name__ == "__main__":
    main()