import React from 'react'

interface AuthGuardProps {
  children: React.ReactNode
  requiredPermissions?: string[]
  redirectTo?: string
}

// Simplified AuthGuard for Azure migration - no authentication required for now
const AuthGuard: React.FC<AuthGuardProps> = ({ children }) => {
  return (
    <div className="scout-auth-context">
      {children}
    </div>
  )
}

export default AuthGuard