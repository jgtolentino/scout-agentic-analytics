# Creative Effectiveness Scoring (CES) System Architecture

This reference architecture demonstrates how to build a production-ready creative effectiveness scoring system using multimodal AI models, integrated with Supabase, Vercel, and the TBWA Scout Analytics platform.

## Architecture overview

The Creative Effectiveness Scoring (CES) system provides automated analysis and scoring of creative assets (video, image, audio) against TBWA's creative effectiveness criteria. The system integrates multiple AI models with fallback capabilities, benchmark databases, and real-time dashboard visualization.

:::image type="content" source="./images/ces-architecture-overview.svg" alt-text="Architecture diagram showing the CES system components and data flow." lightbox="./images/ces-architecture-overview.svg":::

The architecture consists of several key components:

- **Asset Ingestion Layer**: Handles multimodal file uploads (ZIP, direct upload)
- **Processing Pipeline**: Multimodal AI analysis with model orchestration
- **Scoring Engine**: TBWA 8-dimension effectiveness evaluation
- **Benchmark Integration**: WARC, Cannes Lions, D&AD reference database
- **Analytics Dashboard**: Real-time visualization and reporting
- **Agent Orchestration**: Pulser agent coordination and task delegation

## Architecture components

### Asset Ingestion and Storage

| Component | Description | Technology |
|-----------|-------------|------------|
| **Upload Handler** | Multimodal asset ingestion with validation | Supabase Edge Functions |
| **Storage Layer** | Secure asset storage with RLS policies | Supabase Storage |
| **Processing Queue** | Async job processing for large files | Supabase Functions |

The ingestion layer supports multiple file formats:
- **Video**: MP4, MOV, WebM (up to 500MB)
- **Image**: JPG, PNG, PDF (up to 100MB) 
- **Audio**: MP3, WAV (up to 200MB)
- **Batch**: ZIP archives with mixed content

### AI Model Orchestration

The system employs a multi-tier model architecture with intelligent fallbacks:

#### Primary Models
- **LLaVA-Critic**: Visual content analysis and quality scoring
- **Q-Align**: Discrete-level visual scoring across modalities
- **Score2Instruct**: Video quality scoring with justification

#### Fallback Chain
1. **Claude 3.5 Opus** (Primary): Comprehensive multimodal analysis
2. **Amazon Nova Pro** (Secondary): Cost-effective processing
3. **GPT-4o** (Tertiary): Last resort with high accuracy

#### Model Selection Logic

```typescript
interface ModelOrchestrator {
  selectModel(assetType: 'video' | 'image' | 'audio'): Promise<ModelProvider>
  fallbackChain: ModelProvider[]
  confidenceThreshold: number
}
```

### Scoring Framework

The CES system implements TBWA's 8-dimensional creative effectiveness framework:

| Dimension | Weight | Description | Cultural Emphasis |
|-----------|--------|-------------|-------------------|
| **Clarity of Messaging** | 1.2x | Message comprehension | Local language nuances |
| **Emotional Resonance** | 1.3x | Emotional impact strength | Filipino cultural values |
| **Brand Recognition** | 1.1x | Brand presence and recall | Local brand associations |
| **Cultural Fit** | 1.4x | Cultural alignment | Philippine cultural cues |
| **Production Quality** | 1.0x | Technical execution | International standards |
| **Call to Action** | 1.1x | Action clarity | Localized behaviors |
| **Distinctiveness** | 1.5x | Disruption & originality | Market differentiation |
| **TBWA DNA** | 1.3x | Brand philosophy alignment | Agency principles |

### Data Architecture

#### Database Schema

The system uses a comprehensive PostgreSQL schema optimized for multimodal analytics:

```sql
-- Core asset management
CREATE TABLE ces.creative_assets (
    id UUID PRIMARY KEY,
    filename TEXT NOT NULL,
    file_url TEXT NOT NULL,
    asset_type TEXT GENERATED ALWAYS AS (
        CASE 
            WHEN content_type LIKE 'video/%' THEN 'video'
            WHEN content_type LIKE 'image/%' THEN 'image'
            WHEN content_type LIKE 'audio/%' THEN 'audio'
        END
    ) STORED,
    brand_context TEXT,
    campaign_name TEXT,
    competitive_set TEXT[],
    processing_status TEXT DEFAULT 'pending',
    quality_metrics JSONB
);

-- Evaluation results with computed scores
CREATE TABLE ces.evaluations (
    id UUID PRIMARY KEY,
    asset_id UUID REFERENCES ces.creative_assets(id),
    scores JSONB NOT NULL,
    overall_score NUMERIC GENERATED ALWAYS AS (
        (scores->>'clarity')::numeric + (scores->>'emotion')::numeric + 
        -- ... all 8 dimensions
    ) / 8.0) STORED,
    explanation TEXT,
    confidence_score NUMERIC,
    benchmark_percentile NUMERIC
);
```

#### Performance Optimization

- **Indexing Strategy**: Composite indexes on asset_type + brand_context
- **Partitioning**: Date-based partitioning for evaluation history
- **Caching**: Redis layer for frequent benchmark queries
- **CDN Integration**: Asset delivery optimization

### Security and Access Control

#### Row Level Security (RLS)

```sql
-- Agent-based access control
CREATE POLICY "Creative analysts access" ON ces.creative_assets 
    FOR ALL TO authenticated 
    USING (auth.jwt() ->> 'role' = 'creative_analyst');

-- Secure benchmark data
CREATE POLICY "Read benchmarks" ON ces.benchmark_library 
    FOR SELECT TO authenticated 
    USING (is_active = true);
```

#### API Security

- **JWT Authentication**: Supabase Auth integration
- **Rate Limiting**: 25 evaluations/minute per user
- **Input Validation**: Content-type and file size restrictions
- **Audit Logging**: Complete evaluation trail

## Deployment architecture

### Production Environment

The system deploys across multiple services for scalability and reliability:

:::image type="content" source="./images/ces-deployment-diagram.svg" alt-text="Deployment architecture showing multi-service setup." lightbox="./images/ces-deployment-diagram.svg":::

#### Core Services

| Service | Platform | Purpose | Scaling |
|---------|----------|---------|---------|
| **Edge Functions** | Supabase | AI model orchestration | Auto-scale |
| **Dashboard UI** | Vercel | User interface | Global CDN |
| **Database** | Supabase PostgreSQL | Data persistence | Read replicas |
| **Storage** | Supabase Storage | Asset management | Multi-region |
| **Queue Processing** | Supabase Functions | Background jobs | Horizontal scale |

#### Agent Integration

The system integrates with the Pulser agent framework:

```yaml
# CESAI Agent Configuration
agent:
  id: "CESAI"
  type: "creative_orchestrator"
  capabilities:
    - creative_effectiveness_scoring
    - benchmark_competitive_analysis
    - multimodal_asset_analysis
  integrations:
    - echo_data_extraction
    - scout_data_pipeline
    - insight_template_runner
```

### Development Environment

Local development setup supports the full pipeline:

```bash
# Environment setup
npm install
supabase start
vercel dev

# Deploy edge functions
supabase functions deploy ces-score
supabase functions deploy ces-upload

# Run migrations
supabase db push
```

## Design considerations

### Scalability

#### Horizontal Scaling
- **Stateless Functions**: Edge functions scale automatically
- **Database Sharding**: Asset partitioning by brand/date
- **CDN Distribution**: Global asset delivery
- **Queue Management**: Background processing for large batches

#### Performance Targets
- **Response Time**: <3 seconds per evaluation
- **Throughput**: 25+ evaluations per minute
- **Accuracy**: 94% correlation with human evaluation
- **Uptime**: 99.9% availability SLA

### Cost Optimization

#### Model Selection Strategy
```typescript
const modelCosts = {
  'llava-critic': { costPerToken: 0.001, accuracy: 0.92 },
  'claude-opus': { costPerToken: 0.015, accuracy: 0.95 },
  'nova-pro': { costPerToken: 0.008, accuracy: 0.93 }
};

function selectOptimalModel(complexity: number, budget: number): ModelProvider {
  return complexity > 0.8 ? 'claude-opus' : 'nova-pro';
}
```

#### Resource Management
- **Intelligent Caching**: Model results cached for 24 hours
- **Batch Processing**: Group similar assets for efficiency
- **Tiered Storage**: Hot/warm/cold asset storage
- **Model Pruning**: Remove underperforming model variants

### Reliability and Monitoring

#### Error Handling
```typescript
interface ErrorRecovery {
  retryPolicy: {
    maxRetries: 3,
    backoffStrategy: 'exponential',
    failoverModels: ModelProvider[]
  };
  circuitBreaker: {
    failureThreshold: 5,
    timeoutDuration: 30000
  };
}
```

#### Monitoring Stack
- **Health Checks**: Model availability and response time
- **Performance Metrics**: Scoring accuracy and processing speed
- **Alert System**: Failure detection and escalation
- **Audit Trail**: Complete evaluation history

## Example scenarios

### Scenario 1: Single Asset Evaluation

A creative director uploads a 30-second TV commercial for effectiveness analysis:

1. **Asset Upload**: Video file processed through ingestion pipeline
2. **Model Selection**: LLaVA-Critic selected for video analysis
3. **Multimodal Processing**: Frame extraction, audio transcription, text OCR
4. **Scoring**: 8-dimension TBWA framework evaluation
5. **Benchmark Comparison**: Positioning against WARC database
6. **Results Delivery**: Interactive dashboard with visual overlays

**Expected Output**:
```json
{
  "overall_score": 8.4,
  "scores": {
    "clarity": 8, "emotion": 9, "branding": 7,
    "culture": 9, "production": 10, "cta": 8,
    "distinctiveness": 9, "tbwa_dna": 8
  },
  "benchmark_percentile": 87,
  "explanation": "Strong emotional resonance with excellent production values...",
  "processing_time_ms": 2847
}
```

### Scenario 2: Competitive Campaign Analysis

Brand team analyzes competitor creative assets for strategic insights:

1. **Batch Upload**: Multiple competitor assets via ZIP upload
2. **Parallel Processing**: Agent delegation for concurrent analysis
3. **Comparative Scoring**: Cross-brand effectiveness comparison
4. **Market Positioning**: Competitive landscape visualization
5. **Strategic Recommendations**: Gap analysis and opportunities

### Scenario 3: Campaign Optimization

Creative team iterates on campaign concepts using CES feedback:

1. **Initial Evaluation**: Baseline creative assessment
2. **Optimization Suggestions**: AI-generated improvement recommendations
3. **Variant Testing**: A/B testing of creative modifications
4. **Performance Tracking**: Longitudinal effectiveness monitoring
5. **ROI Analysis**: Business impact correlation

## Next steps

### Implementation Phases

#### Phase 1: Core Infrastructure (Weeks 1-2)
- [ ] Deploy database schema and edge functions
- [ ] Implement basic scoring pipeline
- [ ] Create dashboard foundation

#### Phase 2: Model Integration (Weeks 3-4)
- [ ] Integrate primary AI models (LLaVA-Critic, Q-Align)
- [ ] Implement fallback orchestration
- [ ] Add benchmark database

#### Phase 3: Advanced Features (Weeks 5-6)
- [ ] Visual overlay generation
- [ ] Competitive analysis tools
- [ ] Batch processing optimization

#### Phase 4: Production Deployment (Weeks 7-8)
- [ ] Performance optimization
- [ ] Security hardening
- [ ] Monitoring implementation

### Related Resources

- [TBWA Creative Effectiveness Framework](./tbwa-framework.md)
- [Pulser Agent Integration Guide](./pulser-integration.md)
- [API Reference Documentation](./api-reference.md)
- [Deployment Guide](./deployment-guide.md)

---

## Contributors

This architecture was developed by the TBWA Scout Analytics team in collaboration with InsightPulseAI, incorporating industry best practices for AI-powered creative analysis systems.