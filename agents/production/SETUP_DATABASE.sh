#!/bin/bash

# DIRECT DATABASE SETUP - USING THE WORKING KEYS
# This creates the database schema and inserts agents directly

PROJECT_URL="https://texxwmlroefdisgxpszc.supabase.co"
SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRleHh3bWxyb2VmZGlzZ3hwc3pjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1Mjg0MDcyNCwiZXhwIjoyMDY4NDE2NzI0fQ.rPkW7VgW42GCaz9cfxvhyDo_1ySHBiyxnjfiycJXptcn"

echo "🚀 Setting up database schema directly..."

# Create the agents table
echo "Creating agents table..."
curl -X POST "$PROJECT_URL/rest/v1/rpc/exec" \
  -H "apikey: $SERVICE_KEY" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "CREATE TABLE IF NOT EXISTS agents (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      agent_name TEXT NOT NULL UNIQUE,
      agent_type TEXT NOT NULL,
      version TEXT NOT NULL DEFAULT '\''1.0.0'\'',
      status TEXT NOT NULL DEFAULT '\''inactive'\'',
      capabilities JSONB DEFAULT '\''[]'\''::jsonb,
      configuration JSONB DEFAULT '\''{}'\''::jsonb,
      description TEXT,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    );"
  }'

echo -e "\n✅ Database schema created!"

# Insert the production agents directly
echo "Inserting production agents..."
curl -X POST "$PROJECT_URL/rest/v1/agents" \
  -H "apikey: $SERVICE_KEY" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '[
    {
      "agent_name": "Lyra-Primary",
      "agent_type": "schema_inference",
      "version": "1.0.0",
      "status": "active",
      "capabilities": ["schema_discovery", "json_to_sql", "master_data_update"],
      "description": "Primary schema inference agent with failover"
    },
    {
      "agent_name": "Lyra-Secondary", 
      "agent_type": "schema_inference",
      "version": "1.0.0",
      "status": "inactive",
      "capabilities": ["schema_discovery", "json_to_sql", "master_data_update"],
      "description": "Secondary schema inference agent for HA"
    },
    {
      "agent_name": "Master-Toggle",
      "agent_type": "filter_management", 
      "version": "1.0.0",
      "status": "active",
      "capabilities": ["filter_sync", "toggle_api", "websocket_streaming"],
      "description": "Real-time filter management agent"
    },
    {
      "agent_name": "Iska",
      "agent_type": "documentation",
      "version": "2.0.0", 
      "status": "active",
      "capabilities": ["web_scraping", "document_ingestion", "qa_validation", "semantic_search"],
      "description": "Master documentation intelligence agent"
    },
    {
      "agent_name": "AI-Agent-Auditor",
      "agent_type": "compliance",
      "version": "1.0.0",
      "status": "active", 
      "capabilities": ["oath_monitoring", "compliance_scoring", "audit_reporting"],
      "description": "OATH compliance monitoring agent"
    },
    {
      "agent_name": "Stacey",
      "agent_type": "analyst",
      "version": "1.0.0",
      "status": "active",
      "capabilities": ["data_analysis", "reporting"],
      "description": "Data analysis specialist"
    },
    {
      "agent_name": "Dash", 
      "agent_type": "dashboard_engineer",
      "version": "1.0.0",
      "status": "active",
      "capabilities": ["dashboard_creation", "visualization"],
      "description": "Dashboard engineering agent"
    },
    {
      "agent_name": "Fully",
      "agent_type": "engineer",
      "version": "1.0.0",
      "status": "active",
      "capabilities": ["fullstack_development", "deployment"],
      "description": "Fullstack engineering agent"
    },
    {
      "agent_name": "KeyKey",
      "agent_type": "env_sync",
      "version": "1.0.0", 
      "status": "active",
      "capabilities": ["environment_sync", "credential_management"],
      "description": "Environment synchronization agent"
    },
    {
      "agent_name": "Doer",
      "agent_type": "executor",
      "version": "1.0.0",
      "status": "active",
      "capabilities": ["task_execution", "workflow_automation"],
      "description": "Task execution agent"
    }
  ]'

echo -e "\n✅ Production agents inserted!"

# Verify the setup
echo -e "\nVerifying setup..."
curl -X GET "$PROJECT_URL/rest/v1/agents?select=agent_name,agent_type,status" \
  -H "apikey: $SERVICE_KEY" \
  -H "Authorization: Bearer $SERVICE_KEY"

echo -e "\n\n🎉 COMPLETE! Agent registry is live at:"
echo "   https://texxwmlroefdisgxpszc.supabase.co"
echo ""
echo "🎯 Next steps:"
echo "   1. Check the agents table in Supabase Dashboard"
echo "   2. Run the AI Agent Auditor for OATH compliance"
echo "   3. Deploy agents using the deployment scripts"
echo ""
echo "✅ Database setup complete!"