-- Scout Recommendations Seed Data
-- 7 exemplar recommendations representing each tier

-- Operational tier: Day-to-day optimizations
insert into scout.recommendations (
  title,
  description,
  tier,
  confidence_score,
  expected_impact,
  implementation_effort,
  priority_rank,
  evidence,
  data_sources,
  filters_applied,
  recommended_actions,
  success_metrics,
  timeline_estimate,
  resource_requirements,
  target_audience,
  affected_categories,
  affected_regions,
  tags,
  status
) values (
  'Optimize High-Volume SKU Inventory Levels',
  'Analysis shows 15 SKUs with >10% stockout rate contributing to $2.1M lost revenue. Recommend adjusting reorder points and safety stock levels based on demand forecasting.',
  'operational',
  0.87,
  'Reduce stockouts by 60%, increase revenue by $1.26M annually',
  'Low - Requires inventory system configuration updates',
  85,
  '[
    {"metric": "stockout_rate", "value": "15.3%", "benchmark": "5.0%", "source": "inventory_analysis"},
    {"metric": "lost_revenue", "value": 2100000, "currency": "USD", "period": "annual"},
    {"metric": "affected_skus", "value": 15, "total_skus": 1247}
  ]'::jsonb,
  ARRAY['inventory_transactions', 'sales_data', 'demand_forecast'],
  '{"date_range": {"from": "2025-08-01", "to": "2025-09-01"}, "categories": ["electronics", "accessories"], "regions": ["NCR", "Cebu"]}'::jsonb,
  ARRAY[
    'Increase reorder points by 25% for top 15 SKUs',
    'Implement automated low-stock alerts',
    'Review supplier lead times and adjust safety stock',
    'Set up weekly inventory review meetings'
  ],
  ARRAY[
    'Stockout rate < 5%',
    'Inventory turnover ratio improvement',
    'Customer satisfaction scores',
    'Lost sales reduction tracking'
  ],
  '2-3 weeks implementation',
  'Inventory manager, data analyst, supplier coordination',
  'Operations teams, procurement managers',
  ARRAY['electronics', 'accessories'],
  ARRAY['NCR', 'Cebu', 'Davao'],
  ARRAY['inventory', 'operational', 'stockout', 'revenue'],
  'pending'
);

-- Tactical tier: Short-term strategic moves  
insert into scout.recommendations (
  title,
  description,
  tier,
  confidence_score,
  expected_impact,
  implementation_effort,
  priority_rank,
  evidence,
  data_sources,
  filters_applied,
  recommended_actions,
  success_metrics,
  timeline_estimate,
  resource_requirements,
  target_audience,
  affected_categories,
  affected_regions,
  tags,
  status
) values (
  'Launch Cross-Category Bundle Campaign for Q4',
  'Consumer behavior analysis reveals 34% of customers purchase complementary items within 7 days. Create bundle offerings combining electronics with accessories to increase average order value.',
  'tactical',
  0.79,
  'Increase AOV by 18%, drive 12% revenue growth in Q4',
  'Medium - Requires campaign development and system integration',
  78,
  '[
    {"metric": "cross_purchase_rate", "value": "34%", "benchmark": "25%", "source": "customer_journey_analysis"},
    {"metric": "avg_order_value", "value": 1450, "currency": "PHP", "period": "monthly"},
    {"metric": "bundle_opportunity", "value": "18%", "calculation": "potential_aov_increase"}
  ]'::jsonb,
  ARRAY['transaction_data', 'customer_behavior', 'market_basket_analysis'],
  '{"date_range": {"from": "2025-07-01", "to": "2025-09-01"}, "customer_segments": ["frequent_buyers", "electronics_buyers"], "categories": ["electronics", "accessories", "mobile"]}'::jsonb,
  ARRAY[
    'Identify top 20 complementary product pairs',
    'Create bundle pricing strategy (10-15% discount)',
    'Develop Q4 marketing campaign materials',
    'Set up cross-sell recommendations in POS',
    'Train sales staff on bundle benefits'
  ],
  ARRAY[
    'Average order value increase >15%',
    'Bundle attachment rate >25%',
    'Q4 revenue growth >10%',
    'Customer satisfaction maintained >4.2/5'
  ],
  '6-8 weeks for full campaign launch',
  'Marketing team, category managers, POS system admin',
  'Category managers, marketing team, sales staff',
  ARRAY['electronics', 'accessories', 'mobile'],
  ARRAY['NCR', 'Cebu', 'Davao', 'Iloilo'],
  ARRAY['campaign', 'bundle', 'cross-sell', 'q4', 'revenue'],
  'pending'
);

-- Strategic tier: Medium-term positioning
insert into scout.recommendations (
  title,
  description,
  tier,
  confidence_score,
  expected_impact,
  implementation_effort,
  priority_rank,
  evidence,
  data_sources,
  filters_applied,
  recommended_actions,
  success_metrics,
  timeline_estimate,
  resource_requirements,
  target_audience,
  affected_categories,
  affected_regions,
  tags,
  status
) values (
  'Expand Premium Brand Portfolio in Tier-2 Cities',
  'Market analysis shows 42% untapped demand for premium brands in Tier-2 cities with 28% higher profit margins. Strategic expansion could capture $5.8M market opportunity.',
  'strategic',
  0.72,
  'Capture $5.8M market opportunity, establish presence in 8 new markets',
  'High - Requires market research, supplier negotiations, logistics setup',
  90,
  '[
    {"metric": "market_opportunity", "value": 5800000, "currency": "USD", "source": "market_research"},
    {"metric": "untapped_demand", "value": "42%", "calculation": "tier2_cities_analysis"},
    {"metric": "profit_margin", "value": "28%", "comparison": "vs_current_portfolio"},
    {"metric": "target_cities", "value": 8, "total_tier2": 24}
  ]'::jsonb,
  ARRAY['market_research', 'competitive_analysis', 'demographic_data', 'purchasing_power'],
  '{"geographic_scope": "tier_2_cities", "brand_tier": "premium", "income_brackets": ["upper_middle", "affluent"], "categories": ["electronics", "appliances", "luxury_goods"]}'::jsonb,
  ARRAY[
    'Conduct detailed market research in top 8 Tier-2 cities',
    'Negotiate premium brand partnerships and distribution rights',
    'Establish supply chain and logistics for new markets',
    'Develop market-specific pricing and promotion strategies',
    'Hire and train local sales teams',
    'Launch pilot stores in 3 cities first'
  ],
  ARRAY[
    'Revenue from Tier-2 cities >$5M annually',
    'Premium brand portfolio margin >25%',
    'Market share in target cities >8%',
    'Customer acquisition cost <$45',
    'Store profitability within 18 months'
  ],
  '12-18 months for full market entry',
  'Business development, supply chain, operations, marketing, HR',
  'C-level executives, regional managers, business development',
  ARRAY['electronics', 'appliances', 'luxury_goods'],
  ARRAY['Baguio', 'Bacolod', 'Cagayan de Oro', 'General Santos', 'Legazpi', 'Naga', 'Puerto Princesa', 'Tuguegarao'],
  ARRAY['expansion', 'premium', 'tier2', 'market_entry', 'strategic'],
  'pending'
);

-- Transformational tier: Long-term business transformation
insert into scout.recommendations (
  title,
  description,
  tier,
  confidence_score,
  expected_impact,
  implementation_effort,
  priority_rank,
  evidence,
  data_sources,
  filters_applied,
  recommended_actions,
  success_metrics,
  timeline_estimate,
  resource_requirements,
  target_audience,
  affected_categories,
  affected_regions,
  tags,
  status
) values (
  'Digital-First Omnichannel Transformation',
  'Customer journey analysis reveals 67% of purchases involve digital touchpoints. Implement unified commerce platform integrating online, mobile, and in-store experiences for seamless customer journey.',
  'transformational',
  0.84,
  'Transform customer experience, increase digital revenue by 150%, improve customer lifetime value by 45%',
  'Very High - Enterprise platform implementation, staff training, process redesign',
  95,
  '[
    {"metric": "digital_touchpoints", "value": "67%", "source": "customer_journey_mapping"},
    {"metric": "mobile_traffic", "value": "52%", "growth": "23% YoY"},
    {"metric": "omnichannel_customers", "value": "31%", "higher_ltv": "45%"},
    {"metric": "digital_revenue_potential", "value": "150%", "calculation": "vs_current_digital"}
  ]'::jsonb,
  ARRAY['customer_analytics', 'digital_engagement', 'sales_data', 'market_trends'],
  '{"transformation_scope": "enterprise", "channels": ["online", "mobile", "in_store", "social"], "customer_segments": ["all"], "technology_stack": ["ecommerce", "pos", "crm", "analytics"]}'::jsonb,
  ARRAY[
    'Select and implement unified commerce platform',
    'Integrate POS, ecommerce, and mobile applications',
    'Implement single customer view and loyalty program',
    'Redesign in-store experience with digital integration',
    'Launch mobile app with AR/VR features',
    'Implement AI-powered personalization engine',
    'Train staff on omnichannel customer service',
    'Migrate customer data and ensure GDPR compliance'
  ],
  ARRAY[
    'Digital revenue growth >150%',
    'Omnichannel customers >60%',
    'Customer lifetime value +45%',
    'Net promoter score >50',
    'Mobile conversion rate >3.5%',
    'Cross-channel attribution accuracy >85%'
  ],
  '24-36 months for complete transformation',
  'IT, digital marketing, operations, customer service, training, change management',
  'CEO, CTO, VP Digital, VP Operations, all department heads',
  ARRAY['all_categories'],
  ARRAY['NCR', 'Cebu', 'Davao', 'nationwide'],
  ARRAY['digital_transformation', 'omnichannel', 'platform', 'customer_experience'],
  'pending'
);

-- Governance tier: Policy and process improvements
insert into scout.recommendations (
  title,
  description,
  tier,
  confidence_score,
  expected_impact,
  implementation_effort,
  priority_rank,
  evidence,
  data_sources,
  filters_applied,
  recommended_actions,
  success_metrics,
  timeline_estimate,
  resource_requirements,
  target_audience,
  affected_categories,
  affected_regions,
  tags,
  status
) values (
  'Implement Data Governance Framework for Analytics',
  'Audit reveals 23% data inconsistencies across systems affecting decision-making accuracy. Establish comprehensive data governance to ensure data quality, privacy compliance, and analytics reliability.',
  'governance',
  0.91,
  'Improve data accuracy to 98%, ensure compliance, reduce analytics errors by 75%',
  'Medium - Policy development, training, system integration',
  82,
  '[
    {"metric": "data_inconsistency", "value": "23%", "source": "data_audit_2025"},
    {"metric": "analytics_errors", "value": "18%", "impact": "decision_making"},
    {"metric": "compliance_gaps", "value": 7, "total_requirements": 12},
    {"metric": "data_sources", "value": 15, "integrated": 9}
  ]'::jsonb,
  ARRAY['data_audit', 'system_logs', 'compliance_review', 'analytics_accuracy'],
  '{"scope": "enterprise_data", "systems": ["crm", "pos", "ecommerce", "inventory", "analytics"], "compliance": ["gdpr", "local_privacy", "industry_standards"]}'::jsonb,
  ARRAY[
    'Establish data governance committee and roles',
    'Create data quality standards and validation rules',
    'Implement master data management for customers/products',
    'Set up automated data quality monitoring',
    'Develop data privacy and security policies',
    'Create data access controls and audit trails',
    'Train staff on data handling procedures',
    'Implement data lineage tracking'
  ],
  ARRAY[
    'Data accuracy >98%',
    'Analytics error rate <5%',
    'Compliance score 100%',
    'Data governance maturity level 4/5',
    'Staff training completion >95%',
    'Data audit findings <3 critical'
  ],
  '4-6 months for full implementation',
  'Data team, IT security, legal, training, business analysts',
  'Data stewards, analysts, compliance team, executive leadership',
  ARRAY['all_data_sources'],
  ARRAY['all_locations'],
  ARRAY['governance', 'data_quality', 'compliance', 'privacy', 'analytics'],
  'pending'
);

-- Financial tier: Financial optimization
insert into scout.recommendations (
  title,
  description,
  tier,
  confidence_score,
  expected_impact,
  implementation_effort,
  priority_rank,
  evidence,
  data_sources,
  filters_applied,
  recommended_actions,
  success_metrics,
  timeline_estimate,
  resource_requirements,
  target_audience,
  affected_categories,
  affected_regions,
  tags,
  status
) values (
  'Dynamic Pricing Strategy Implementation',
  'Price elasticity analysis shows 31% margin improvement potential through dynamic pricing. Implement AI-driven pricing engine to optimize margins while maintaining competitiveness.',
  'financial',
  0.88,
  'Increase gross margin by 31%, optimize pricing across 85% of SKUs, improve competitive positioning',
  'High - AI system implementation, market data integration, staff training',
  88,
  '[
    {"metric": "margin_improvement_potential", "value": "31%", "source": "price_elasticity_analysis"},
    {"metric": "price_optimizable_skus", "value": "85%", "total_skus": 1247},
    {"metric": "competitor_price_variance", "value": "12%", "opportunity": "pricing_gaps"},
    {"metric": "current_gross_margin", "value": "24.5%", "target": "32.1%"}
  ]'::jsonb,
  ARRAY['pricing_data', 'competitor_analysis', 'demand_elasticity', 'margin_analysis'],
  '{"pricing_scope": "dynamic", "categories": ["electronics", "appliances", "accessories"], "market_factors": ["competition", "demand", "inventory", "seasonality"]}'::jsonb,
  ARRAY[
    'Implement AI-powered dynamic pricing engine',
    'Integrate competitor price monitoring feeds',
    'Set up automated repricing rules and thresholds',
    'Create margin protection and floor pricing controls',
    'Develop pricing strategy dashboard for management',
    'Train category managers on pricing optimization',
    'Implement A/B testing framework for pricing',
    'Set up performance monitoring and alerts'
  ],
  ARRAY[
    'Gross margin increase >28%',
    'Price optimization coverage >80% SKUs',
    'Competitive price positioning maintained',
    'Revenue growth maintained >15%',
    'Pricing decision speed <4 hours',
    'Manager adoption rate >90%'
  ],
  '3-5 months for full deployment',
  'Pricing team, data scientists, category managers, IT development',
  'CFO, category managers, pricing analysts, sales teams',
  ARRAY['electronics', 'appliances', 'accessories', 'mobile'],
  ARRAY['NCR', 'Cebu', 'Davao', 'nationwide'],
  ARRAY['pricing', 'margin', 'ai', 'optimization', 'financial'],
  'pending'
);

-- Experiment tier: A/B tests and pilot programs
insert into scout.recommendations (
  title,
  description,
  tier,
  confidence_score,
  expected_impact,
  implementation_effort,
  priority_rank,
  evidence,
  data_sources,
  filters_applied,
  recommended_actions,
  success_metrics,
  timeline_estimate,
  resource_requirements,
  target_audience,
  affected_categories,
  affected_regions,
  tags,
  status
) values (
  'AI-Powered Product Recommendation Engine A/B Test',
  'Pilot program to test machine learning recommendations vs current rule-based system. Initial analysis suggests 22% improvement in click-through rates and 15% increase in conversion.',
  'experiment',
  0.67,
  'Test potential for 22% CTR improvement and 15% conversion increase',
  'Low-Medium - Pilot implementation, limited scope testing',
  65,
  '[
    {"metric": "expected_ctr_improvement", "value": "22%", "confidence": "67%"},
    {"metric": "expected_conversion_increase", "value": "15%", "baseline": "current_system"},
    {"metric": "pilot_scope", "value": "500", "unit": "customers", "duration": "8_weeks"},
    {"metric": "implementation_cost", "value": 45000, "currency": "PHP", "vs_expected_benefit": "positive"}
  ]'::jsonb,
  ARRAY['user_behavior', 'recommendation_performance', 'conversion_data', 'clickstream'],
  '{"test_scope": "pilot", "customer_segment": "electronics_buyers", "channels": ["website", "mobile_app"], "sample_size": 500, "duration": "8_weeks"}'::jsonb,
  ARRAY[
    'Design A/B test framework for recommendation engine',
    'Implement ML-based recommendation algorithm',
    'Set up control and treatment groups (250 each)',
    'Create performance tracking dashboard',
    'Define success criteria and statistical significance',
    'Run 8-week pilot test period',
    'Collect and analyze performance data',
    'Prepare rollout plan if test succeeds'
  ],
  ARRAY[
    'Statistical significance achieved (p<0.05)',
    'Click-through rate change measurement',
    'Conversion rate change measurement',
    'Revenue per user impact analysis',
    'User satisfaction survey results',
    'System performance and latency metrics'
  ],
  '8-12 weeks for complete experiment cycle',
  'Data science team, UX designer, frontend developer, analytics specialist',
  'Digital team, data scientists, product managers',
  ARRAY['electronics', 'mobile', 'accessories'],
  ARRAY['NCR', 'Cebu'],
  ARRAY['experiment', 'ab_test', 'ml', 'recommendation', 'pilot'],
  'pending'
);