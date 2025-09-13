-- ============================================================================
-- Setup Storage Triggers for Automatic Edge Data Processing
-- 
-- This creates database triggers that automatically process files
-- when they land in the scout-bronze storage bucket
-- ============================================================================

-- Create processing log table
CREATE TABLE IF NOT EXISTS public.edge_processing_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  file_path TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('processing', 'success', 'error')),
  bronze_id UUID,
  error_message TEXT,
  processing_time_ms INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for monitoring
CREATE INDEX idx_edge_logs_status ON edge_processing_logs(status, created_at DESC);
CREATE INDEX idx_edge_logs_file ON edge_processing_logs(file_path);

-- Create function to process storage events
CREATE OR REPLACE FUNCTION process_storage_upload()
RETURNS TRIGGER AS $$
DECLARE
  v_webhook_url TEXT;
BEGIN
  -- Only process INSERT events for scout bronze data
  IF TG_OP != 'INSERT' THEN
    RETURN NEW;
  END IF;
  
  -- Check if this is a scout bronze upload
  IF NEW.bucket_id = 'scout-bronze' AND NEW.name LIKE 'scout/v1/bronze/%' THEN
    -- Get the storage webhook URL
    v_webhook_url := current_setting('app.settings.storage_webhook_url', true);
    
    -- If webhook URL is set, use it
    IF v_webhook_url IS NOT NULL THEN
      -- Call webhook asynchronously
      PERFORM net.http_post(
        url := v_webhook_url,
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
        ),
        body := jsonb_build_object(
          'type', TG_OP,
          'record', row_to_json(NEW),
          'old_record', row_to_json(OLD)
        )
      );
    ELSE
      -- Direct processing (if pg_net is not available)
      INSERT INTO edge_processing_logs (file_path, status)
      VALUES (NEW.name, 'processing');
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on storage.objects
DROP TRIGGER IF EXISTS on_storage_upload ON storage.objects;
CREATE TRIGGER on_storage_upload
  AFTER INSERT ON storage.objects
  FOR EACH ROW
  EXECUTE FUNCTION process_storage_upload();

-- Alternative: Use Supabase Database Webhooks
-- This is configured in the Supabase Dashboard under Database > Webhooks
-- URL: https://cxzllzyxwpyptfretryc.functions.supabase.co/storage-webhook
-- Events: INSERT on storage.objects
-- HTTP Headers: 
--   Content-Type: application/json
--   Authorization: Bearer [service-role-key]

-- Create monitoring view
CREATE OR REPLACE VIEW edge_processing_stats AS
SELECT 
  DATE(created_at) as processing_date,
  status,
  COUNT(*) as file_count,
  AVG(processing_time_ms) as avg_processing_time_ms,
  MAX(processing_time_ms) as max_processing_time_ms,
  COUNT(DISTINCT SUBSTRING(file_path FROM 'scout/v1/bronze/([^/]+)/')) as unique_devices
FROM edge_processing_logs
GROUP BY DATE(created_at), status
ORDER BY processing_date DESC, status;

-- Helper function to check processing health
CREATE OR REPLACE FUNCTION check_edge_processing_health()
RETURNS TABLE (
  metric TEXT,
  value NUMERIC,
  status TEXT
) AS $$
BEGIN
  -- Check error rate (last 24 hours)
  RETURN QUERY
  SELECT 
    'error_rate_24h'::TEXT,
    ROUND(100.0 * COUNT(CASE WHEN status = 'error' THEN 1 END) / NULLIF(COUNT(*), 0), 2),
    CASE 
      WHEN COUNT(CASE WHEN status = 'error' THEN 1 END) = 0 THEN 'healthy'
      WHEN 100.0 * COUNT(CASE WHEN status = 'error' THEN 1 END) / COUNT(*) < 5 THEN 'warning'
      ELSE 'critical'
    END
  FROM edge_processing_logs
  WHERE created_at > NOW() - INTERVAL '24 hours';
  
  -- Check processing backlog
  RETURN QUERY
  SELECT 
    'backlog_count'::TEXT,
    COUNT(*)::NUMERIC,
    CASE 
      WHEN COUNT(*) = 0 THEN 'healthy'
      WHEN COUNT(*) < 10 THEN 'warning'
      ELSE 'critical'
    END
  FROM edge_processing_logs
  WHERE status = 'processing'
    AND created_at < NOW() - INTERVAL '10 minutes';
  
  -- Check average processing time
  RETURN QUERY
  SELECT 
    'avg_processing_time_ms'::TEXT,
    COALESCE(AVG(processing_time_ms), 0)::NUMERIC,
    CASE 
      WHEN COALESCE(AVG(processing_time_ms), 0) < 1000 THEN 'healthy'
      WHEN COALESCE(AVG(processing_time_ms), 0) < 5000 THEN 'warning'
      ELSE 'critical'
    END
  FROM edge_processing_logs
  WHERE status = 'success'
    AND created_at > NOW() - INTERVAL '1 hour';
END;
$$ LANGUAGE plpgsql;