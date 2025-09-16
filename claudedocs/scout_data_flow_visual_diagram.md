# Scout v7.1 Visual Data Flow Diagrams

## Complete System Architecture

```mermaid
graph TB
    subgraph "Data Sources"
        A1[Azure SQL Database<br/>160K+ interactions]
        A2[Google Drive<br/>Documents & Files]
        A3[IoT Edge Devices<br/>Real-time Data]
        A4[External APIs<br/>Third-party Data]
    end

    subgraph "Ingestion Layer"
        B1[SuperClaude ETL Orchestrator]
        B2[drive-mirror Edge Function]
        B3[drive-stream-extract Edge Function]
        B4[drive-webhook-handler Edge Function]
        B5[Azure SQL Connector]
    end

    subgraph "Bronze Layer - Raw Data"
        C1[azure_data.interactions]
        C2[bronze.campaign_data]
        C3[bronze.product_catalog]
        C4[bronze.demographic_data]
        C5[bronze.store_locations]
        C6[bronze.transaction_logs]
    end

    subgraph "Silver Layer - Cleansed Data"
        D1[Data Quality Engine]
        D2[silver.customer_profiles]
        D3[silver.transactions_cleaned]
        D4[silver.product_hierarchy]
        D5[silver.campaign_performance]
        D6[silver.demographic_insights]
    end

    subgraph "Gold Layer - Analytics"
        E1[Aggregation Engine]
        E2[gold.customer_360]
        E3[gold.product_performance]
        E4[gold.campaign_roi]
        E5[gold.market_segments]
        E6[gold.brand_affinity]
        E7[gold.geographic_trends]
    end

    subgraph "Platinum Layer - AI/ML"
        F1[MindsDB MCP Server<br/>localhost:47334]
        F2[platinum.customer_predictions]
        F3[platinum.demand_forecasting]
        F4[platinum.price_optimization]
        F5[platinum.campaign_optimization]
        F6[platinum.market_intelligence]
    end

    subgraph "MCP Integration"
        G1[Context7 MCP<br/>Documentation & Patterns]
        G2[SuperClaude Framework v3.0<br/>Agent Orchestration]
    end

    subgraph "Monitoring & Governance"
        H1[metadata.etl_job_runs]
        H2[metadata.quality_metrics]
        H3[metadata.data_lineage]
        H4[metadata.error_log]
        H5[metadata.sla_monitoring]
    end

    subgraph "Applications"
        I1[Next.js Dashboard<br/>Real-time Analytics]
        I2[Standalone Dashboard<br/>Executive Reports]
        I3[API Endpoints<br/>External Access]
    end

    %% Data Flow
    A1 --> B5
    A2 --> B2
    A3 --> B4
    A4 --> B1

    B1 --> C1
    B2 --> C2
    B3 --> C3
    B4 --> C4
    B5 --> C5

    C1 --> D1
    C2 --> D1
    C3 --> D1
    C4 --> D1
    C5 --> D1
    C6 --> D1

    D1 --> D2
    D1 --> D3
    D1 --> D4
    D1 --> D5
    D1 --> D6

    D2 --> E1
    D3 --> E1
    D4 --> E1
    D5 --> E1
    D6 --> E1

    E1 --> E2
    E1 --> E3
    E1 --> E4
    E1 --> E5
    E1 --> E6
    E1 --> E7

    E2 --> F1
    E3 --> F1
    E4 --> F1
    E5 --> F1
    E6 --> F1
    E7 --> F1

    F1 --> F2
    F1 --> F3
    F1 --> F4
    F1 --> F5
    F1 --> F6

    %% MCP Integration
    G1 --> B1
    G1 --> D1
    G1 --> E1
    G2 --> B1
    G2 --> F1

    %% Monitoring
    B1 --> H1
    D1 --> H2
    E1 --> H3
    F1 --> H4
    H1 --> H5

    %% Applications
    E2 --> I1
    E3 --> I1
    F2 --> I1
    F3 --> I2
    F4 --> I3

    %% Styling
    classDef source fill:#e1f5fe
    classDef bronze fill:#fff3e0
    classDef silver fill:#f3e5f5
    classDef gold fill:#fff8e1
    classDef platinum fill:#e8f5e8
    classDef mcp fill:#fce4ec
    classDef monitoring fill:#f1f8e9
    classDef app fill:#e3f2fd

    class A1,A2,A3,A4 source
    class C1,C2,C3,C4,C5,C6 bronze
    class D1,D2,D3,D4,D5,D6 silver
    class E1,E2,E3,E4,E5,E6,E7 gold
    class F1,F2,F3,F4,F5,F6 platinum
    class G1,G2 mcp
    class H1,H2,H3,H4,H5 monitoring
    class I1,I2,I3 app
```

## ETL Processing Pipeline

```mermaid
graph LR
    subgraph "Daily ETL Cycle"
        A[06:00 - Bronze Ingestion] --> B[08:00 - Silver Processing]
        B --> C[10:00 - Gold Analytics] 
        C --> D[12:00 - Platinum AI/ML]
        D --> E[Continuous - Real-time Updates]
    end

    subgraph "Quality Gates"
        F[Schema Validation] --> G[Business Rules]
        G --> H[Data Quality Scoring]
        H --> I[MindsDB Anomaly Detection]
        I --> J[Performance Validation]
        J --> K[Lineage Tracking]
        K --> L[SLA Compliance]
        L --> M[Health Monitoring]
    end

    A --> F
    B --> G
    C --> H
    D --> I
```

## MindsDB MCP Integration Flow

```mermaid
graph TD
    subgraph "MindsDB MCP Server (localhost:47334)"
        A[Local MindsDB Instance]
        B[ML Model Training]
        C[Prediction Engine]
        D[Model Performance Monitor]
    end

    subgraph "Gold Layer Data"
        E[gold.customer_360]
        F[gold.product_performance] 
        G[gold.campaign_roi]
        H[gold.market_segments]
    end

    subgraph "ML Models"
        I[Sales Forecasting<br/>predictor_sales_forecast]
        J[Customer Churn<br/>predictor_customer_churn]
        K[Demand Planning<br/>predictor_demand_planning]
        L[Price Optimization<br/>predictor_price_elasticity]
        M[Campaign Performance<br/>predictor_campaign_roi]
    end

    subgraph "Platinum Insights"
        N[platinum.customer_predictions]
        O[platinum.demand_forecasting]
        P[platinum.price_optimization]
        Q[platinum.campaign_optimization]
        R[platinum.market_intelligence]
    end

    subgraph "SuperClaude Orchestration"
        S[MCP Request Handler]
        T[Model Lifecycle Management]
        U[Prediction Scheduling]
        V[Performance Monitoring]
    end

    %% Data Flow
    E --> A
    F --> A  
    G --> A
    H --> A

    A --> B
    B --> I
    B --> J
    B --> K
    B --> L
    B --> M

    I --> C
    J --> C
    K --> C
    L --> C
    M --> C

    C --> N
    C --> O
    C --> P
    C --> Q
    C --> R

    %% Orchestration
    S --> A
    T --> B
    U --> C
    V --> D

    %% Monitoring
    D --> T
```

## SuperClaude Agent Orchestration

```mermaid
graph TB
    subgraph "SuperClaude Framework v3.0"
        A[Master Orchestrator Agent]
        B[Ingestion Agent]
        C[Quality Agent]
        D[Analytics Agent]
        E[ML Agent]
        F[Monitoring Agent]
    end

    subgraph "MCP Servers"
        G[Context7 MCP<br/>Documentation & Patterns]
        H[MindsDB MCP<br/>ML & Predictions]
    end

    subgraph "ETL Layers"
        I[Bronze Layer]
        J[Silver Layer]
        K[Gold Layer]  
        L[Platinum Layer]
    end

    subgraph "Metadata Framework"
        M[agent_orchestration]
        N[etl_job_runs]
        O[quality_metrics]
        P[data_lineage]
        Q[error_log]
    end

    %% Agent Coordination
    A --> B
    A --> C
    A --> D
    A --> E
    A --> F

    %% MCP Integration
    B --> G
    C --> G
    D --> G
    E --> H
    F --> G

    %% Layer Processing
    B --> I
    C --> J
    D --> K
    E --> L

    %% Metadata Tracking
    A --> M
    B --> N
    C --> O
    D --> P
    F --> Q

    %% Quality Gates
    I --> C
    J --> D
    K --> E
    L --> F
```

## Data Quality & Governance Flow

```mermaid
graph LR
    subgraph "Data Quality Framework"
        A[Data Ingestion]
        B[Schema Validation]
        C[Business Rule Engine]
        D[Quality Scoring]
        E[Anomaly Detection]
        F[Lineage Tracking]
        G[Compliance Check]
    end

    subgraph "Quality Metrics"
        H[Completeness Score >95%]
        I[Uniqueness Score <0.1% duplicates]
        J[Validity Score >90%]
        K[Consistency Score >85%]
        L[Timeliness <30min latency]
    end

    subgraph "Data Contracts"
        M[Schema Definition]
        N[Quality Requirements]  
        O[SLA Thresholds]
        P[Business Rules]
    end

    subgraph "Monitoring & Alerts"
        Q[Real-time Quality Dashboard]
        R[SLA Breach Alerts]
        S[Error Notification]
        T[Performance Reports]
    end

    %% Quality Flow
    A --> B
    B --> C
    C --> D
    D --> E
    E --> F
    F --> G

    %% Metrics
    D --> H
    D --> I
    D --> J
    D --> K
    D --> L

    %% Contracts
    M --> B
    N --> C
    O --> D
    P --> C

    %% Monitoring
    H --> Q
    I --> R
    J --> S
    K --> T
```

## Real-time Processing Architecture

```mermaid
graph TD
    subgraph "Event Sources"
        A[Google Drive Webhooks]
        B[IoT Device Streams]
        C[API Events]
        D[Database Changes]
    end

    subgraph "Event Processing"
        E[drive-webhook-handler]
        F[Event Router]
        G[Stream Processor]
        H[Change Data Capture]
    end

    subgraph "Processing Pipeline"
        I[Event Validation]
        J[Transformation Engine]
        K[Quality Gates]
        L[Target Layer Update]
    end

    subgraph "Real-time Updates"
        M[Dashboard Refresh]
        N[Alert Generation]
        O[Downstream Notifications]
        P[Cache Invalidation]
    end

    %% Event Flow
    A --> E
    B --> F
    C --> G
    D --> H

    E --> I
    F --> I
    G --> I
    H --> I

    I --> J
    J --> K
    K --> L

    L --> M
    L --> N
    L --> O
    L --> P
```

## Performance & Monitoring Dashboard

```mermaid
graph TB
    subgraph "Performance Metrics"
        A[Processing Latency<br/><30min target]
        B[Throughput<br/>Records/hour]
        C[Error Rate<br/><0.1% target]
        D[System Uptime<br/>>99.9% target]
    end

    subgraph "Data Quality Metrics"
        E[Overall Quality Score<br/>>90% target]
        F[Completeness<br/>>95% critical fields]
        G[Accuracy<br/>>85% ML predictions]
        H[Freshness<br/><1hr critical data]
    end

    subgraph "Business KPIs"
        I[Data Processing Cost<br/>60% reduction]
        J[Manual Work Reduction<br/>90% automation]
        K[Decision Speed<br/>Real-time insights]
        L[ROI Improvement<br/>25% campaign optimization]
    end

    subgraph "Health Status"
        M[Bronze Layer: Healthy ✅]
        N[Silver Layer: Healthy ✅]
        O[Gold Layer: Healthy ✅]
        P[Platinum Layer: Healthy ✅]
    end

    %% Connections showing monitoring flow
    A --> M
    B --> N  
    C --> O
    D --> P
    E --> I
    F --> J
    G --> K
    H --> L
```