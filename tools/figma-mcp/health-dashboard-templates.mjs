// Health Dashboard UI Kit Template Mapper
import { exportPNGs, getVariables } from "./sdk.js";

const HEALTH_DASHBOARD_FILE = "kXOb4ck97DsiGrm815VgDz";

// Template structure based on Health Dashboard UI Kit
const DASHBOARD_TEMPLATES = {
  // Main Dashboard Screens
  screens: [
    { id: "main-dashboard", nodeId: "0:1", name: "Main Dashboard", type: "screen" },
    { id: "analytics-view", nodeId: "analytics-screen", name: "Analytics View", type: "screen" },
    { id: "patients-list", nodeId: "patients-screen", name: "Patients List", type: "screen" },
    { id: "appointments", nodeId: "appointments-screen", name: "Appointments", type: "screen" },
    { id: "medical-records", nodeId: "records-screen", name: "Medical Records", type: "screen" }
  ],

  // Component Templates
  components: [
    // KPI Cards & Metrics
    { id: "kpi-card-large", nodeId: "kpi-large", name: "KPI Card Large", type: "component" },
    { id: "kpi-card-small", nodeId: "kpi-small", name: "KPI Card Small", type: "component" },
    { id: "health-score-donut", nodeId: "health-donut", name: "Health Score Donut", type: "component" },
    { id: "vital-signs-card", nodeId: "vitals-card", name: "Vital Signs Card", type: "component" },
    
    // Charts & Visualizations
    { id: "heart-rate-chart", nodeId: "heart-chart", name: "Heart Rate Chart", type: "component" },
    { id: "blood-pressure-chart", nodeId: "bp-chart", name: "Blood Pressure Chart", type: "component" },
    { id: "weight-trend-chart", nodeId: "weight-chart", name: "Weight Trend Chart", type: "component" },
    { id: "activity-bar-chart", nodeId: "activity-bars", name: "Activity Bar Chart", type: "component" },
    
    // Lists & Tables
    { id: "patient-row", nodeId: "patient-item", name: "Patient List Row", type: "component" },
    { id: "appointment-card", nodeId: "appointment-item", name: "Appointment Card", type: "component" },
    { id: "medication-row", nodeId: "med-item", name: "Medication Row", type: "component" },
    { id: "lab-result-card", nodeId: "lab-card", name: "Lab Result Card", type: "component" },
    
    // Navigation & Layout
    { id: "sidebar-nav", nodeId: "sidebar", name: "Sidebar Navigation", type: "component" },
    { id: "top-header", nodeId: "header", name: "Top Header", type: "component" },
    { id: "breadcrumbs", nodeId: "breadcrumb", name: "Breadcrumbs", type: "component" },
    
    // Form Elements
    { id: "search-bar", nodeId: "search", name: "Search Bar", type: "component" },
    { id: "filter-dropdown", nodeId: "filter", name: "Filter Dropdown", type: "component" },
    { id: "date-picker", nodeId: "date-picker", name: "Date Picker", type: "component" },
    
    // Status & Indicators
    { id: "status-badge", nodeId: "status-badge", name: "Status Badge", type: "component" },
    { id: "priority-indicator", nodeId: "priority", name: "Priority Indicator", type: "component" },
    { id: "health-alert", nodeId: "alert", name: "Health Alert", type: "component" },
    
    // Modals & Overlays
    { id: "patient-modal", nodeId: "patient-modal", name: "Patient Details Modal", type: "component" },
    { id: "appointment-modal", nodeId: "appt-modal", name: "Appointment Modal", type: "component" },
    { id: "notification-toast", nodeId: "toast", name: "Notification Toast", type: "component" }
  ]
};

// Color palette specific to Health Dashboard
const HEALTH_PALETTE = {
  primary: "#10B981", // Green for health/positive
  secondary: "#3B82F6", // Blue for info
  accent: "#8B5CF6", // Purple for premium features
  warning: "#F59E0B", // Amber for warnings
  danger: "#EF4444", // Red for critical/urgent
  success: "#10B981", // Green for success states
  neutral: {
    50: "#F9FAFB",
    100: "#F3F4F6",
    200: "#E5E7EB", 
    300: "#D1D5DB",
    400: "#9CA3AF",
    500: "#6B7280",
    600: "#4B5563",
    700: "#374151",
    800: "#1F2937",
    900: "#111827"
  }
};

export async function exportHealthDashboardTemplates() {
  console.log("🏥 Exporting Health Dashboard Templates");
  
  const outputDir = "templates/health-dashboard";
  
  // Export all template references
  const allNodeIds = [
    ...DASHBOARD_TEMPLATES.screens.map(s => s.nodeId),
    ...DASHBOARD_TEMPLATES.components.map(c => c.nodeId)
  ];
  
  try {
    await exportPNGs(HEALTH_DASHBOARD_FILE, allNodeIds, outputDir);
    
    // Create template metadata
    const metadata = {
      fileId: HEALTH_DASHBOARD_FILE,
      palette: HEALTH_PALETTE,
      templates: DASHBOARD_TEMPLATES,
      exportedAt: new Date().toISOString()
    };
    
    const fs = require('fs');
    fs.writeFileSync(
      `${outputDir}/templates.json`, 
      JSON.stringify(metadata, null, 2)
    );
    
    console.log(`✅ Exported ${allNodeIds.length} Health Dashboard templates`);
    return metadata;
    
  } catch (error) {
    console.error("❌ Failed to export templates:", error);
    throw error;
  }
}

// Generate React component templates
export function generateReactTemplates(metadata) {
  const templates = {};
  
  // Generate screen templates
  metadata.templates.screens.forEach(screen => {
    templates[screen.id] = {
      component: generateScreenTemplate(screen),
      story: generateScreenStory(screen),
      test: generateScreenTest(screen)
    };
  });
  
  // Generate component templates  
  metadata.templates.components.forEach(component => {
    templates[component.id] = {
      component: generateComponentTemplate(component),
      story: generateComponentStory(component),
      test: generateComponentTest(component),
      codeConnect: generateCodeConnect(component)
    };
  });
  
  return templates;
}

function generateScreenTemplate(screen) {
  return `// Generated from Health Dashboard UI Kit
import React from 'react';
import { ${screen.name.replace(/\s+/g, '')}Layout } from '../layouts';
import { useHealthDashboard } from '../hooks/useHealthDashboard';

interface ${screen.name.replace(/\s+/g, '')}Props {
  className?: string;
}

export function ${screen.name.replace(/\s+/g, '')}({ className }: ${screen.name.replace(/\s+/g, '')}Props) {
  const { data, loading, error } = useHealthDashboard();

  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;

  return (
    <${screen.name.replace(/\s+/g, '')}Layout className={className}>
      {/* Template content based on ${screen.nodeId} */}
    </${screen.name.replace(/\s+/g, '')}Layout>
  );
}`;
}

function generateComponentTemplate(component) {
  return `// Generated from Health Dashboard UI Kit  
import React from 'react';

interface ${component.name.replace(/\s+/g, '')}Props {
  className?: string;
  // Add props based on Figma component variants
}

export function ${component.name.replace(/\s+/g, '')}({ className, ...props }: ${component.name.replace(/\s+/g, '')}Props) {
  return (
    <div className={\`health-${component.id} \${className}\`} data-testid="${component.id}">
      {/* Template content based on ${component.nodeId} */}
    </div>
  );
}`;
}

// Run if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  exportHealthDashboardTemplates()
    .then(metadata => {
      console.log("🎯 Template export complete!");
      console.log(`📊 Screens: ${metadata.templates.screens.length}`);
      console.log(`🧩 Components: ${metadata.templates.components.length}`);
    })
    .catch(console.error);
}