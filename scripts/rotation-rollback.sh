#!/usr/bin/env bash
# Automated rollback system for password rotation failures
set -euo pipefail

echo "🔄 Starting password rotation rollback..."

# Check if we have a previous password to rollback to
:bruno run '
if [ -z "$BRUNO_SECRET_db_password_prev" ]; then
  echo "❌ No previous password found for rollback"
  exit 1
fi
'

# Perform rollback
echo "Reverting etl_svc to previous password..."
:bruno run '
psql "$BRUNO_SECRET_db_url_admin" -v ON_ERROR_STOP=1 <<SQL
do $
begin
  alter role etl_svc with password :prev;
  raise notice '\''Password reverted for etl_svc'\'';
exception when others then
  raise exception '\''Rollback failed: %'\'', sqlerrm;
end$;
SQL
' prev="$BRUNO_SECRET_db_password_prev"

# Update connection URL to use previous password
:bruno secrets set db.url "postgresql://etl_svc:${BRUNO_SECRET_db_password_prev}@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres?options=project%3D${BRUNO_SECRET_supabase_project_ref}"

# Verify rollback
echo "Verifying rollback..."
if :bruno run 'psql "$BRUNO_SECRET_db_url" -c "select now() as rollback_test, current_user;" | grep etl_svc'; then
  echo "✅ Rollback successful"
  
  # Update current password to be the previous one
  :bruno secrets set db.password "$BRUNO_SECRET_db_password_prev"
  
  # Clear the failed new password
  :bruno secrets unset db.password_new || true
  
  # Log rollback
  :bruno run 'echo "$(date -Is): Password rollback completed" >> ~/.rotation-audit.log'
  
  # Notify success
  :bruno run './scripts/notify-rotation-enhanced.sh "Password rotation rolled back successfully" "warning"'
else
  echo "❌ Rollback verification failed"
  
  # Critical failure - trigger PagerDuty
  :bruno run './scripts/notify-rotation-enhanced.sh "CRITICAL: Password rollback failed - manual intervention required" "error"'
  exit 1
fi