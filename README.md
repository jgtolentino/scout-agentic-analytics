# Scout v7.1 Agentic Analytics Platform

## Overview

Scout v7.1 transforms Scout Dashboard from basic ETL/BI to an intelligent conversational analytics platform powered by a multi-agent system. Users interact in natural language (English/Filipino) for insights, forecasts, and recommendations.

## Architecture

### Core Agents
- **QueryAgent**: Natural language to SQL conversion with security validation
- **RetrieverAgent**: RAG pipeline for business context and competitive intelligence  
- **ChartVisionAgent**: Automated visualization and chart generation
- **NarrativeAgent**: Executive summaries and insights in natural language
- **AgentOrchestrator**: Multi-agent coordination and workflow management

### Data Pipeline
- **Medallion Architecture**: Bronze → Silver → Gold → Platinum
- **RAG Pipeline**: pgvector embeddings with hybrid search (vector + BM25)
- **Semantic Layer**: Business logic abstraction with Filipino language support
- **Row Level Security**: Tenant isolation via JWT claims

### Deployment
- **Supabase Edge Functions**: Serverless Deno runtime for agent endpoints
- **MindsDB Integration**: Predictive analytics and forecasting
- **Real-time Processing**: Streaming data ingestion and analysis

## Quick Start

```bash
# Setup environment
make v7-setup

# Deploy all components  
make v7-deploy

# Run tests
make v7-test

# Check status
make status
```

## Documentation

- [Product Requirements](./PRD.md)
- [Architecture Guide](./docs/ARCHITECTURE.md) 
- [Deployment Guide](./docs/DEPLOYMENT.md)
- [Agent Contracts](./agents/contracts.yaml)

## Features

- 🤖 **Multi-Agent Intelligence**: Specialized agents for different analytics tasks
- 🌐 **Multilingual Support**: English and Filipino language processing
- 📊 **Automated Visualization**: Smart chart generation based on data insights
- 🔒 **Enterprise Security**: Row-level security and audit logging
- ⚡ **Real-time Analytics**: Streaming data processing and live insights
- 🎯 **Predictive Intelligence**: MindsDB integration for forecasting

## License

MIT License - Built by TBWA Data Intelligence Team