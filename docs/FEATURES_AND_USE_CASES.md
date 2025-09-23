# Scout v7 Features & Use Cases Specification

**Complete feature enumeration and role-based use cases for TBWA Project Scout v7**

---

# Features (Complete)

## A) Data & Architecture

### Supabase Medallion Pipeline
* **Bronze (Raw)** → **Silver (Clean)** → **Gold (KPIs/Views)** → **Platinum (Frameworks/Benchmarks/CES)**
* Complete data lineage with quality gates at each layer
* Automated ETL with CRISP-DM methodology integration

### Approved Views for Edge Functions (Read-Only)
**Gold Layer Views:**
- `gold_customer_activity` - Customer behavior and interaction patterns
- `gold_product_combinations` - Basket analysis and product associations
- `gold_persona_region_metrics` - Geographic persona distribution and performance

**Platinum Layer Views:**
- `platinum_recommendations` - AI-generated recommendations with ROI projections
- `platinum_basket_combos` - Advanced basket combination insights
- `platinum_persona_insights` - Deep persona behavioral analysis

**Consumption Views:**
- `v_store_kpi_platinum` - Store-level KPI dashboard data
- `v_store_persona_mix` - Store persona composition analysis
- `v_distributor_network_platinum` - Distributor network intelligence
- `v_store_sales_hourly` - Hourly sales pattern analysis

### Hybrid CAG + RAG Architecture
**CAG (Cache) - Static Data:**
- Master product catalog
- Geographic hierarchy (barangay/municipality/region)
- KPI definitions and business rules
- Static taxonomies and classifications

**RAG (Retrieval) - Dynamic Data:**
- Fresh transaction streams
- Daily brand share calculations
- Real-time substitution patterns
- Price elasticity metrics
- Predictive analytics outputs
- Creative Effectiveness Score (CES) data

### Security & Access Control
* **Role-Based Row Level Security (RLS)**
* **Conformed Metric Access** - No raw table exposure from Edge Functions
* **Bruno-routed secrets** - Zero credential handling by Claude
* **Read-only data paths** from Edge Functions to data layer

---

## B) Intelligence & Models

### Dynamic Persona System
* **Data-Driven Clustering** - Not limited to 4 static personas
* **Similarity Scoring** - Continuous persona matching with confidence levels
* **Rules-Augmented Classification** - Business logic overlay on ML clustering
* **Dynamic Persona Creation** - Auto-generate new personas when similarity falls below threshold

### Transaction Inference Engine
**Bidirectional Inference:**
- **Items from Context** - Infer SKUs from amount/time/location patterns
- **Gap Completion** - Infer missing transactions from inventory/cash deltas
- **Pattern Matching** - Use basket combos and time-of-day patterns
- **Probabilistic Completion** - Statistical confidence scoring for inferences

**Time-Series Forecasting (Optional):**
- Hour/day horizon demand predictions
- Store-level inventory optimization
- Staffing requirement forecasting

### Recommendations Engine (ROI-Linked)
**Recommendation Types:**
- **Inventory** - Stock optimization with projected ROI
- **Pricing** - Dynamic pricing suggestions with elasticity consideration
- **Marketing** - Persona-targeted promotional recommendations
- **Supply/Sales** - Distribution and sales strategy optimization

**Features:**
- **Persona-Aware** - Tailored to customer segment preferences
- **Role-Aware** - Customized for user role (owner/distributor/brand manager)
- **Projected Impact** - Quantified ROI and success probability

### Reinforcement Learning Loop
* **Unified Feedback Logging** - `model_feedback` table captures all interactions
* **Action Types** - accept/reject/correct/ignore recommendations
* **Policy Tuning** - Bandit/RL-ready architecture for continuous improvement
* **Performance Tracking** - Model effectiveness measurement over time

### Model Architecture Philosophy
* **Model-Agnostic** - Support heuristic + statistical + ML approaches
* **No Vendor Lock** - Platform-independent implementations
* **Confidence Scoring** - All predictions include uncertainty estimates
* **Explainable AI** - Business-interpretable model outputs

---

## C) Edge Functions (Supabase)

### Core AI Functions

**`inferTransaction()`**
- **Purpose** - Enrich and complete partial transaction data
- **Features** - Forecast when requested, confidence scoring, partial success handling
- **Response Codes** - 206 (partial completion), 422 (validation failure), 200 (success)
- **Input** - Partial transaction context (amount, time, location, available items)
- **Output** - Completed transaction with confidence scores

**`matchPersona()`**
- **Purpose** - Assign customers to behavioral personas
- **Algorithm** - Cluster similarity + business rules
- **Features** - Confidence scoring, dynamic persona creation
- **Threshold Management** - Create new personas when similarity < threshold
- **Output** - Persona assignment with similarity score and characteristics

**`generateRecommendations()`**
- **Purpose** - Generate role-aware business recommendations
- **Features** - Projected ROI calculation, recommendation logging
- **Personalization** - Persona-aware and role-specific suggestions
- **Types** - Inventory, pricing, marketing, operational recommendations
- **Feedback Loop** - Integration with `model_feedback` for continuous learning

### Data Access Layer (DAL)
* **View-Only Access** - Exclusively uses gold/platinum views
* **Clean Function Routing** - Claude/SuperClaude compatible interfaces
* **Performance Optimized** - <1.2s CAG, <3s RAG response times
* **Error Handling** - Comprehensive error responses with actionable guidance

---

## D) Schema Additions

### New Tables

**`persona_cluster`**
- Dynamic clustering results
- Optional embedding centroids for ML-based matching
- Cluster characteristics and business interpretation
- Performance metrics per cluster

**`buyer_persona`**
- Current persona assignments for customers
- Similarity scores and confidence levels
- Assignment history and evolution tracking
- Business-relevant persona characteristics

**`transaction_inference`**
- Inferred transaction fields with confidence scores
- Original vs. inferred data comparison
- Inference methodology and model version
- Quality assurance flags and manual overrides

**`sales_forecast`** (Optional)
- Store-level demand predictions by time horizon
- Confidence intervals and prediction accuracy
- Historical forecast vs. actual performance
- Input features and model interpretability

**`recommendation`**
- Issued recommendations with projected ROI
- Recommendation type, target persona, and business context
- Implementation status and actual vs. projected outcomes
- User feedback and effectiveness measurement

**`model_feedback`**
- Reinforcement learning feedback loop
- User actions: accept/reject/correct/ignore
- Context and reasoning for feedback
- Model performance impact tracking

---

## E) Agentic Strategy Pipeline (McKinsey-Grade)

### Strategic Intelligence Workflow
**Maya** (Context Discovery) →
**Claudia** (Stakeholder Analysis) →
**Gagambi** (Market & Competitive Intelligence) →
**Manus** (Framework Application: Porter/BCG/SWOT/Value Chain) →
**Echo** (Insight Extraction) →
**Ace** (Options & Trade-offs Analysis) →
**Yummy** (Prioritized Recommendations) →
**Deckgen** (Executive Presentation) →
**Basher** (90/180/365 Day Roadmap)

### Orchestration
* **Sari-Sari Advanced Expert** - Master orchestrator
* **CAG+RAG Integration** - Seamless data access across pipeline
* **Sub-Agent Coordination** - Intelligent task routing and result synthesis
* **Executive Artifacts** - McKinsey-quality deliverables

---

## F) Dashboard & UX (Scout v6)

### Dashboard Structure
**Tab Organization:**
- **Executive** - C-suite KPIs and strategic overview
- **Analytics** - Deep-dive analysis and diagnostic tools
- **Brands** - Brand performance and competitive analysis
- **Geo** - Geographic performance and territory insights
- **Strategy** - Strategic planning and scenario analysis

### UI Components
* **KPI Cards** - Real-time performance indicators
* **Predictive Charts** - Forecasting and trend visualization
* **Barangay Choropleths** - Geographic heat maps
* **Persona Mix Panels** - Customer segment visualization
* **Recommendations Feed** - AI suggestions with accept/dismiss logging

### Design Standards
* **TBWA/SMP Styling** - Brand-compliant design system
* **Power BI-Level Polish** - Professional dashboard aesthetics
* **Technology Stack** - React + Tailwind + Supabase hooks
* **Responsive Design** - Mobile-first with desktop optimization

---

## G) Gold-Standard Alignment (FMCG)

### Reference Standards
* **Academic** - *Marketing Metrics*, *How Brands Grow*, *Retail Analytics*
* **Industry** - IPA/WARC effectiveness frameworks
* **Methodological** - MMM, market basket analysis, demand elasticity, RFM/CLV
* **Creative** - CES + WARC/IPA creative effectiveness measurement

### Analytical Methods
**Market Mix Modeling (MMM)**
- Multi-touch attribution across channels
- Media effectiveness and optimization
- Incremental lift measurement

**Market Basket Analysis**
- Apriori and FP-Growth algorithms
- Association rules mining
- Cross-selling opportunity identification

**Demand Elasticity**
- Price sensitivity analysis
- Promotional effectiveness measurement
- Competitive response modeling

**Customer Analytics**
- RFM (Recency, Frequency, Monetary) segmentation
- Customer Lifetime Value (CLV) prediction
- Churn probability and retention strategies

---

## H) Orchestration & Security

### SuperClaude Integration
* **Agent Registration** - Formal agent manifest and capability declaration
* **Prompt Engineering** - Standardized prompt templates and validation
* **Registry Management** - Centralized agent discovery and version control
* **Validation Framework** - Automated testing and quality assurance

### Security Architecture
* **Bruno Secret Routing** - Centralized credential management
* **Zero Claude Credentials** - No direct credential access for AI agents
* **Read-Only Data Paths** - Secure data access from Edge Functions
* **Audit Trail** - Comprehensive logging of all data access and modifications

---

## I) Development & Infrastructure Quality

### Performance Targets
* **CAG Response Time** - <1.2 seconds for cached data retrieval
* **RAG Response Time** - <3 seconds for fresh data queries
* **Metric Alignment** - ≥90% consistency across data layers
* **User Adoption** - Cross-role engagement and utilization metrics

### Code Quality Standards
**JavaScript/TypeScript Hygiene:**
- JSX components in `.tsx` files only
- Vite React plugin configuration
- `tsconfig.json` with `jsx: react-jsx` setting
- Comprehensive type safety and linting

**Development Workflow:**
- Soft reload capabilities for rapid development
- Validation hooks for agent registry updates
- Automated testing and quality gates
- Performance monitoring and optimization

---

# Use Cases (By Role)

## Store Owner (Sari-sari Entrepreneur)

### Daily Operations
**Auto-Complete Missing Sales**
- Log cash and change at day end
- System infers missing SKUs and quantities
- Confidence levels surfaced for validation
- Manual override capability for corrections

**Demand Forecasting**
- Next 24-72 hour demand predictions
- Preparation guidance for stock and staffing
- Weather and event-based adjustments
- Historical accuracy tracking

**Inventory Management**
- **Stockout Prevention** - Proactive alerts with reorder suggestions
- **ROI Calculation** - Quantified impact of avoided stockouts
- **Supplier Integration** - Direct reorder capabilities where available
- **Seasonal Planning** - Holiday and event-based inventory optimization

### Customer Experience
**Persona-Based Promotions**
- Student morning combo recommendations
- Senior citizen essential bundles
- Family weekend packages
- Seasonal promotional ideas

**Smart Pricing**
- Margin optimization suggestions on high-velocity items
- Low-elasticity item identification
- Competitive pricing alerts
- Dynamic promotional pricing

**Point-of-Sale Intelligence**
- Up-sell suggestions at checkout
- Cross-sell recommendations based on basket analysis
- Customer preference learning
- Loyalty program integration

---

## Distributor / Supplier

### Territory Management
**Geographic Intelligence**
- **Barangay-Level Heatmaps** - Demand spikes and gap identification
- **Territory Performance** - Comparative analysis across regions
- **Market Penetration** - Opportunity identification and expansion planning
- **Competitive Landscape** - Share analysis and positioning insights

**Network Optimization**
- **Stock Planning** - Store-specific restock recommendations prioritized by ROI
- **Route Optimization** - Efficient delivery routing based on predicted demand
- **Capacity Management** - Focus routes where predicted demand exceeds capacity
- **Performance Tracking** - Delivery effectiveness and customer satisfaction

### Product Management
**Slow-Mover Recovery**
- Identify products moving slowly in specific locations
- Targeted promotional recommendations where peer stores succeed
- Transfer suggestions between high/low performing locations
- Clearance strategy optimization

**Demand Planning**
- Aggregate demand forecasting across network
- Seasonal pattern recognition and planning
- New product introduction strategies
- Inventory level optimization

---

## Brand Manager (FMCG)

### Market Intelligence
**Share & Penetration Tracking**
- Real-time market share monitoring via Gold views
- Penetration analysis by geographic segment
- Competitive positioning and movement alerts
- Category growth and decline patterns

**Substitution Analysis**
- Competitive substitution pattern identification
- Brand switching behavior analysis
- Price sensitivity and elasticity measurement
- Promotional cannibalisation assessment

### Campaign Effectiveness
**Promotional ROI**
- Real-time promotional performance tracking
- Elasticity estimates by micro-region
- Cross-promotional impact analysis
- Campaign optimization recommendations

**Creative Effectiveness**
- **Persona Lift Analysis** - Which creative/offers move which personas
- **CES Integration** - Creative Effectiveness Score tracking
- **WARC/IPA Alignment** - Industry benchmark comparison
- **Multi-touch Attribution** - Campaign interaction effects

### Strategic Planning
**Scenario Analysis**
- Price/promotion mix trade-off modeling
- Competitive response simulation
- Market expansion opportunity assessment
- Resource allocation optimization

---

## TBWA Strategist / Executive

### Strategic Intelligence
**McKinsey-Style Reporting**
- Auto-generated strategic reports from real data
- Executive summary with key insights and recommendations
- Risk assessment and mitigation strategies
- KPI dashboard with strategic context

**Creative Strategy**
- **Creative Effectiveness Overlays** - CES + WARC/IPA linkage to sales outcomes
- **Campaign Performance Analysis** - Multi-dimensional effectiveness measurement
- **Brand Health Monitoring** - Long-term brand equity tracking
- **Competitive Intelligence** - Market positioning and share of voice analysis

### Client Management
**Strategy Pipeline Management**
- Client-specific strategy runbooks per region
- 90/180/365-day milestone tracking
- Deliverable management and progress monitoring
- Stakeholder communication and reporting

**Business Development**
- Market opportunity identification and sizing
- Competitive landscape analysis and positioning
- Pitch support with data-driven insights
- ROI projection and business case development

---

## Analyst / Operations

### Diagnostic Tools
**One-Click Diagnostics**
- **Top Driver Analysis** (Echo) - Automated insight identification
- **Outlier Detection** - Statistical anomaly identification
- **Data Quality Assessment** - Completeness and accuracy monitoring
- **Performance Benchmarking** - Industry and peer comparison

### Model Management
**Feedback Curation**
- Review inference edits and recommendation outcomes
- Model performance tuning and optimization
- User feedback analysis and integration
- Continuous improvement implementation

**Governance & Audit**
- **Transaction Inference Audit** - Review `transaction_inference` table for accuracy
- **Model Feedback Analysis** - Examine `model_feedback` for patterns and insights
- **Compliance Monitoring** - Ensure adherence to business rules and regulations
- **Performance Reporting** - Model effectiveness and business impact measurement

### Operations Excellence
**Process Optimization**
- Workflow efficiency analysis and improvement
- Automation opportunity identification
- Resource allocation optimization
- Performance standard establishment and monitoring

**Quality Assurance**
- Data validation and cleansing procedures
- Model output verification and testing
- User acceptance testing and feedback integration
- Continuous improvement process management

---

## Implementation Roadmap

### Phase 1: Foundation (Q1)
- Medallion architecture implementation
- Core Edge Functions development
- Basic dashboard with essential KPIs
- Initial persona system deployment

### Phase 2: Intelligence (Q2)
- Advanced AI models and recommendations
- Full agentic strategy pipeline
- Enhanced dashboard with predictive analytics
- Reinforcement learning loop activation

### Phase 3: Scale (Q3)
- Multi-region deployment
- Advanced creative effectiveness integration
- Full SuperClaude orchestration
- Enterprise-grade security and compliance

### Phase 4: Optimization (Q4)
- Performance optimization and scaling
- Advanced analytics and insights
- Full automation and self-service capabilities
- Strategic planning and scenario modeling

---

*This specification serves as the definitive guide for Scout v7 development and implementation. All features and use cases are designed to deliver measurable business value while maintaining technical excellence and user experience standards.*