#!/usr/bin/env bash
# Manual password rotation with all safety features
set -euo pipefail

echo "🔐 Starting manual password rotation for etl_svc..."

# Pre-flight checks
echo "Running pre-rotation checks..."
:bruno run 'psql "$BRUNO_SECRET_db_url" -c "select 1" >/dev/null 2>&1' || {
  echo "❌ Current connection failed - aborting"
  exit 1
}

# Backup current password
:bruno run '
if [ -z "$BRUNO_SECRET_db_password_prev" ] || [ "$BRUNO_SECRET_db_password_prev" != "$BRUNO_SECRET_db_password" ]; then
  :bruno secrets set db.password_prev "$BRUNO_SECRET_db_password"
  echo "Backed up current password"
fi
'

# Generate new password
echo "Generating new password..."
:bruno run 'NEW_PW=$(openssl rand -base64 32); :bruno secrets set db.password_new "$NEW_PW"; echo "New password generated"'

# Rotate password in database
echo "Rotating password in database..."
:bruno run '
psql "$BRUNO_SECRET_db_url_admin" -v ON_ERROR_STOP=1 <<SQL
do $
begin
  alter role etl_svc with password :newpw;
  raise notice '\''Password rotated for etl_svc'\'';
exception when others then
  raise exception '\''Failed to rotate password: %'\'', sqlerrm;
end$;
SQL
' newpw="$BRUNO_SECRET_db_password_new" || {
  echo "❌ Database rotation failed"
  :bruno run './scripts/notify-rotation-enhanced.sh "Manual password rotation failed at DB step" "error"'
  exit 1
}

# Update connection URL
echo "Updating connection configuration..."
:bruno secrets set db.url "postgresql://etl_svc:${BRUNO_SECRET_db_password_new}@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres?options=project%3D${BRUNO_SECRET_supabase_project_ref}"

# Verify new connection
echo "Verifying new connection..."
if :bruno run 'psql "$BRUNO_SECRET_db_url" -c "select now() as verify_time, current_user;" | grep etl_svc'; then
  echo "✅ Connection verified"
  
  # Commit the rotation
  :bruno run '
    :bruno secrets set db.password "$BRUNO_SECRET_db_password_new"
    :bruno secrets unset db.password_new || true
    echo "$(date -Is): Manual password rotation completed" >> ~/.rotation-audit.log
  '
  
  # Update Edge Functions if needed
  if [ "${UPDATE_EDGE_FUNCTIONS:-false}" = "true" ]; then
    echo "Updating Edge Functions..."
    :bruno run '
      supabase secrets set --project-ref $BRUNO_SECRET_supabase_project_ref \
        DB_URL="$BRUNO_SECRET_db_url"
      supabase functions deploy ingest-bronze --project-ref $BRUNO_SECRET_supabase_project_ref
    '
  fi
  
  # Success notification
  :bruno run './scripts/notify-rotation-enhanced.sh "Manual password rotation completed successfully" "success"'
  echo "🎉 Password rotation completed successfully!"
  
else
  echo "❌ Connection verification failed - initiating rollback"
  :bruno run './scripts/rotation-rollback.sh'
  exit 1
fi