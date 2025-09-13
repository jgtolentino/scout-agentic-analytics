// Health Dashboard Component Templates Generator
import fs from 'fs';
import path from 'path';

const COMPONENT_TEMPLATES = {
  // KPI & Metrics Components
  "kpi-card": {
    name: "KpiCard",
    category: "metrics",
    props: ["title", "value", "trend", "trendDirection", "icon", "size"],
    variants: ["default", "large", "compact"],
    figmaNodeId: "kpi-card"
  },
  
  "health-score-donut": {
    name: "HealthScoreDonut", 
    category: "metrics",
    props: ["value", "total", "label", "color", "size", "showPercentage"],
    variants: ["default", "large", "minimal"],
    figmaNodeId: "health-donut"
  },
  
  "vital-signs-card": {
    name: "VitalSignsCard",
    category: "metrics", 
    props: ["heartRate", "bloodPressure", "temperature", "oxygenLevel"],
    variants: ["default", "compact", "detailed"],
    figmaNodeId: "vitals-card"
  },

  // Chart Components
  "heart-rate-chart": {
    name: "HeartRateChart",
    category: "charts",
    props: ["data", "timeRange", "showGrid", "color", "height"],
    variants: ["line", "area", "minimal"],
    figmaNodeId: "heart-chart"
  },
  
  "blood-pressure-chart": {
    name: "BloodPressureChart", 
    category: "charts",
    props: ["data", "systolicColor", "diastolicColor", "showTargetRange"],
    variants: ["default", "compact", "detailed"],
    figmaNodeId: "bp-chart"
  },
  
  "activity-bar-chart": {
    name: "ActivityBarChart",
    category: "charts", 
    props: ["data", "categories", "colors", "stacked", "showLegend"],
    variants: ["horizontal", "vertical", "stacked"],
    figmaNodeId: "activity-bars"
  },

  // List & Table Components
  "patient-row": {
    name: "PatientRow",
    category: "lists",
    props: ["patient", "status", "lastVisit", "priority", "onSelect"],
    variants: ["default", "compact", "detailed"],
    figmaNodeId: "patient-item"
  },
  
  "appointment-card": {
    name: "AppointmentCard",
    category: "cards", 
    props: ["time", "patient", "type", "status", "doctor", "onEdit"],
    variants: ["default", "compact", "upcoming"],
    figmaNodeId: "appointment-item"
  },
  
  "lab-result-card": {
    name: "LabResultCard",
    category: "cards",
    props: ["testName", "result", "normalRange", "status", "date"],
    variants: ["normal", "abnormal", "critical"],
    figmaNodeId: "lab-card"
  },

  // Navigation & Layout
  "sidebar-nav": {
    name: "SidebarNav", 
    category: "navigation",
    props: ["items", "activeItem", "collapsed", "onItemSelect"],
    variants: ["default", "collapsed", "mobile"],
    figmaNodeId: "sidebar"
  },
  
  "breadcrumbs": {
    name: "Breadcrumbs",
    category: "navigation",
    props: ["items", "separator", "maxItems"],
    variants: ["default", "compact", "dropdown"],
    figmaNodeId: "breadcrumb"
  },

  // Form & Input Components
  "search-bar": {
    name: "SearchBar",
    category: "forms",
    props: ["placeholder", "value", "onSearch", "suggestions", "size"],
    variants: ["default", "compact", "with-filters"],
    figmaNodeId: "search"
  },
  
  "date-picker": {
    name: "DatePicker", 
    category: "forms",
    props: ["value", "onChange", "minDate", "maxDate", "format"],
    variants: ["single", "range", "compact"],
    figmaNodeId: "date-picker"
  },

  // Status & Feedback
  "status-badge": {
    name: "StatusBadge",
    category: "feedback",
    props: ["status", "variant", "size", "icon"],
    variants: ["critical", "stable", "recovering", "normal"],
    figmaNodeId: "status-badge"
  },
  
  "health-alert": {
    name: "HealthAlert",
    category: "feedback", 
    props: ["type", "message", "actionable", "onDismiss", "onAction"],
    variants: ["info", "warning", "error", "success"],
    figmaNodeId: "alert"
  },
  
  "notification-toast": {
    name: "NotificationToast",
    category: "feedback",
    props: ["message", "type", "duration", "position", "onClose"],
    variants: ["success", "error", "warning", "info"],
    figmaNodeId: "toast"
  }
};

export function generateComponentTemplate(componentId, config) {
  const template = COMPONENT_TEMPLATES[componentId];
  if (!template) throw new Error(`Unknown component template: ${componentId}`);

  return {
    component: generateReactComponent(componentId, template),
    story: generateStorybook(componentId, template),
    test: generateTests(componentId, template),
    codeConnect: generateCodeConnect(componentId, template),
    types: generateTypeDefinitions(componentId, template)
  };
}

function generateReactComponent(componentId, template) {
  const propsInterface = generatePropsInterface(template);
  const componentLogic = generateComponentLogic(template);
  
  return `import React from 'react';
import { cn } from '../../utils/cn';
${generateImports(template)}

${propsInterface}

export function ${template.name}({ 
  ${template.props.join(',\n  ')},
  className,
  ...props 
}: ${template.name}Props) {
  ${componentLogic}

  return (
    <div 
      className={cn(
        'health-${componentId}',
        getVariantClasses(variant),
        className
      )}
      data-testid="${componentId}"
      {...props}
    >
      ${generateJSXContent(template)}
    </div>
  );
}

${generateHelperFunctions(template)}

${template.name}.displayName = '${template.name}';`;
}

function generatePropsInterface(template) {
  const propTypes = {
    title: 'string',
    value: 'number',
    data: 'any[]',
    status: `'${template.variants?.join("' | '") || 'string'}'`,
    size: "'sm' | 'md' | 'lg'",
    color: 'string',
    onClick: '() => void',
    onChange: '(value: any) => void'
  };

  const props = template.props.map(prop => {
    const type = propTypes[prop] || 'any';
    const optional = ['className', 'onClick', 'onChange', 'onSelect'].includes(prop) ? '?' : '';
    return `  ${prop}${optional}: ${type};`;
  }).join('\n');

  return `interface ${template.name}Props {
${props}
  variant?: '${template.variants.join("' | '")}';
  className?: string;
}`;
}

function generateComponentLogic(template) {
  switch (template.category) {
    case 'metrics':
      return `
  // Calculate percentage for metrics
  const percentage = typeof value === 'number' && typeof total === 'number' 
    ? Math.round((value / total) * 100) 
    : 0;
  
  // Determine status color
  const statusColor = percentage >= 80 ? 'text-health-success' : 
                     percentage >= 60 ? 'text-health-warning' : 
                     'text-health-danger';`;

    case 'charts':
      return `
  // Process chart data
  const processedData = React.useMemo(() => {
    return Array.isArray(data) ? data : [];
  }, [data]);
  
  // Chart dimensions
  const chartHeight = height || 200;`;

    case 'forms':
      return `
  // Form state management
  const [internalValue, setInternalValue] = React.useState(value || '');
  
  const handleChange = (newValue: any) => {
    setInternalValue(newValue);
    onChange?.(newValue);
  };`;

    default:
      return '// Component logic';
  }
}

function generateJSXContent(template) {
  switch (template.category) {
    case 'metrics':
      return `
      <div className="flex items-center justify-between p-4">
        <div>
          <h3 className="text-sm font-medium text-health-neutral-600">{title}</h3>
          <p className="text-2xl font-bold text-health-neutral-900">{value}</p>
          {trend && (
            <span className={cn('text-xs', statusColor)}>
              {trend}
            </span>
          )}
        </div>
        {icon && (
          <div className="text-health-primary">
            {icon}
          </div>
        )}
      </div>`;

    case 'charts':
      return `
      <div className="p-4">
        <svg width="100%" height={chartHeight} className="overflow-visible">
          {/* Chart content based on processedData */}
        </svg>
      </div>`;

    case 'lists':
      return `
      <div className="flex items-center justify-between p-3 hover:bg-health-neutral-50 transition-colors">
        <div className="flex items-center space-x-3">
          <div className="flex-1">
            {/* List item content */}
          </div>
        </div>
        <div className="flex items-center space-x-2">
          {/* Actions */}
        </div>
      </div>`;

    default:
      return `{/* ${template.name} content */}`;
  }
}

function generateHelperFunctions(template) {
  return `
function getVariantClasses(variant: string) {
  const variants = {
    ${template.variants.map(v => `'${v}': 'health-${template.name.toLowerCase()}-${v}'`).join(',\n    ')}
  };
  return variants[variant] || variants.default;
}`;
}

function generateStorybook(componentId, template) {
  return `import type { Meta, StoryObj } from '@storybook/react';
import { ${template.name} } from './${template.name}';

const meta: Meta<typeof ${template.name}> = {
  title: '${template.category}/${template.name}',
  component: ${template.name},
  parameters: {
    layout: 'centered',
    design: {
      type: 'figma',
      url: 'https://www.figma.com/design/kXOb4ck97DsiGrm815VgDz/Health-Dashboard-UI-Kit--Community-?node-id=${template.figmaNodeId}&m=dev',
    },
  },
  argTypes: {
    variant: {
      control: { type: 'select' },
      options: [${template.variants.map(v => `'${v}'`).join(', ')}],
    },
  },
};

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {
  args: {
    ${generateStoryArgs(template)}
  },
};

${template.variants.map(variant => `
export const ${variant.charAt(0).toUpperCase() + variant.slice(1)}: Story = {
  args: {
    ...Default.args,
    variant: '${variant}',
  },
};`).join('')}

export const Interactive: Story = {
  args: {
    ...Default.args,
  },
  play: async ({ canvasElement }) => {
    // Interaction tests
  },
};`;
}

function generateStoryArgs(template) {
  const argDefaults = {
    title: `'${template.name} Title'`,
    value: '75',
    total: '100', 
    data: '[{ label: "Sample", value: 10 }]',
    status: `'${template.variants[0]}'`,
    variant: `'default'`
  };

  return template.props
    .filter(prop => argDefaults[prop])
    .map(prop => `${prop}: ${argDefaults[prop]}`)
    .join(',\n    ');
}

function generateTests(componentId, template) {
  return `import { render, screen, fireEvent } from '@testing-library/react';
import { ${template.name} } from './${template.name}';

const defaultProps = {
  ${generateTestProps(template)}
};

describe('${template.name}', () => {
  it('renders without crashing', () => {
    render(<${template.name} {...defaultProps} />);
    expect(screen.getByTestId('${componentId}')).toBeInTheDocument();
  });

  it('applies correct variant classes', () => {
    ${template.variants.map(variant => `
    const { rerender } = render(<${template.name} {...defaultProps} variant="${variant}" />);
    expect(screen.getByTestId('${componentId}')).toHaveClass('health-${template.name.toLowerCase()}-${variant}');`).join('')}
  });

  ${generateCategorySpecificTests(template, componentId)}

  it('matches Figma design snapshot', () => {
    const { container } = render(<${template.name} {...defaultProps} />);
    expect(container.firstChild).toMatchSnapshot();
  });
});`;
}

function generateTestProps(template) {
  const testDefaults = {
    title: "'Test Title'",
    value: '42',
    data: '[{ x: 1, y: 2 }]',
    status: `'${template.variants[0]}'`,
  };

  return template.props
    .filter(prop => testDefaults[prop])
    .map(prop => `${prop}: ${testDefaults[prop]}`)
    .join(',\n  ');
}

function generateCategorySpecificTests(template, componentId) {
  switch (template.category) {
    case 'forms':
      return `
  it('handles user input correctly', () => {
    const mockOnChange = jest.fn();
    render(<${template.name} {...defaultProps} onChange={mockOnChange} />);
    
    const input = screen.getByTestId('${componentId}');
    fireEvent.change(input, { target: { value: 'test input' } });
    
    expect(mockOnChange).toHaveBeenCalledWith('test input');
  });`;
    
    case 'charts':
      return `
  it('renders chart data correctly', () => {
    const testData = [{ x: 1, y: 10 }, { x: 2, y: 20 }];
    render(<${template.name} {...defaultProps} data={testData} />);
    
    // Test chart rendering
    expect(screen.getByTestId('${componentId}')).toContainElement(
      screen.getByRole('img') // SVG chart
    );
  });`;

    default:
      return `
  it('handles click events', () => {
    const mockOnClick = jest.fn();
    render(<${template.name} {...defaultProps} onClick={mockOnClick} />);
    
    fireEvent.click(screen.getByTestId('${componentId}'));
    expect(mockOnClick).toHaveBeenCalled();
  });`;
  }
}

function generateCodeConnect(componentId, template) {
  return `import { figma, html } from "@figma/code-connect";
import { ${template.name} } from "./${template.name}";

figma.connect(${template.name}, "https://www.figma.com/design/kXOb4ck97DsiGrm815VgDz/Health-Dashboard-UI-Kit--Community-?node-id=${template.figmaNodeId}", {
  props: {
    ${template.props.map(prop => generateFigmaPropMapping(prop)).join(',\n    ')}
  },
  example: ({ ${template.props.join(', ')} }) => html\`
    <${template.name}
      ${template.props.map(prop => `${prop}={\${${prop}}}`).join('\n      ')}
      data-testid="${componentId}"
    />
  \`
});`;
}

function generateFigmaPropMapping(prop) {
  const mappings = {
    title: 'figma.textContent("Title")',
    value: 'figma.textContent("Value")', 
    status: 'figma.enum("Status", { "Critical": "critical", "Stable": "stable" })',
    variant: 'figma.enum("Variant", { "Default": "default", "Large": "large" })',
    color: 'figma.string("Color")'
  };
  
  return `${prop}: ${mappings[prop] || `figma.string("${prop.charAt(0).toUpperCase() + prop.slice(1)}")`}`;
}

// Generate all components
export function generateAllComponents(outputDir = 'apps/health-dashboard/src/components') {
  const results = {};
  
  Object.keys(COMPONENT_TEMPLATES).forEach(componentId => {
    console.log(`🧩 Generating component: ${componentId}`);
    
    const templates = generateComponentTemplate(componentId, COMPONENT_TEMPLATES[componentId]);
    const config = COMPONENT_TEMPLATES[componentId];
    
    // Create directories  
    const componentDir = path.join(outputDir, config.category, config.name);
    fs.mkdirSync(componentDir, { recursive: true });
    
    // Write files
    fs.writeFileSync(path.join(componentDir, `${config.name}.tsx`), templates.component);
    fs.writeFileSync(path.join(componentDir, `${config.name}.stories.tsx`), templates.story);
    fs.writeFileSync(path.join(componentDir, `${config.name}.test.tsx`), templates.test);
    fs.writeFileSync(path.join(componentDir, `${config.name}.connect.ts`), templates.codeConnect);
    
    results[componentId] = {
      path: componentDir,
      files: [`${config.name}.tsx`, `${config.name}.stories.tsx`, `${config.name}.test.tsx`, `${config.name}.connect.ts`]
    };
  });
  
  console.log(`✅ Generated ${Object.keys(results).length} component templates`);
  return results;
}

function generateImports(template) {
  // Generate necessary imports based on component category
  const imports = [];
  
  if (template.category === 'charts') {
    imports.push("import { ResponsiveContainer, LineChart, Line, XAxis, YAxis } from 'recharts';");
  }
  
  if (template.category === 'forms') {
    imports.push("import { useCallback } from 'react';");
  }
  
  return imports.join('\n');
}

function generateTypeDefinitions(componentId, template) {
  return `// Type definitions for ${template.name}
export interface ${template.name}Props {
  ${template.props.map(prop => {
    const type = getTypeForProp(prop);
    return `${prop}?: ${type};`;
  }).join('\n  ')}
  variant?: '${template.variants.join("' | '")}';
  className?: string;
}

export type ${template.name}Variant = '${template.variants.join("' | '")}';`;
}

function getTypeForProp(prop) {
  const types = {
    title: 'string',
    value: 'number',
    data: 'any[]',
    onClick: '() => void',
    onChange: '(value: any) => void',
    status: 'string',
    color: 'string'
  };
  
  return types[prop] || 'any';
}