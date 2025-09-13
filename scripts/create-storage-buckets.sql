-- ============================================================================
-- Create Storage Buckets for Edge Ingestion
-- Run this in Supabase SQL Editor to set up the bucket structure
-- ============================================================================

-- Create the main bucket for Scout data
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'scout-bronze',
  'scout-bronze', 
  false,  -- Private bucket (requires auth)
  52428800,  -- 50MB file size limit
  ARRAY['application/json', 'text/csv', 'application/x-parquet', 'application/gzip']
)
ON CONFLICT (id) DO UPDATE SET
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Create RLS policies for the bucket
-- Policy 1: Service role can do everything
CREATE POLICY "Service role full access" ON storage.objects
FOR ALL TO service_role
USING (bucket_id = 'scout-bronze');

-- Policy 2: Authenticated users with storage_uploader role can upload
CREATE POLICY "Storage uploaders can insert" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'scout-bronze' 
  AND auth.jwt() ->> 'role' = 'storage_uploader'
  AND name LIKE 'scout/v1/%'
);

-- Policy 3: Allow storage uploaders to read their uploads
CREATE POLICY "Storage uploaders can read" ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id = 'scout-bronze' 
  AND auth.jwt() ->> 'role' = 'storage_uploader'
);

-- Grant usage on storage schema
GRANT USAGE ON SCHEMA storage TO authenticated;
GRANT SELECT, INSERT ON storage.objects TO authenticated;

-- Create helper function to check bucket status
CREATE OR REPLACE FUNCTION check_scout_storage_setup()
RETURNS TABLE (
  bucket_exists boolean,
  bucket_public boolean,
  file_count bigint,
  total_size_mb numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    EXISTS(SELECT 1 FROM storage.buckets WHERE id = 'scout-bronze'),
    COALESCE((SELECT public FROM storage.buckets WHERE id = 'scout-bronze'), false),
    COUNT(*)::bigint,
    ROUND(SUM(metadata->>'size')::numeric / 1048576, 2)
  FROM storage.objects
  WHERE bucket_id = 'scout-bronze';
END;
$$ LANGUAGE plpgsql;

-- Check the setup
SELECT * FROM check_scout_storage_setup();