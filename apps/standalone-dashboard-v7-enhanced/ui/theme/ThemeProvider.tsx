'use client'
import React, { PropsWithChildren, useMemo } from 'react'
import { TOKENS } from './tokens'
import './tailwind-bridge.css'

export function ThemeProvider({children}: PropsWithChildren) {
  const styleVars = useMemo(() => ({
    ['--color-bg' as any]: TOKENS.color.bg,
    ['--color-surface']: TOKENS.color.surface,
    ['--color-text']: TOKENS.color.text,
    ['--color-primary']: TOKENS.color.primary,
    ['--color-muted']: TOKENS.color.muted,
    ['--color-accent']: TOKENS.color.accent,
    ['--radius-sm']: TOKENS.radius.sm,
    ['--radius-md']: TOKENS.radius.md,
    ['--radius-lg']: TOKENS.radius.lg,
    ['--gap-xs']: TOKENS.gap.xs,
    ['--gap-sm']: TOKENS.gap.sm,
    ['--gap-md']: TOKENS.gap.md,
    ['--gap-lg']: TOKENS.gap.lg,
    ['--gap-xl']: TOKENS.gap.xl,
    ['--shadow-sm']: TOKENS.shadow.sm,
    ['--shadow-md']: TOKENS.shadow.md,
    ['--shadow-lg']: TOKENS.shadow.lg,
    ['--font-sans']: TOKENS.font.sans,
    ['--font-mono']: TOKENS.font.mono,
  }), [])

  return <div style={styleVars as React.CSSProperties} className="theme-root">{children}</div>
}