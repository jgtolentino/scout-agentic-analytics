SELECT m = CASE WHEN OBJECT_ID('etl.sp_parse_transcripts_basic','P') IS NULL THEN 'MISS etl.sp_parse_transcripts_basic' END
UNION ALL SELECT CASE WHEN OBJECT_ID('etl.sp_update_persona_roles_v21','P') IS NULL THEN 'MISS etl.sp_update_persona_roles_v21' END
UNION ALL SELECT CASE WHEN OBJECT_ID('gold.v_persona_coverage_summary','V') IS NULL THEN 'MISS gold.v_persona_coverage_summary' END
UNION ALL SELECT CASE WHEN OBJECT_ID('etl.persona_inference_cache','U') IS NULL THEN 'MISS etl.persona_inference_cache' END;