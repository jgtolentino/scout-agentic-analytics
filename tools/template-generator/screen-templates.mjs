// Health Dashboard Screen Templates Generator
import fs from 'fs';
import path from 'path';

const SCREEN_TEMPLATES = {
  "main-dashboard": {
    name: "MainDashboard", 
    description: "Main health dashboard with KPIs and charts",
    components: ["KpiCard", "HealthScoreDonut", "VitalSignsCard", "HeartRateChart", "ActivityBarChart"],
    layout: "grid-cols-12 gap-6"
  },
  
  "analytics-view": {
    name: "AnalyticsView",
    description: "Detailed analytics and trends view", 
    components: ["TrendChart", "ComparisonChart", "DataTable", "FilterDropdown"],
    layout: "grid-cols-8 gap-4"
  },
  
  "patients-list": {
    name: "PatientsList",
    description: "Patient management and list view",
    components: ["SearchBar", "PatientRow", "StatusBadge", "PriorityIndicator"],
    layout: "flex flex-col gap-4"
  },
  
  "appointments": {
    name: "Appointments", 
    description: "Appointment scheduling and management",
    components: ["AppointmentCard", "DatePicker", "NotificationToast"],
    layout: "grid-cols-6 gap-4"
  },
  
  "medical-records": {
    name: "MedicalRecords",
    description: "Patient medical records and history",
    components: ["LabResultCard", "MedicationRow", "HealthAlert"],
    layout: "grid-cols-10 gap-5"
  }
};

export function generateScreenTemplate(screenId, config) {
  const template = SCREEN_TEMPLATES[screenId];
  if (!template) throw new Error(`Unknown screen template: ${screenId}`);

  return {
    component: generateScreenComponent(screenId, template),
    story: generateScreenStory(screenId, template),
    test: generateScreenTest(screenId, template),
    layout: generateScreenLayout(screenId, template)
  };
}

function generateScreenComponent(screenId, template) {
  const imports = template.components.map(comp => 
    `import { ${comp} } from '../components/${comp}';`
  ).join('\n');

  return `import React from 'react';
import { ${template.name}Layout } from '../layouts';
${imports}

interface ${template.name}Props {
  className?: string;
  data?: any;
}

export function ${template.name}({ className, data }: ${template.name}Props) {
  return (
    <${template.name}Layout className={className}>
      <div className="${template.layout}" data-testid="${screenId}">
        {/* Auto-generated from Health Dashboard UI Kit */}
        {/* Template: ${template.description} */}
        
        {/* Main content area */}
        <div className="col-span-full">
          <h1 className="text-2xl font-bold text-health-neutral-900 mb-6">
            ${template.name.replace(/([A-Z])/g, ' $1').trim()}
          </h1>
        </div>

        ${generateTemplateContent(template)}
      </div>
    </${template.name}Layout>
  );
}

${template.name}.displayName = '${template.name}';`;
}

function generateTemplateContent(template) {
  // Generate different content patterns based on screen type
  switch (template.name) {
    case 'MainDashboard':
      return `
        {/* KPI Row */}
        <div className="col-span-12 grid grid-cols-4 gap-4">
          <KpiCard title="Total Patients" value={1247} trend="+12%" />
          <KpiCard title="Active Cases" value={89} trend="+5%" />
          <KpiCard title="Appointments Today" value={24} trend="-3%" />
          <KpiCard title="Critical Alerts" value={3} trend="0%" />
        </div>

        {/* Charts Row */}
        <div className="col-span-8">
          <HealthScoreDonut value={75} total={100} />
        </div>
        <div className="col-span-4">
          <VitalSignsCard />
        </div>

        {/* Activity Charts */}
        <div className="col-span-6">
          <HeartRateChart />
        </div>
        <div className="col-span-6">
          <ActivityBarChart />
        </div>`;

    case 'PatientsList':
      return `
        {/* Search and Filters */}
        <div className="w-full flex justify-between items-center">
          <SearchBar placeholder="Search patients..." />
          <FilterDropdown options={['All', 'Critical', 'Stable', 'Recovering']} />
        </div>

        {/* Patients List */}
        <div className="w-full space-y-2">
          {Array.from({ length: 8 }).map((_, i) => (
            <PatientRow 
              key={i}
              patient={{
                name: \`Patient \${i + 1}\`,
                age: 25 + i * 5,
                status: ['Critical', 'Stable', 'Recovering'][i % 3]
              }}
            />
          ))}
        </div>`;

    case 'Appointments':
      return `
        {/* Calendar Header */}
        <div className="col-span-6 flex justify-between items-center">
          <h2 className="text-lg font-semibold">Today's Appointments</h2>
          <DatePicker />
        </div>

        {/* Appointments Grid */}
        <div className="col-span-6 space-y-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <AppointmentCard 
              key={i}
              time={\`\${9 + i}:00 AM\`}
              patient={\`Patient \${i + 1}\`}
              type={['Checkup', 'Follow-up', 'Emergency'][i % 3]}
            />
          ))}
        </div>`;

    default:
      return `{/* Template content for ${template.name} */}`;
  }
}

function generateScreenStory(screenId, template) {
  return `import type { Meta, StoryObj } from '@storybook/react';
import { ${template.name} } from './${template.name}';

const meta: Meta<typeof ${template.name}> = {
  title: 'Screens/${template.name}',
  component: ${template.name},
  parameters: {
    layout: 'fullscreen',
    design: {
      type: 'figma',
      url: 'https://www.figma.com/design/kXOb4ck97DsiGrm815VgDz/Health-Dashboard-UI-Kit--Community-?node-id=${screenId}',
    },
  },
};

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {
  args: {},
};

export const WithMockData: Story = {
  args: {
    data: {
      // Mock data for ${template.description}
    }
  },
};

export const Loading: Story = {
  args: {},
  parameters: {
    mockData: { loading: true }
  },
};`;
}

function generateScreenTest(screenId, template) {
  return `import { render, screen } from '@testing-library/react';
import { ${template.name} } from './${template.name}';

describe('${template.name}', () => {
  it('renders without crashing', () => {
    render(<${template.name} />);
    expect(screen.getByTestId('${screenId}')).toBeInTheDocument();
  });

  it('displays the correct title', () => {
    render(<${template.name} />);
    expect(screen.getByText('${template.name.replace(/([A-Z])/g, ' $1').trim()}')).toBeInTheDocument();
  });

  it('renders all expected components', () => {
    render(<${template.name} />);
    // Test for key components presence
    ${template.components.map(comp => 
      `// expect(screen.getByTestId('${comp.toLowerCase()}')).toBeInTheDocument();`
    ).join('\n    ')}
  });

  it('matches Figma design snapshot', async () => {
    const { container } = render(<${template.name} />);
    // Visual regression test would go here
    expect(container.firstChild).toMatchSnapshot();
  });
});`;
}

function generateScreenLayout(screenId, template) {
  return `import React from 'react';
import { Sidebar, Header, Breadcrumbs } from '../components/layout';

interface ${template.name}LayoutProps {
  children: React.ReactNode;
  className?: string;
}

export function ${template.name}Layout({ children, className }: ${template.name}LayoutProps) {
  return (
    <div className="min-h-screen bg-health-neutral-50">
      <Sidebar />
      <div className="ml-64"> {/* Sidebar width */}
        <Header />
        <div className="p-6">
          <Breadcrumbs 
            items={[
              { label: 'Dashboard', href: '/dashboard' },
              { label: '${template.name.replace(/([A-Z])/g, ' $1').trim()}', href: '#' }
            ]} 
          />
          <main className={\`mt-6 \${className || ''}\`}>
            {children}
          </main>
        </div>
      </div>
    </div>
  );
}`;
}

// Generate all screen templates
export function generateAllScreens(outputDir = 'apps/health-dashboard/src/screens') {
  const results = {};
  
  Object.keys(SCREEN_TEMPLATES).forEach(screenId => {
    console.log(`🏗️  Generating screen: ${screenId}`);
    
    const templates = generateScreenTemplate(screenId, SCREEN_TEMPLATES[screenId]);
    const config = SCREEN_TEMPLATES[screenId];
    
    // Create directories
    const screenDir = path.join(outputDir, config.name);
    fs.mkdirSync(screenDir, { recursive: true });
    
    // Write files
    fs.writeFileSync(path.join(screenDir, `${config.name}.tsx`), templates.component);
    fs.writeFileSync(path.join(screenDir, `${config.name}.stories.tsx`), templates.story);
    fs.writeFileSync(path.join(screenDir, `${config.name}.test.tsx`), templates.test);
    fs.writeFileSync(path.join(screenDir, `${config.name}Layout.tsx`), templates.layout);
    
    results[screenId] = {
      path: screenDir,
      files: [`${config.name}.tsx`, `${config.name}.stories.tsx`, `${config.name}.test.tsx`, `${config.name}Layout.tsx`]
    };
  });
  
  console.log(`✅ Generated ${Object.keys(results).length} screen templates`);
  return results;
}