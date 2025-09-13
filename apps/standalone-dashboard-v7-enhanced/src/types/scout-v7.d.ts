/**
 * Scout v7 JSON-driven dashboard configuration types
 * Generated from scout.v7.json contract
 */

// Core Configuration Types
export interface ScoutV7Config {
  meta: MetaInfo;
  theme: ThemeConfig;
  navigation: NavigationConfig;
  pages: Record<string, PageConfig>;
  widgets: Record<string, WidgetConfig>;
  dataSources: DataSourcesConfig;
  filters: Record<string, FilterConfig>;
  roles: Record<string, RoleConfig>;
  featureFlags: Record<string, FeatureFlagConfig>;
}

// Meta Information
export interface MetaInfo {
  name: string;
  version: string;
  description: string;
  updated: string;
}

// Theme Configuration
export interface ThemeConfig {
  colors: {
    primary: string;
    secondary: string;
    accent: string;
    success: string;
    warning: string;
    danger: string;
    background: string;
    surface: string;
    text: string;
    muted: string;
  };
  typography: {
    fontFamily: string;
    sizes: {
      xs: string;
      sm: string;
      base: string;
      lg: string;
      xl: string;
      '2xl': string;
      '3xl': string;
    };
  };
  spacing: {
    xs: string;
    sm: string;
    md: string;
    lg: string;
    xl: string;
    '2xl': string;
  };
  borderRadius: {
    sm: string;
    md: string;
    lg: string;
  };
}

// Navigation Configuration
export interface NavigationConfig {
  primary: NavItem[];
  user: NavItem[];
}

export interface NavItem {
  id: string;
  label: string;
  icon: string;
  href?: string;
  action?: string;
  requiredRole?: RoleName;
}

// Page Configuration
export interface PageConfig {
  title: string;
  description: string;
  layout: 'grid' | 'split';
  requiredRole: RoleName;
  featureFlag?: string;
  sections: SectionConfig[];
}

export interface SectionConfig {
  id: string;
  title?: string;
  type?: SectionType;
  grid?: string;
  span?: string | number;
  filters?: FilterType[];
  controls?: string[];
  dataSource?: string;
  widgets?: WidgetInstance[];
  maxSelections?: number;
  formats?: string[];
  actions?: string[];
  realtime?: boolean;
}

export type SectionType = 
  | 'filter-bar' 
  | 'multi-select' 
  | 'control-panel' 
  | 'template-gallery'
  | 'table'
  | 'export-panel'
  | 'status-grid'
  | 'config-panel'
  | 'log-viewer'
  | 'ai-chat'
  | 'choropleth-map'
  | 'region-selector';

// Widget Configuration
export interface WidgetConfig {
  component: string;
  props: string[];
  realtime?: boolean;
}

export interface WidgetInstance {
  type: WidgetType;
  title: string;
  dataSource: string;
  span?: number;
  format?: DataFormat;
  showTrend?: boolean;
  orientation?: 'horizontal' | 'vertical';
  stacked?: boolean;
  colorScale?: string;
  autoScroll?: boolean;
  xAxis?: string;
  yAxis?: string;
  series?: string[];
  axes?: string[];
  size?: string;
  color?: string;
  categories?: string[];
  sortable?: boolean;
  paginated?: boolean;
  threshold?: number;
  quadrants?: string[];
  endpoint?: string;
  context?: string;
  historical?: string;
  forecast?: string;
  confidence?: string;
}

export type WidgetType = 
  | 'scorecard'
  | 'line-chart'
  | 'bar-chart'
  | 'heat-map'
  | 'agent-feed'
  | 'combo-chart'
  | 'sankey'
  | 'scatter-plot'
  | 'treemap'
  | 'table'
  | 'radar-chart'
  | 'stacked-bar'
  | 'bubble-chart'
  | 'competitive-table'
  | 'choropleth-map'
  | 'pareto-chart'
  | 'matrix-chart'
  | 'waterfall-chart'
  | 'forecast-chart'
  | 'ai-chat'
  | 'scorecard-list'
  | 'histogram'
  | 'correlation-matrix'
  | 'scenario-analysis'
  | 'anomaly-detection'
  | 'action-cards';

export type DataFormat = 'currency' | 'number' | 'percentage';

// Data Source Configuration
export interface DataSourcesConfig {
  rpc: Record<string, RPCEndpoint>;
  edge: Record<string, EdgeFunction>;
  sse: Record<string, SSEEndpoint>;
}

export interface RPCEndpoint {
  endpoint: string;
  method: 'GET' | 'POST' | 'PUT' | 'DELETE';
  cache: number; // seconds
}

export interface EdgeFunction {
  function: string;
  region: string;
}

export interface SSEEndpoint {
  endpoint: string;
  reconnect: boolean;
}

// Filter Configuration
export interface FilterConfig {
  type: FilterType;
  default?: string;
  options?: string[] | FilterOption[];
  dataSource?: string;
  multiple?: boolean;
  min?: number;
  max?: number;
  step?: number;
}

export interface FilterOption {
  value: string;
  label: string;
}

export type FilterType = 
  | 'date-range' 
  | 'select' 
  | 'range'
  | 'multi-select'
  | 'region-selector'
  | 'category'
  | 'brand'
  | 'priceRange'
  | 'inventory';

// Role Configuration
export interface RoleConfig {
  permissions: Permission[];
  pages: string[];
}

export type RoleName = 'viewer' | 'analyst' | 'admin';
export type Permission = 'view' | 'export' | 'analyze' | 'forecast' | 'configure' | 'manage';

// Feature Flag Configuration
export interface FeatureFlagConfig {
  enabled: boolean;
  rollout: number; // percentage
}

// Runtime Types for Data Handling
export interface ChartDataPoint {
  [key: string]: string | number | boolean | null | undefined;
}

export interface ScoreCardData {
  title: string;
  value: string | number;
  delta?: number;
  format?: DataFormat;
  trend?: 'up' | 'down' | 'neutral';
}

export interface AgentFeedItem {
  id: string;
  severity: 'critical' | 'warning' | 'info';
  source: 'monitor' | 'contract' | 'manual';
  title: string;
  description?: string;
  timestamp: string;
  actions?: AgentAction[];
}

export interface AgentAction {
  id: string;
  label: string;
  requiresApproval: boolean;
  policyGated: boolean;
}

export interface ChatMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: string;
  metadata?: Record<string, any>;
}

export interface GeoDataPoint {
  region: string;
  revenuePhp: number;
  growthPct?: number | null;
  ourSharePct?: number | null;
  topCompetitor?: string | null;
  topCompSharePct?: number | null;
  deltaPct?: number | null;
}

// API Response Types
export interface APIResponse<T = any> {
  success: boolean;
  data?: T;
  error?: string;
  timestamp?: string;
}

export interface KPIResponse {
  revenue_mtd?: number;
  active_stores?: number;
  market_share?: number;
  ai_insights_count?: number;
  revenue_growth_mom?: number;
}

// Component Props Types
export interface ScoreCardProps {
  title: string;
  value: string | number;
  delta?: number;
  format?: DataFormat;
  showTrend?: boolean;
  isLoading?: boolean;
  hint?: string;
}

export interface ChartProps {
  title: string;
  data: ChartDataPoint[];
  isLoading?: boolean;
  className?: string;
  height?: number;
}

export interface AgentFeedProps {
  title: string;
  items: AgentFeedItem[];
  autoScroll?: boolean;
  maxItems?: number;
}

export interface FilterDrawerProps {
  isOpen: boolean;
  onClose: () => void;
  filters?: Record<string, any>;
  onFiltersChange?: (filters: Record<string, any>) => void;
}

// Utility Types
export type DeepPartial<T> = {
  [P in keyof T]?: T[P] extends object ? DeepPartial<T[P]> : T[P];
};

export type RequiredKeys<T, K extends keyof T> = T & Required<Pick<T, K>>;

// Context Types for React
export interface ScoutV7ContextValue {
  config: ScoutV7Config;
  currentUser: {
    role: RoleName;
    permissions: Permission[];
  };
  theme: ThemeConfig;
  isFeatureEnabled: (flag: string) => boolean;
  hasPermission: (permission: Permission) => boolean;
  canAccessPage: (pageId: string) => boolean;
}

export interface FilterContextValue {
  filters: Record<string, any>;
  setFilter: (key: string, value: any) => void;
  clearFilters: () => void;
  isFilterActive: boolean;
  getFilterQuery: () => Record<string, any>;
}

// Hook Return Types
export interface UseScoutDataResult<T = any> {
  data: T | undefined;
  isLoading: boolean;
  error: Error | null;
  refetch: () => void;
}

export interface UseRealTimeResult<T = any> {
  data: T[];
  isConnected: boolean;
  error: Error | null;
  reconnect: () => void;
}

// JSON-driven Page Renderer Types
export interface PageRendererProps {
  pageConfig: PageConfig;
  userRole: RoleName;
  filters?: Record<string, any>;
}

export interface SectionRendererProps {
  section: SectionConfig;
  userRole: RoleName;
  filters?: Record<string, any>;
}

export interface WidgetRendererProps {
  widget: WidgetInstance;
  config: WidgetConfig;
  data?: any;
  isLoading?: boolean;
  error?: Error | null;
}

// Data fetching types
export interface DataFetcher {
  rpc: (endpoint: string, params?: Record<string, any>) => Promise<any>;
  edge: (functionName: string, params?: Record<string, any>) => Promise<any>;
  sse: (endpoint: string, callback: (data: any) => void) => () => void; // Returns cleanup function
}

// Amazon Theme Integration
export interface AmazonThemeTokens {
  colors: {
    amazonOrange: string;
    amazonBlue: string;
    amazonGray: string;
    amazonSuccess: string;
    amazonWarning: string;
    amazonError: string;
  };
  components: {
    button: {
      primary: string;
      secondary: string;
      danger: string;
    };
    card: {
      background: string;
      border: string;
      shadow: string;
    };
    navigation: {
      background: string;
      text: string;
      hover: string;
    };
  };
}

// Reshaped Integration Types
export interface ReshapedThemeConfig {
  name: string;
  tokens: {
    color: Record<string, string>;
    typography: Record<string, string>;
    spacing: Record<string, string>;
    radius: Record<string, string>;
  };
}

// Export default type for the main configuration
export default ScoutV7Config;