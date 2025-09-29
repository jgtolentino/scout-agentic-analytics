# Data Storytelling Checklist

**Baseline standard for Scout Analytics dashboard design and development**

---

## ✅ What's Already Deployed (Storytelling-Compliant)

### **Headline KPI Cards with Deltas**
Daily Volume, Daily Revenue, Avg Basket Size, Avg Duration with green/red % deltas → quick "what changed" narrative.

### **Context-First Charting**
Default time-series for "Transaction Volume Trends" with clear labeling and single-color emphasis → lowers cognitive load.

### **Guided Narrative Panel ("Transaction Trends Insights")**
Curated bullets (peak hours, weekend uplift, metro velocity, avg duration) + AI Recommendations → converts raw data into actions.

### **Structured Exploration**
Tabs (Volume / Revenue / Basket Size / Duration) create a storyline: *how much → how valuable → how big → how long*.

### **Filterable Framing**
Right rail with Analysis Mode (single / compare / multi), Brands, Categories, Locations, Time & Temporal → adapts stories to different audiences without rebuilding.

### **Temporal Framing**
Daily period selection and "Trend Analysis / Show Delta" → supports *then vs now* comparisons.

### **Export & Refresh**
One-click Export and Refresh → keeps the story current and shareable.

### **Information Architecture**
Left navigation mirrors a classic story arc:
Transaction Trends → Product Mix → Consumer Behavior → Consumer Profiling → Competitive → Geographical.
(From *what's happening* to *why it's happening* to *where to act*.)

---

## 🎯 What's Missing (Quick Wins to Make It Airtight)

### **Inline Annotations on Charts**
Peak callouts (e.g., "Sep 3: payday bump +18%") and weekend shading.
→ Add badges + legend item for "weekend."

### **Compare Mode Visuals**
When "vs previous" is on, show dual line or ghost overlay with end-point lift labels.

### **Small Multiples**
With brand/category filters, render mini trend strips (sparklines) for fast pattern scanning.

### **Confidence & Sample Notes**
Tiny footnote under insights: filters applied, N size, data span, last refresh → avoids misreads.

### **Bookmark/Share States**
"Copy story link" that preserves filters + tab → lets teams share identical views.

### **KPI Tooltips**
Define formula + period for each KPI to prevent drift in interpretation.

### **Narrative Template**
"Generate brief" button outputs 4 bullets: *What changed, Where, Why (hypothesis), What to do next*—auto-filled from insights.

### **Accessibility Polish**
Contrast-check the yellows; add keyboard focus for right-rail filters.

---

## 📋 Implementation Checklist

**Design Teams:**
- [ ] Create annotation system for chart peak callouts
- [ ] Design compare mode dual-line overlays
- [ ] Implement sparkline small multiples
- [ ] Add confidence indicators and footnotes
- [ ] Design bookmark/share UI patterns
- [ ] Create KPI tooltip definitions
- [ ] Design narrative template generator
- [ ] Audit accessibility (contrast, keyboard navigation)

**Development Teams:**
- [ ] Build inline chart annotation system
- [ ] Implement compare mode visualization logic
- [ ] Create sparkline component library
- [ ] Add metadata footnotes to insights
- [ ] Build URL state management for sharing
- [ ] Create tooltip system for KPI definitions
- [ ] Implement auto-narrative generation
- [ ] Complete accessibility remediation

**Content Teams:**
- [ ] Define KPI formulas and periods
- [ ] Create annotation content guidelines
- [ ] Write narrative template patterns
- [ ] Establish confidence thresholds
- [ ] Document sharing best practices

---

## 🎯 Success Metrics

**Reader Comprehension:**
- Time to insight <30 seconds
- Question-to-answer path <3 clicks
- Export usage >20% of sessions

**Technical Performance:**
- Chart load time <200ms
- Filter response <100ms
- Export generation <5 seconds

**Accessibility Compliance:**
- WCAG 2.1 AA standards
- Keyboard navigation support
- Screen reader compatibility

---

**Status:** Reader-ready baseline standard for Scout Analytics dashboard development