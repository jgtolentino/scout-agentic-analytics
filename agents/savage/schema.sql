-- Agent Savage Database Schema
-- Brand-aligned pattern generation and visualization

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Projects table (brand configurations)
CREATE TABLE IF NOT EXISTS projects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  owner_id UUID REFERENCES auth.users(id),
  org_type TEXT NOT NULL, -- UNDP, OCHA, Corporate, etc.
  project_name TEXT NOT NULL,
  brand_json JSONB NOT NULL DEFAULT '{}', -- colors, fonts, logos, motifs
  settings JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Pattern templates library
CREATE TABLE IF NOT EXISTS pattern_templates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  template_id TEXT UNIQUE NOT NULL,
  template_name TEXT NOT NULL,
  description TEXT,
  category TEXT NOT NULL, -- geometric, organic, data-driven, etc.
  base_svg TEXT NOT NULL, -- Base SVG template
  parameters JSONB NOT NULL DEFAULT '{}', -- Available parameters
  preview_url TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Generated patterns
CREATE TABLE IF NOT EXISTS patterns (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
  template_id TEXT REFERENCES pattern_templates(template_id),
  pattern_name TEXT,
  params JSONB NOT NULL DEFAULT '{}', -- spacing, rotation, colors, etc.
  data_map JSONB DEFAULT '{}', -- Optional data-driven values
  svg_content TEXT, -- Generated SVG
  gif_url TEXT, -- Generated GIF URL
  png_url TEXT, -- Generated PNG URL
  export_versions JSONB DEFAULT '[]', -- Version history
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Comments and collaboration
CREATE TABLE IF NOT EXISTS comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pattern_id UUID REFERENCES patterns(id) ON DELETE CASCADE,
  author_id UUID REFERENCES auth.users(id),
  author_name TEXT,
  body TEXT NOT NULL,
  resolved BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Pattern analytics
CREATE TABLE IF NOT EXISTS pattern_analytics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pattern_id UUID REFERENCES patterns(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL, -- view, download, share, etc.
  user_id UUID REFERENCES auth.users(id),
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX idx_projects_owner ON projects(owner_id);
CREATE INDEX idx_projects_org_type ON projects(org_type);
CREATE INDEX idx_patterns_project ON patterns(project_id);
CREATE INDEX idx_patterns_template ON patterns(template_id);
CREATE INDEX idx_patterns_created ON patterns(created_at DESC);
CREATE INDEX idx_comments_pattern ON comments(pattern_id);
CREATE INDEX idx_analytics_pattern ON pattern_analytics(pattern_id);
CREATE INDEX idx_analytics_event ON pattern_analytics(event_type);

-- Update trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_projects_updated_at 
    BEFORE UPDATE ON projects 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_patterns_updated_at 
    BEFORE UPDATE ON patterns 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Views for common queries
CREATE OR REPLACE VIEW recent_patterns AS
SELECT 
    p.*,
    pr.project_name,
    pr.org_type,
    pr.brand_json,
    pt.template_name,
    pt.category
FROM patterns p
JOIN projects pr ON p.project_id = pr.id
JOIN pattern_templates pt ON p.template_id = pt.template_id
WHERE p.created_at > NOW() - INTERVAL '30 days'
ORDER BY p.created_at DESC;

-- Function to get pattern statistics
CREATE OR REPLACE FUNCTION get_pattern_stats(
    p_project_id UUID DEFAULT NULL,
    p_days_back INTEGER DEFAULT 30
)
RETURNS TABLE (
    total_patterns BIGINT,
    unique_templates BIGINT,
    total_downloads BIGINT,
    total_comments BIGINT,
    most_used_template TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(DISTINCT p.id)::BIGINT as total_patterns,
        COUNT(DISTINCT p.template_id)::BIGINT as unique_templates,
        COUNT(DISTINCT pa.id)::BIGINT as total_downloads,
        COUNT(DISTINCT c.id)::BIGINT as total_comments,
        (
            SELECT template_id 
            FROM patterns 
            WHERE (p_project_id IS NULL OR project_id = p_project_id)
            AND created_at > NOW() - INTERVAL '1 day' * p_days_back
            GROUP BY template_id 
            ORDER BY COUNT(*) DESC 
            LIMIT 1
        ) as most_used_template
    FROM patterns p
    LEFT JOIN pattern_analytics pa ON p.id = pa.pattern_id AND pa.event_type = 'download'
    LEFT JOIN comments c ON p.id = c.pattern_id
    WHERE (p_project_id IS NULL OR p.project_id = p_project_id)
    AND p.created_at > NOW() - INTERVAL '1 day' * p_days_back;
END;
$$ LANGUAGE plpgsql;

-- Row Level Security
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE patterns ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE pattern_analytics ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own projects" 
    ON projects FOR SELECT 
    USING (auth.uid() = owner_id OR org_type = 'public');

CREATE POLICY "Users can create projects" 
    ON projects FOR INSERT 
    WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Users can update their own projects" 
    ON projects FOR UPDATE 
    USING (auth.uid() = owner_id);

CREATE POLICY "Users can view patterns in their projects" 
    ON patterns FOR SELECT 
    USING (
        project_id IN (
            SELECT id FROM projects WHERE owner_id = auth.uid() OR org_type = 'public'
        )
    );

CREATE POLICY "Users can create patterns in their projects" 
    ON patterns FOR INSERT 
    WITH CHECK (
        project_id IN (
            SELECT id FROM projects WHERE owner_id = auth.uid()
        )
    );

-- Public read access for templates
CREATE POLICY "Everyone can view active templates" 
    ON pattern_templates FOR SELECT 
    USING (is_active = true);

-- Sample pattern templates
INSERT INTO pattern_templates (template_id, template_name, description, category, base_svg, parameters) VALUES
('grid-stripes', 'Grid Stripes', 'Modern grid pattern with diagonal stripes', 'geometric', 
'<svg><pattern id="grid-stripes"><!-- Base SVG --></pattern></svg>',
'{"spacing": {"type": "number", "default": 10, "min": 5, "max": 50}, "rotation": {"type": "number", "default": 45, "min": 0, "max": 360}, "strokeWidth": {"type": "number", "default": 2, "min": 1, "max": 10}}'),

('dot-matrix', 'Dot Matrix', 'Circular dot pattern with variable density', 'geometric',
'<svg><pattern id="dot-matrix"><!-- Base SVG --></pattern></svg>',
'{"dotSize": {"type": "number", "default": 4, "min": 2, "max": 20}, "spacing": {"type": "number", "default": 20, "min": 10, "max": 100}}'),

('wave-flow', 'Wave Flow', 'Organic flowing wave pattern', 'organic',
'<svg><pattern id="wave-flow"><!-- Base SVG --></pattern></svg>',
'{"amplitude": {"type": "number", "default": 20, "min": 5, "max": 50}, "frequency": {"type": "number", "default": 0.1, "min": 0.01, "max": 1}}'),

('data-bars', 'Data Bars', 'Bar chart pattern for data visualization', 'data-driven',
'<svg><pattern id="data-bars"><!-- Base SVG --></pattern></svg>',
'{"barWidth": {"type": "number", "default": 20, "min": 10, "max": 50}, "maxHeight": {"type": "number", "default": 100, "min": 50, "max": 200}}')

ON CONFLICT (template_id) DO NOTHING;