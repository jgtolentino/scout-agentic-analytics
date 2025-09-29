# Scout v7 Project Structure

**Complete enterprise analytics platform with Azure deployment and multi-mode capabilities**

---

## 🏗️ Top-Level Architecture

```
scout-v7/
├── apps/                           # Application modules
│   ├── dal-agent/                  # Data Access Layer & Analytics Engine
│   ├── scout-dashboard/            # Legacy dashboard (Azure-integrated)
│   ├── standalone-dashboard-nextjs/ # Next.js standalone dashboard
│   ├── standalone-dashboard-v7-enhanced/ # Enhanced Vite dashboard
│   ├── suqi-analytics/             # AI analytics backend
│   └── suqi-public/               # Production public dashboard ✅
├── azure/                          # Azure infrastructure configs
├── sql/                           # Database schemas & migrations
├── scripts/                       # Automation & deployment scripts
├── docs/                          # Documentation & guides
└── bruno/                         # API testing & automation
```

---

## 📊 Apps Directory Breakdown

### **dal-agent** (Core Analytics Engine)

**Purpose**: Multi-mode analytics engine with Azure Functions, local fallback, and comprehensive data processing

**Key Components:**
- **Scout Analytics Engine**: `scout-comprehensive-system.py` - Multi-mode deployment (local/hybrid/Azure)
- **API Server**: `scout-api-server.py` - Flask API with fallback pattern
- **Azure Functions**: Custom container with ODBC18 drivers for production deployment
- **Bruno Collections**: One-shot deployment automation and testing suites
- **Data Processing**: ETL pipelines, Nielsen taxonomy, and export systems

**Critical Files:**
```
dal-agent/
├── scout-comprehensive-system.py    # Core multi-mode engine
├── scout-api-server.py             # API server with fallback
├── azure-functions/                # Production Azure deployment
│   ├── Dockerfile                  # Custom ODBC18 container
│   ├── http_analyze/              # HTTP trigger function
│   └── timer_insightpack/         # Timer trigger function
├── bruno-one-shot-deployment.collection.json  # Complete deployment
├── observability-integration.py   # App Insights telemetry
├── azure-ai-search-index.json    # Vector search configuration
└── CRITICAL_FIXES_APPLIED.md      # Production readiness summary
```

**Data Flow:**
```
Azure SQL → ETL Pipeline → Gold Layer → Analytics Engine → API/Dashboard
```

### **suqi-public** (Production Dashboard) ✅

**Purpose**: Live production dashboard with real Scout v7 data

**Status**: **DEPLOYED** - https://suqi-public.vercel.app/
- 12,192 canonical transactions processed
- 99.25% data extraction success rate
- <200ms API response times

**Architecture:**
```
suqi-public/
├── app/api/                        # Next.js API routes
├── src/components/                 # React components
├── lib/                           # Database & auth utilities
└── vercel.json                    # Production deployment config
```

### **standalone-dashboard-v7-enhanced** (Vite Dashboard)

**Purpose**: Enhanced dashboard with advanced UI components and real-time analytics

**Tech Stack**: Vite + React + TypeScript + Tailwind
**Features**: Data storytelling compliance, advanced charting, export systems

```
standalone-dashboard-v7-enhanced/
├── src/
│   ├── components/                 # Reusable UI components
│   ├── hooks/                     # Custom React hooks
│   ├── state/                     # State management
│   └── types/                     # TypeScript definitions
├── dist/                          # Production build
└── Data_Storytelling_Checklist.md # Implementation guide
```

### **scout-dashboard** (Legacy Azure-Integrated)

**Purpose**: Original dashboard with Azure AD integration and security

**Features**: Enterprise authentication, RBAC, secure Azure connectivity

### **suqi-analytics** (AI Backend)

**Purpose**: AI-powered analytics backend with predictive modeling

**Components**: FastAPI backend, ML services, data processing

---

## 🗃️ SQL & Database Layer

### **Schema Organization**
```
sql/
├── analytics/                      # Business intelligence views
├── migrations/                     # Database schema changes
├── procedures/                     # Stored procedures
├── views/                         # Database views
└── validation/                    # Data quality checks
```

### **Key Views & Procedures**
- `dbo.v_transactions_flat_production` - Flattened transaction data
- `dbo.v_canonical_export_45` - 45-column canonical export
- Nielsen taxonomy integration with 6-level hierarchy
- Enhanced ETL with column mapping and validation

---

## 🚀 Deployment & Infrastructure

### **Azure Components**
```
azure/
├── data-factory/                   # ETL pipeline configs
├── functions/                      # Serverless deployment
├── ai-search/                     # Vector search index
└── key-vault/                     # Secrets management
```

### **Bruno Automation**
```
bruno/
├── bruno-one-shot-deployment.collection.json  # Complete deployment
├── bruno-analytics-complete.yml              # Analytics validation
└── flat_export_bulletproof.bru              # Export testing
```

### **Deployment Modes**

**1. Local Zero-Subscription**
- SQLite database
- Local analytics engine
- No external dependencies

**2. Hybrid Mode**
- Local engine + Azure services
- Enhanced AI capabilities
- Cost-optimized approach

**3. Full Azure**
- Complete cloud deployment
- Enterprise-grade security
- Managed Identity + Key Vault

---

## 📋 Documentation Structure

### **Technical Documentation**
```
docs/
├── AZURE_DEPLOYMENT_GUIDE.md      # Azure setup instructions
├── SCOUT_API_DOCUMENTATION.md     # API reference
├── ETL_PIPELINE_COMPLETE.md       # Data processing guide
└── NIELSEN_1100_IMPLEMENTATION_COMPLETE.md  # Taxonomy guide
```

### **Process Documentation**
- `Data_Storytelling_Checklist.md` - Dashboard design standards
- `CRITICAL_FIXES_APPLIED.md` - Production readiness report
- `CANONICAL_DEPLOYMENT_CHECKLIST.md` - Deployment validation

---

## 🔧 Automation & Scripts

### **Core Scripts**
```
scripts/
├── conn_default.sh                # Secure database connection
├── export_canonical.sh           # Data export automation
├── deploy_nielsen_taxonomy.sh    # Taxonomy deployment
└── sql.sh                        # SQL execution wrapper
```

### **Validation & Testing**
- Bruno collections for API testing
- Data quality validation scripts
- Schema compliance checking
- Performance monitoring

---

## 📊 Data Flow Architecture

### **ETL Pipeline**
```
Source Data → Bronze (Raw) → Silver (Cleaned) → Gold (Enriched) → Platinum (Analytics)
```

### **Analytics Processing**
```
Gold Layer → Scout Engine → API Endpoints → Dashboard Visualization
```

### **Export Systems**
- Canonical 45-column export
- Cross-tabulation analysis
- Nielsen taxonomy integration
- Real-time analytics generation

---

## 🎯 Current Status

### **Production Ready** ✅
- **suqi-public**: Live dashboard with real data
- **dal-agent**: Multi-mode analytics engine with critical fixes
- **Azure Infrastructure**: Complete deployment automation
- **Data Quality**: 99.25% processing success rate

### **Development Active** 🔄
- Enhanced dashboard features
- AI-powered insights
- Performance optimization
- Additional analytics modules

### **Documentation Complete** 📚
- Technical specifications
- API documentation
- Deployment guides
- Data storytelling standards

---

## 🚦 Quick Start Commands

### **Local Development**
```bash
# Start analytics engine
cd apps/dal-agent
python scout-comprehensive-system.py

# Launch dashboard
cd apps/suqi-public
npm run dev
```

### **Production Deployment**
```bash
# Deploy complete system
bruno run bruno-one-shot-deployment.collection.json

# Validate deployment
make doctor && make flat
```

### **Data Operations**
```bash
# Export canonical data
./scripts/export_canonical.sh

# Deploy Nielsen taxonomy
./scripts/deploy_nielsen_taxonomy.sh
```

---

**Project Status**: Production-ready enterprise analytics platform with comprehensive Azure integration and multi-mode deployment capabilities.