-- Scout v7 Authentication and Authorization Schema
-- Creates user profiles, roles, and permissions for Scout dashboard access

-- Enable Row Level Security
ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- Create schema for auth-related tables
CREATE SCHEMA IF NOT EXISTS scout_auth;

-- User roles enum
CREATE TYPE scout_auth.user_role AS ENUM (
  'admin',        -- Full system access
  'analyst',      -- Full read access + some write permissions
  'viewer',       -- Read-only access
  'guest'         -- Limited access to specific stores/brands
);

-- Permission types enum
CREATE TYPE scout_auth.permission_type AS ENUM (
  'scout_read',           -- Read Scout transaction data
  'scout_write',          -- Modify Scout data
  'scout_admin',          -- Administrative functions
  'analytics_advanced',   -- Advanced analytics features
  'export_data',          -- Export capabilities
  'ai_insights',          -- AI-powered insights access
  'store_management',     -- Store configuration
  'brand_management',     -- Brand configuration
  'user_management'       -- Manage other users
);

-- User profiles table
CREATE TABLE scout_auth.user_profiles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  email TEXT NOT NULL,
  full_name TEXT,
  role scout_auth.user_role NOT NULL DEFAULT 'viewer',
  permissions scout_auth.permission_type[] NOT NULL DEFAULT ARRAY['scout_read'],

  -- Access restrictions
  allowed_stores INTEGER[] DEFAULT NULL,  -- NULL = all stores, specific array = restricted
  allowed_brands TEXT[] DEFAULT NULL,     -- NULL = all brands, specific array = restricted

  -- Metadata
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_login_at TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,

  -- Analytics preferences
  default_date_range INTERVAL DEFAULT '30 days',
  preferred_timezone TEXT DEFAULT 'Asia/Manila',
  dashboard_config JSONB DEFAULT '{}'
);

-- Create index for faster lookups
CREATE INDEX idx_user_profiles_user_id ON scout_auth.user_profiles(user_id);
CREATE INDEX idx_user_profiles_role ON scout_auth.user_profiles(role);
CREATE INDEX idx_user_profiles_email ON scout_auth.user_profiles(email);

-- Audit log for user actions
CREATE TABLE scout_auth.user_audit_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  action TEXT NOT NULL,
  resource_type TEXT,
  resource_id TEXT,
  details JSONB DEFAULT '{}',
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index for audit queries
CREATE INDEX idx_user_audit_log_user_id ON scout_auth.user_audit_log(user_id);
CREATE INDEX idx_user_audit_log_created_at ON scout_auth.user_audit_log(created_at);
CREATE INDEX idx_user_audit_log_action ON scout_auth.user_audit_log(action);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION scout_auth.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updating updated_at
CREATE TRIGGER update_user_profiles_updated_at
  BEFORE UPDATE ON scout_auth.user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION scout_auth.update_updated_at_column();

-- Function to create user profile automatically
CREATE OR REPLACE FUNCTION scout_auth.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO scout_auth.user_profiles (user_id, email, role, permissions)
  VALUES (
    NEW.id,
    NEW.email,
    'viewer',
    ARRAY['scout_read']::scout_auth.permission_type[]
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile on user signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION scout_auth.handle_new_user();

-- Function to log user actions
CREATE OR REPLACE FUNCTION scout_auth.log_user_action(
  p_user_id UUID,
  p_action TEXT,
  p_resource_type TEXT DEFAULT NULL,
  p_resource_id TEXT DEFAULT NULL,
  p_details JSONB DEFAULT '{}',
  p_ip_address INET DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  log_id UUID;
BEGIN
  INSERT INTO scout_auth.user_audit_log (
    user_id, action, resource_type, resource_id, details, ip_address, user_agent
  )
  VALUES (
    p_user_id, p_action, p_resource_type, p_resource_id, p_details, p_ip_address, p_user_agent
  )
  RETURNING id INTO log_id;

  RETURN log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check user permissions
CREATE OR REPLACE FUNCTION scout_auth.user_has_permission(
  p_user_id UUID,
  p_permission scout_auth.permission_type
)
RETURNS BOOLEAN AS $$
DECLARE
  user_permissions scout_auth.permission_type[];
BEGIN
  SELECT permissions INTO user_permissions
  FROM scout_auth.user_profiles
  WHERE user_id = p_user_id AND is_active = TRUE;

  RETURN p_permission = ANY(user_permissions);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check store access
CREATE OR REPLACE FUNCTION scout_auth.user_can_access_store(
  p_user_id UUID,
  p_store_id INTEGER
)
RETURNS BOOLEAN AS $$
DECLARE
  allowed_stores INTEGER[];
BEGIN
  SELECT allowed_stores INTO allowed_stores
  FROM scout_auth.user_profiles
  WHERE user_id = p_user_id AND is_active = TRUE;

  -- NULL means access to all stores
  IF allowed_stores IS NULL THEN
    RETURN TRUE;
  END IF;

  RETURN p_store_id = ANY(allowed_stores);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check brand access
CREATE OR REPLACE FUNCTION scout_auth.user_can_access_brand(
  p_user_id UUID,
  p_brand TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
  allowed_brands TEXT[];
BEGIN
  SELECT allowed_brands INTO allowed_brands
  FROM scout_auth.user_profiles
  WHERE user_id = p_user_id AND is_active = TRUE;

  -- NULL means access to all brands
  IF allowed_brands IS NULL THEN
    RETURN TRUE;
  END IF;

  RETURN p_brand = ANY(allowed_brands);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Row Level Security Policies

-- Enable RLS on user_profiles
ALTER TABLE scout_auth.user_profiles ENABLE ROW LEVEL SECURITY;

-- Users can only see their own profile
CREATE POLICY "Users can view own profile" ON scout_auth.user_profiles
  FOR SELECT USING (auth.uid() = user_id);

-- Users can update their own profile (limited fields)
CREATE POLICY "Users can update own profile" ON scout_auth.user_profiles
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (
    auth.uid() = user_id AND
    OLD.role = NEW.role AND  -- Can't change their own role
    OLD.permissions = NEW.permissions  -- Can't change their own permissions
  );

-- Admins can see all profiles
CREATE POLICY "Admins can view all profiles" ON scout_auth.user_profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM scout_auth.user_profiles up
      WHERE up.user_id = auth.uid()
      AND up.role = 'admin'
      AND up.is_active = TRUE
    )
  );

-- Admins can manage all profiles
CREATE POLICY "Admins can manage all profiles" ON scout_auth.user_profiles
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM scout_auth.user_profiles up
      WHERE up.user_id = auth.uid()
      AND up.role = 'admin'
      AND up.is_active = TRUE
    )
  );

-- Enable RLS on audit log
ALTER TABLE scout_auth.user_audit_log ENABLE ROW LEVEL SECURITY;

-- Users can see their own audit log
CREATE POLICY "Users can view own audit log" ON scout_auth.user_audit_log
  FOR SELECT USING (auth.uid() = user_id);

-- Admins can see all audit logs
CREATE POLICY "Admins can view all audit logs" ON scout_auth.user_audit_log
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM scout_auth.user_profiles up
      WHERE up.user_id = auth.uid()
      AND up.role = 'admin'
      AND up.is_active = TRUE
    )
  );

-- Grant necessary permissions
GRANT USAGE ON SCHEMA scout_auth TO authenticated, anon;
GRANT SELECT ON scout_auth.user_profiles TO authenticated, anon;
GRANT SELECT ON scout_auth.user_audit_log TO authenticated;

-- Create a view for public user info (no sensitive data)
CREATE VIEW scout_auth.public_user_profiles AS
SELECT
  id,
  user_id,
  full_name,
  role,
  created_at,
  is_active
FROM scout_auth.user_profiles
WHERE is_active = TRUE;

GRANT SELECT ON scout_auth.public_user_profiles TO authenticated, anon;

-- Insert default admin user (this should be updated with actual admin email)
-- Note: This will only work after the user signs up through auth
-- INSERT INTO scout_auth.user_profiles (user_id, email, role, permissions)
-- VALUES (
--   'uuid-of-admin-user',
--   'admin@tbwa.com',
--   'admin',
--   ARRAY['scout_read', 'scout_write', 'scout_admin', 'analytics_advanced', 'export_data', 'ai_insights', 'store_management', 'brand_management', 'user_management']::scout_auth.permission_type[]
-- );

COMMENT ON SCHEMA scout_auth IS 'Authentication and authorization schema for Scout v7 Dashboard';
COMMENT ON TABLE scout_auth.user_profiles IS 'User profiles with roles and permissions for Scout dashboard access';
COMMENT ON TABLE scout_auth.user_audit_log IS 'Audit log for tracking user actions and security events';