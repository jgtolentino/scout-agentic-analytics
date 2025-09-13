#!/usr/bin/env node
// Complete Health Dashboard Template Generation Pipeline
import fs from 'fs';
import path from 'path';
import { generateAllScreens } from './screen-templates.mjs';
import { generateAllComponents } from './component-templates.mjs';
import { exportHealthDashboardTemplates } from '../figma-mcp/health-dashboard-templates.mjs';

const CONFIG = {
  healthDashboardFileId: "kXOb4ck97DsiGrm815VgDz",
  outputDirs: {
    screens: "apps/health-dashboard/src/screens",
    components: "apps/health-dashboard/src/components", 
    templates: "templates/health-dashboard",
    docs: "docs/templates"
  },
  generateOptions: {
    screens: true,
    components: true,
    figmaExport: true,
    documentation: true,
    tests: true,
    storybook: true,
    codeConnect: true
  }
};

class TemplateGenerator {
  constructor(config = CONFIG) {
    this.config = config;
    this.results = {
      screens: {},
      components: {},
      figmaRefs: null,
      errors: []
    };
  }

  async generateAll() {
    console.log('🏥 Starting Health Dashboard Template Generation');
    console.log('=' .repeat(60));
    
    try {
      // Step 1: Export Figma references
      if (this.config.generateOptions.figmaExport) {
        await this.exportFigmaReferences();
      }

      // Step 2: Generate screen templates  
      if (this.config.generateOptions.screens) {
        await this.generateScreenTemplates();
      }

      // Step 3: Generate component templates
      if (this.config.generateOptions.components) {
        await this.generateComponentTemplates();
      }

      // Step 4: Generate documentation
      if (this.config.generateOptions.documentation) {
        await this.generateDocumentation();
      }

      // Step 5: Setup development environment
      await this.setupDevEnvironment();

      // Step 6: Generate summary report
      await this.generateSummaryReport();

      console.log('\n✅ Template generation completed successfully!');
      return this.results;

    } catch (error) {
      console.error('\n❌ Template generation failed:', error);
      this.results.errors.push(error.message);
      throw error;
    }
  }

  async exportFigmaReferences() {
    console.log('\n🎨 Exporting Figma references...');
    
    try {
      this.results.figmaRefs = await exportHealthDashboardTemplates();
      console.log(`✅ Exported ${this.results.figmaRefs.templates.screens.length} screens and ${this.results.figmaRefs.templates.components.length} components`);
    } catch (error) {
      console.warn('⚠️  Figma export failed, continuing with local templates:', error.message);
      this.results.errors.push(`Figma export: ${error.message}`);
    }
  }

  async generateScreenTemplates() {
    console.log('\n📱 Generating screen templates...');
    
    try {
      this.results.screens = generateAllScreens(this.config.outputDirs.screens);
      console.log(`✅ Generated ${Object.keys(this.results.screens).length} screen templates`);
    } catch (error) {
      console.error('❌ Screen template generation failed:', error);
      this.results.errors.push(`Screen templates: ${error.message}`);
      throw error;
    }
  }

  async generateComponentTemplates() {
    console.log('\n🧩 Generating component templates...');
    
    try {
      this.results.components = generateAllComponents(this.config.outputDirs.components);
      console.log(`✅ Generated ${Object.keys(this.results.components).length} component templates`);
    } catch (error) {
      console.error('❌ Component template generation failed:', error);
      this.results.errors.push(`Component templates: ${error.message}`);
      throw error;
    }
  }

  async generateDocumentation() {
    console.log('\n📚 Generating documentation...');
    
    const docsDir = this.config.outputDirs.docs;
    fs.mkdirSync(docsDir, { recursive: true });

    // Generate README
    const readme = this.generateReadme();
    fs.writeFileSync(path.join(docsDir, 'README.md'), readme);

    // Generate component catalog
    const catalog = this.generateComponentCatalog();
    fs.writeFileSync(path.join(docsDir, 'component-catalog.md'), catalog);

    // Generate screen guide
    const screenGuide = this.generateScreenGuide();
    fs.writeFileSync(path.join(docsDir, 'screen-guide.md'), screenGuide);

    console.log('✅ Generated documentation files');
  }

  async setupDevEnvironment() {
    console.log('\n⚙️  Setting up development environment...');

    // Generate package.json scripts
    const packageScripts = {
      "health:dev": "storybook dev -p 6007",
      "health:build": "npm run build-storybook",
      "health:test": "jest --testMatch='**/*health*/**/*.test.{js,ts,tsx}'",
      "health:test:visual": "playwright test tests/health-dashboard",
      "health:sync": "node tools/figma-mcp/health-dashboard-templates.mjs",
      "health:generate": "node tools/template-generator/generate-all-templates.mjs",
      "health:lint": "eslint apps/health-dashboard/src --ext .ts,.tsx"
    };

    // Create environment config
    const envTemplate = this.generateEnvTemplate();
    fs.writeFileSync('.env.health.example', envTemplate);

    // Generate TypeScript config for health dashboard
    const tsConfig = this.generateTsConfig();
    fs.writeFileSync('apps/health-dashboard/tsconfig.json', JSON.stringify(tsConfig, null, 2));

    console.log('✅ Development environment configured');
  }

  generateReadme() {
    return `# Health Dashboard Templates

> Auto-generated from Figma Health Dashboard UI Kit

## Overview

This package contains **${Object.keys(this.results.screens).length} screen templates** and **${Object.keys(this.results.components).length} component templates** derived from the [Health Dashboard UI Kit](https://www.figma.com/design/${this.config.healthDashboardFileId}).

## Generated Templates

### 🖥️ Screen Templates
${Object.entries(this.results.screens).map(([id, info]) => 
  `- **${id}**: \`${info.path}\``
).join('\n')}

### 🧩 Component Templates  
${Object.entries(this.results.components).map(([id, info]) => 
  `- **${id}**: \`${info.path}\``
).join('\n')}

## Quick Start

\`\`\`bash
# Install dependencies
npm install

# Start Storybook for component development
npm run health:dev

# Run visual regression tests
npm run health:test:visual

# Sync with Figma (requires FIGMA_TOKEN)
npm run health:sync
\`\`\`

## Development Workflow

1. **Make design changes** in Figma Health Dashboard UI Kit
2. **Sync templates**: \`npm run health:sync\`
3. **Update components** as needed
4. **Test visual parity**: \`npm run health:test:visual\` 
5. **Build & deploy**: \`npm run health:build\`

## Template Structure

\`\`\`
apps/health-dashboard/
├── src/
│   ├── screens/           # Page-level templates
│   ├── components/        # Reusable component templates
│   └── utils/             # Shared utilities
├── tests/                 # Visual regression tests
└── stories/               # Storybook stories
\`\`\`

## Code Connect

Each component includes Figma Code Connect specifications for bidirectional sync:

\`\`\`bash
# Publish Code Connect to Figma
npm run code-connect:publish
\`\`\`

---

*Generated on ${new Date().toISOString().split('T')[0]} by Health Dashboard Template Generator*
`;
  }

  generateComponentCatalog() {
    return `# Component Catalog

## Metrics Components

| Component | Variants | Props | Figma |
|-----------|----------|-------|-------|
| KpiCard | default, large, compact | title, value, trend | [View](https://www.figma.com/design/${this.config.healthDashboardFileId}/?node-id=kpi-card) |
| HealthScoreDonut | default, large, minimal | value, total, label | [View](https://www.figma.com/design/${this.config.healthDashboardFileId}/?node-id=health-donut) |
| VitalSignsCard | default, compact, detailed | heartRate, bloodPressure | [View](https://www.figma.com/design/${this.config.healthDashboardFileId}/?node-id=vitals-card) |

## Chart Components

| Component | Variants | Props | Figma |
|-----------|----------|-------|-------|
| HeartRateChart | line, area, minimal | data, timeRange, color | [View](https://www.figma.com/design/${this.config.healthDashboardFileId}/?node-id=heart-chart) |
| BloodPressureChart | default, compact, detailed | data, systolicColor, diastolicColor | [View](https://www.figma.com/design/${this.config.healthDashboardFileId}/?node-id=bp-chart) |
| ActivityBarChart | horizontal, vertical, stacked | data, categories, colors | [View](https://www.figma.com/design/${this.config.healthDashboardFileId}/?node-id=activity-bars) |

## List Components

| Component | Variants | Props | Figma |
|-----------|----------|-------|-------|
| PatientRow | default, compact, detailed | patient, status, priority | [View](https://www.figma.com/design/${this.config.healthDashboardFileId}/?node-id=patient-item) |
| AppointmentCard | default, compact, upcoming | time, patient, type, status | [View](https://www.figma.com/design/${this.config.healthDashboardFileId}/?node-id=appointment-item) |
| LabResultCard | normal, abnormal, critical | testName, result, status | [View](https://www.figma.com/design/${this.config.healthDashboardFileId}/?node-id=lab-card) |

## Usage Examples

\`\`\`tsx
import { KpiCard, HealthScoreDonut } from '@/components/metrics';

export function Dashboard() {
  return (
    <div className="grid grid-cols-4 gap-4">
      <KpiCard 
        title="Total Patients" 
        value={1247} 
        trend="+12%" 
        variant="large"
      />
      <HealthScoreDonut 
        value={75} 
        total={100} 
        label="Health Score"
      />
    </div>
  );
}
\`\`\`
`;
  }

  generateScreenGuide() {
    return `# Screen Templates Guide

## Available Screens

${Object.entries(this.results.screens).map(([id, info]) => `
### ${id}

**Path**: \`${info.path}\`  
**Components**: Multiple integrated components  
**Layout**: Responsive grid system  

\`\`\`tsx
import { ${id.split('-').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join('')} } from '@/screens';

// Usage
<${id.split('-').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join('')} />
\`\`\`
`).join('')}

## Screen Composition

Each screen template includes:

- ✅ **Layout wrapper** with sidebar and header
- ✅ **Responsive grid system** 
- ✅ **Integrated components** from the component library
- ✅ **Mock data structure** for development
- ✅ **Loading and error states**
- ✅ **Storybook stories** for development
- ✅ **Visual regression tests**

## Customization

1. **Override props**: Pass custom data to screen components
2. **Modify layout**: Edit the grid classes in screen templates  
3. **Add components**: Import and use additional components
4. **Update styles**: Customize Tailwind classes

\`\`\`tsx
// Example customization
<MainDashboard 
  data={customHealthData}
  className="custom-dashboard-styles"
/>
\`\`\`
`;
  }

  generateEnvTemplate() {
    return `# Health Dashboard Environment Configuration

# Figma Integration
FIGMA_TOKEN=your-figma-personal-access-token
FIGMA_FILE_ID_HEALTH=${this.config.healthDashboardFileId}

# Development
NODE_ENV=development
STORYBOOK_PORT=6007

# Testing  
PLAYWRIGHT_BROWSERS=chromium,webkit,firefox
VISUAL_REGRESSION_THRESHOLD=0.1

# API Configuration (if needed)
HEALTH_API_BASE_URL=https://api.example.com
HEALTH_API_KEY=your-health-api-key
`;
  }

  generateTsConfig() {
    return {
      "extends": "../../tsconfig.json",
      "compilerOptions": {
        "baseUrl": "src",
        "paths": {
          "@/*": ["*"],
          "@/components/*": ["components/*"],
          "@/screens/*": ["screens/*"],
          "@/utils/*": ["utils/*"]
        }
      },
      "include": [
        "src/**/*",
        "tests/**/*",
        "stories/**/*"
      ],
      "exclude": [
        "node_modules",
        "dist",
        "storybook-static"
      ]
    };
  }

  async generateSummaryReport() {
    console.log('\n📊 Generating summary report...');

    const report = {
      timestamp: new Date().toISOString(),
      figmaFileId: this.config.healthDashboardFileId,
      generated: {
        screens: Object.keys(this.results.screens).length,
        components: Object.keys(this.results.components).length,
        figmaRefs: this.results.figmaRefs ? 'success' : 'failed'
      },
      outputs: {
        screenFiles: Object.values(this.results.screens).reduce((acc, s) => acc + s.files.length, 0),
        componentFiles: Object.values(this.results.components).reduce((acc, c) => acc + c.files.length, 0)
      },
      errors: this.results.errors,
      nextSteps: [
        'Review generated templates in apps/health-dashboard/',
        'Start Storybook: npm run health:dev',
        'Run tests: npm run health:test:visual',
        'Customize components as needed',
        'Deploy to production'
      ]
    };

    fs.writeFileSync(
      path.join(this.config.outputDirs.docs, 'generation-report.json'),
      JSON.stringify(report, null, 2)
    );

    console.log('✅ Summary report saved');
    this.displaySummary(report);
  }

  displaySummary(report) {
    console.log('\n' + '='.repeat(60));
    console.log('📋 GENERATION SUMMARY');
    console.log('='.repeat(60));
    console.log(`🖥️  Screens generated: ${report.generated.screens}`);
    console.log(`🧩 Components generated: ${report.generated.components}`);
    console.log(`📁 Total files created: ${report.outputs.screenFiles + report.outputs.componentFiles}`);
    console.log(`🎨 Figma sync: ${report.generated.figmaRefs}`);
    
    if (report.errors.length > 0) {
      console.log(`⚠️  Errors encountered: ${report.errors.length}`);
      report.errors.forEach(error => console.log(`   - ${error}`));
    }
    
    console.log('\n🚀 Next Steps:');
    report.nextSteps.forEach(step => console.log(`   ${step}`));
    console.log('\n' + '='.repeat(60));
  }
}

// Run if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  const generator = new TemplateGenerator(CONFIG);
  
  generator.generateAll()
    .then(results => {
      console.log('\n🎉 Health Dashboard templates are ready!');
      console.log(`📍 Check apps/health-dashboard/ for generated code`);
      process.exit(0);
    })
    .catch(error => {
      console.error('\n💥 Generation failed:', error);
      process.exit(1);
    });
}

export { TemplateGenerator, CONFIG };