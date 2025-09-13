import fs from 'node:fs'
import path from 'node:path'

export type VendorTokens = {
  colors?: Record<string,string>
  radius?: Record<string,string|number>
  spacing?: Record<string,string|number>
  shadows?: Record<string,string>
  typography?: { fontFamily?: string, fontMono?: string }
}

export type ScoutTokens = {
  color: {
    bg: string; surface: string; text: string;
    primary: string; muted: string; accent: string;
  },
  radius: { sm: string; md: string; lg: string },
  gap: { xs: string; sm: string; md: string; lg: string; xl: string },
  shadow: { sm: string; md: string; lg: string },
  font: { sans: string; mono: string },
}

export function fromVendor(v: VendorTokens): ScoutTokens {
  return {
    color: {
      bg: v.colors?.background ?? '#0b0f1a',
      surface: v.colors?.surface ?? '#121826',
      text: v.colors?.text ?? '#e5e7eb',
      primary: v.colors?.primary ?? '#22c55e',
      muted: v.colors?.muted ?? '#64748b',
      accent: v.colors?.accent ?? '#60a5fa',
    },
    radius: {
      sm: toPx(v.radius?.sm ?? 6),
      md: toPx(v.radius?.md ?? 10),
      lg: toPx(v.radius?.lg ?? 14),
    },
    gap: {
      xs: toPx(v.spacing?.xs ?? 4),
      sm: toPx(v.spacing?.sm ?? 8),
      md: toPx(v.spacing?.md ?? 12),
      lg: toPx(v.spacing?.lg ?? 16),
      xl: toPx(v.spacing?.xl ?? 24),
    },
    shadow: {
      sm: v.shadows?.sm ?? '0 1px 2px rgba(0,0,0,.2)',
      md: v.shadows?.md ?? '0 6px 12px rgba(0,0,0,.25)',
      lg: v.shadows?.lg ?? '0 12px 24px rgba(0,0,0,.3)',
    },
    font: {
      sans: v.typography?.fontFamily ?? 'Inter, ui-sans-serif, system-ui',
      mono: v.typography?.fontMono ?? 'ui-monospace, SFMono-Regular, Menlo, monospace',
    }
  }
}

function toPx(v: string|number){ return typeof v === 'number' ? `${v}px` : v }