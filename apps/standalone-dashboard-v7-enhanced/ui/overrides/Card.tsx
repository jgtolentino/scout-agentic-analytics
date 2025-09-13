import * as React from 'react'

interface CardProps {
  children: React.ReactNode
  className?: string
  variant?: 'default' | 'neumorph' | 'kpi'
}

export function Card({children, className = '', variant = 'default'}: CardProps) {
  const baseClass = variant === 'neumorph' ? 'neumorph' : 
                   variant === 'kpi' ? 'kpi bg-surface' : 
                   'card'
  
  return <div className={`${baseClass} ${className}`}>{children}</div>
}