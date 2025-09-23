# Scout v7 Business & Research Question Framework

**Directive**: Every chart/table should answer one of these questions—nothing else.

## 1. Time of Day Analysis

### Business Questions
- **Peak Patterns**: When do snacks vs. beverages peak?
- **Brand Performance**: Which brands win at Evening vs. Morning vs. Afternoon?
- **Category Timing**: Do different product categories have distinct daypart preferences?

### Research Questions
- **Association**: Is daypart associated with category/brand (χ²)?
- **Prediction**: Does daypart predict basket size (ANOVA/OLS)?
- **Temporal Patterns**: Statistical significance of time-based consumption patterns

### Available Data Columns
- `daypart` (Morning, Afternoon, Evening)
- `brand`, `category`, `product_name`
- `Basket_Item_Count`, `Amount`
- `weekday_weekend`

---

## 2. Basket Behavior Analysis

### Business Questions
- **Basket Composition**: Do large baskets favor staples vs. impulse items?
- **Payment Patterns**: Do large baskets correlate with e-wallet usage?
- **Value Optimization**: What drives higher transaction values?

### Research Questions
- **Independence**: Is payment method independent of basket size (χ²)?
- **Correlation**: Correlation between basket_size and transaction value?
- **Segmentation**: Basket behavior patterns across customer segments

### Available Data Columns
- `Basket_Item_Count`, `Amount`, `avg_transaction_value`
- `payment_method`
- `total_items_purchased`, `total_spent`

---

## 3. Demographics & Emotions Analysis

### Business Questions
- **Peak Demographics**: Which age bracket × gender dominates weekend evenings?
- **Emotional Shopping**: Do stressed/happy shoppers skew toward specific categories?
- **Weekend Patterns**: How do demographics shift between weekdays and weekends?

### Research Questions
- **Association Tests**: emotion × daypart, age bracket × category (χ²)
- **Regression Models**: value ~ emotion + age + gender (Logistic/OLS)
- **Interaction Effects**: Age × gender × daypart interaction patterns

### Available Data Columns
- `weekday_weekend`, `daypart`
- Demographics fields (Age, Gender from enhanced features)
- Emotional state indicators (from audio_transcript analysis)

---

## 4. Brand Switching & Substitution Analysis

### Business Questions
- **Substitution Vulnerability**: Which categories are most substitution-prone?
- **Recommendation Impact**: Which brands benefit from owner suggestions?
- **Competitive Dynamics**: Brand switching patterns across stores

### Research Questions
- **Change Analysis**: Δshare pre/post suggestion with confidence intervals
- **Substitution Rate**: Substitution rate by category with statistical significance
- **Predictive Models**: Likelihood of brand switching based on context

### Available Data Columns
- `substitution_events` (when implemented)
- `brand`, `category`, `product_name`
- `audio_transcript` (for suggestion analysis)
- Store-level brand performance metrics

---

## 5. Location Intelligence

### Business Questions
- **Geographic Performance**: Which municipalities over-index for Brand B evenings?
- **Store Optimization**: Location-specific category and brand preferences
- **Regional Patterns**: Metro Manila consumption pattern variations

### Research Questions
- **Mixed Models**: value ~ daypart + brand + (1|municipality)
- **Geographic Clustering**: Spatial patterns in consumption behavior
- **Location Effects**: Store location impact on brand/category performance

### Available Data Columns
- `StoreID`, `StoreName`, `municipality_name`
- `stores_visited`, `cross_store_mobility`
- Geographic indicators from enhanced customer features

---

## Implementation Roadmap

### Phase 1: Core Analytics (Immediate)
1. **Time of Day Analysis**: Daypart × category/brand performance
2. **Basket Behavior**: Payment method × basket size correlation
3. **Location Intelligence**: Store-level brand performance

### Phase 2: Advanced Analytics (Next Sprint)
1. **Demographics Integration**: Age/gender analysis when available
2. **Emotion Analysis**: Audio transcript sentiment analysis
3. **Substitution Tracking**: Brand switching detection

### Phase 3: Predictive Models (Future)
1. **Mixed Effect Models**: Hierarchical location modeling
2. **Causal Inference**: Pre/post intervention analysis
3. **Real-time Recommendations**: Dynamic substitution suggestions

---

## Statistical Testing Framework

### Required Tests
- **χ² Tests**: Independence testing for categorical variables
- **ANOVA/OLS**: Continuous outcome prediction
- **Logistic Regression**: Binary outcome modeling
- **Mixed Effects**: Hierarchical/nested data modeling
- **Confidence Intervals**: All effect size estimates

### Success Metrics
- **Statistical Significance**: p < 0.05 for primary hypotheses
- **Effect Sizes**: Practical significance thresholds
- **Model Performance**: R² > 0.3 for prediction models
- **Business Impact**: Measurable revenue/efficiency gains

---

## Data Quality Requirements

### Minimum Sample Sizes
- **χ² Tests**: ≥5 expected frequency per cell
- **ANOVA**: ≥30 per group for normality
- **Regression**: ≥10 observations per predictor
- **Mixed Models**: ≥20 clusters with ≥5 observations each

### Data Completeness Targets
- **Core Variables**: >95% completeness
- **Secondary Variables**: >80% completeness
- **Geographic Data**: >90% store mapping
- **Temporal Data**: Complete daypart coverage

This framework ensures every analysis directly addresses business needs while maintaining statistical rigor.