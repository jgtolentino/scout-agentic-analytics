-- rows
SELECT COUNT(*) FROM fact_transactions_location;
-- substitution consistency violations
SELECT COUNT(*) FROM fact_transactions_location
WHERE substitution_detected = TRUE
  AND (substitution_reason IS NULL OR brand_switching_score IS NULL OR audio_transcript IS NULL);
-- location: missing municipality
SELECT COUNT(*) FROM fact_transactions_location WHERE municipality_name IS NULL;
-- location: missing geometry
SELECT COUNT(*) FROM fact_transactions_location
WHERE latitude IS NULL AND longitude IS NULL;