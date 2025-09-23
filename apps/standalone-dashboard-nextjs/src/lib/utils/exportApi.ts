/**
 * Scout Analytics Export API Utilities
 * Client-side helpers for interacting with the export API
 */

export interface ExportResponse {
  ok: boolean;
  type: string;
  sql?: string;
  filename?: string;
  mode?: 'resolve' | 'delegate';
  runner_command?: string;
  error?: string;
  delegated?: boolean;
  bruno?: any;
}

export interface CustomExportRequest {
  sql: string;
  filename?: string;
  description?: string;
}

export interface ExportValidationError {
  ok: false;
  error: string;
  validation: {
    passed: false;
    error: string;
  };
  help?: {
    allowed_tables: string[];
    allowed_functions: string[];
    max_length: number;
    max_top: number;
    example: string;
  };
}

/**
 * Get list of available export types
 */
export async function getAvailableExports(): Promise<{
  ok: boolean;
  available_exports: Array<{
    type: string;
    redact: boolean;
    description: string;
  }>;
}> {
  const response = await fetch('/api/export/list');
  return response.json();
}

/**
 * Execute a predefined export
 */
export async function executePreDefinedExport(
  type: string,
  options: Record<string, any> = {}
): Promise<ExportResponse> {
  const response = await fetch(`/api/export/${type}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(options)
  });

  return response.json();
}

/**
 * Execute a custom SQL export with validation
 */
export async function executeCustomExport(
  request: CustomExportRequest
): Promise<ExportResponse | ExportValidationError> {
  const response = await fetch('/api/export/custom', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(request)
  });

  return response.json();
}

/**
 * Get validation rules for custom exports
 */
export async function getCustomExportRules(): Promise<{
  ok: boolean;
  validation_rules: {
    max_length: number;
    max_top_value: number;
    allowed_tables: string[];
    allowed_functions: string[];
    required_start: string;
    prohibited_keywords: string[];
  };
  example_request: CustomExportRequest;
}> {
  const response = await fetch('/api/export/custom');
  return response.json();
}

/**
 * Validate SQL before submitting (client-side basic checks)
 */
export function validateSqlBasic(sql: string): {
  valid: boolean;
  errors: string[];
  warnings: string[];
} {
  const errors: string[] = [];
  const warnings: string[] = [];

  // Basic checks
  if (!sql.trim()) {
    errors.push('SQL query cannot be empty');
  }

  if (sql.length > 5000) {
    errors.push('SQL query exceeds maximum length of 5000 characters');
  }

  if (!sql.trim().toUpperCase().startsWith('SELECT')) {
    errors.push('Query must start with SELECT');
  }

  // Check for dangerous keywords
  const dangerous = /(;|--|\/\*|\bDROP\b|\bALTER\b|\bINSERT\b|\bUPDATE\b|\bDELETE\b|\bMERGE\b|\bEXEC\b)/i;
  if (dangerous.test(sql)) {
    errors.push('Query contains prohibited keywords or patterns');
  }

  // Check for required tables
  const allowedTables = [
    'gold.v_transactions_flat',
    'gold.v_transactions_crosstab',
    'gold.v_pbi_transactions_summary',
    'gold.v_pbi_brand_performance'
  ];

  const hasAllowedTable = allowedTables.some(table => sql.includes(table));
  if (!hasAllowedTable) {
    errors.push('Query must reference at least one allowed table');
  }

  // Check TOP clause
  const topMatch = sql.match(/\bTOP\s*\(\s*(\d+)\s*\)/i);
  if (topMatch) {
    const topValue = parseInt(topMatch[1]);
    if (topValue > 10000) {
      errors.push('TOP value cannot exceed 10,000');
    }
    if (topValue > 1000) {
      warnings.push('Large TOP values may impact performance');
    }
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings
  };
}

/**
 * Format export command for display
 */
export function formatExportCommand(command: string): {
  command: string;
  description: string;
  estimatedTime: string;
} {
  // Parse command to provide helpful context
  const isCustom = command.includes('custom');
  const hasTop = /TOP\s*\(\s*(\d+)\s*\)/i.test(command);
  const topMatch = command.match(/TOP\s*\(\s*(\d+)\s*\)/i);
  const recordCount = topMatch ? parseInt(topMatch[1]) : 'all';

  let estimatedTime = '< 30 seconds';
  let description = 'Standard export';

  if (isCustom) {
    description = 'Custom SQL export';
    if (typeof recordCount === 'number') {
      if (recordCount > 5000) {
        estimatedTime = '1-2 minutes';
      } else if (recordCount > 1000) {
        estimatedTime = '30-60 seconds';
      }
    }
  } else {
    if (command.includes('crosstab')) {
      description = 'Dimensional analysis export';
    } else if (command.includes('brands')) {
      description = 'Brand performance export';
    } else if (command.includes('flat_latest')) {
      description = 'Latest transactions export';
    }
  }

  return {
    command,
    description,
    estimatedTime
  };
}

/**
 * Copy text to clipboard with fallback
 */
export async function copyToClipboard(text: string): Promise<boolean> {
  try {
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(text);
      return true;
    } else {
      // Fallback for older browsers
      const textArea = document.createElement('textarea');
      textArea.value = text;
      textArea.style.position = 'fixed';
      textArea.style.left = '-999999px';
      textArea.style.top = '-999999px';
      document.body.appendChild(textArea);
      textArea.focus();
      textArea.select();
      const result = document.execCommand('copy');
      textArea.remove();
      return result;
    }
  } catch (error) {
    console.error('Failed to copy to clipboard:', error);
    return false;
  }
}

/**
 * Generate filename with timestamp
 */
export function generateTimestampedFilename(base: string, extension: string = 'csv'): string {
  const timestamp = new Date().toISOString().slice(0, 19).replace(/[:.]/g, '-');
  const cleanBase = base.toLowerCase().replace(/[^a-z0-9_-]/g, '_');
  return `scout_${cleanBase}_${timestamp}.${extension}`;
}