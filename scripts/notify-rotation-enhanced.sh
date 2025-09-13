#!/usr/bin/env bash
# Enhanced notification system with Slack, email, and PagerDuty
set -euo pipefail

MSG="${1:-ETL password rotation}"
STATUS="${2:-info}"  # info, success, warning, error
TIMESTAMP=$(date -Is)

# Slack notification (if configured)
if [ -n "${BRUNO_SECRET_notify_slack_webhook:-}" ]; then
  case "$STATUS" in
    success) EMOJI="✅" ;;
    warning) EMOJI="⚠️" ;;
    error)   EMOJI="❌" ;;
    *)       EMOJI="ℹ️" ;;
  esac
  
  curl -sS -X POST -H "Content-type: application/json" \
    --data "{
      \"text\": \"$EMOJI [$TIMESTAMP] $MSG\",
      \"attachments\": [{
        \"color\": \"$([ "$STATUS" = "error" ] && echo "danger" || echo "good")\",
        \"fields\": [
          {\"title\": \"Project\", \"value\": \"${BRUNO_SECRET_supabase_project_ref:-unknown}\", \"short\": true},
          {\"title\": \"Environment\", \"value\": \"production\", \"short\": true}
        ]
      }]
    }" \
    "$BRUNO_SECRET_notify_slack_webhook" >/dev/null || echo "Slack notification failed"
fi

# Email notification via SendGrid (if configured)
if [ -n "${BRUNO_SECRET_sendgrid_api_key:-}" ] && [ "$STATUS" = "error" ]; then
  curl -sS -X POST https://api.sendgrid.com/v3/mail/send \
    -H "Authorization: Bearer $BRUNO_SECRET_sendgrid_api_key" \
    -H "Content-Type: application/json" \
    -d "{
      \"personalizations\": [{
        \"to\": [{\"email\": \"${BRUNO_SECRET_notify_email:-ops@tbwa.com}\"}]
      }],
      \"from\": {\"email\": \"alerts@tbwa.com\"},
      \"subject\": \"[ALERT] $MSG\",
      \"content\": [{
        \"type\": \"text/plain\",
        \"value\": \"Timestamp: $TIMESTAMP\nStatus: $STATUS\nMessage: $MSG\nProject: ${BRUNO_SECRET_supabase_project_ref:-unknown}\"
      }]
    }" >/dev/null || echo "Email notification failed"
fi

# PagerDuty incident (critical errors only)
if [ -n "${BRUNO_SECRET_pagerduty_token:-}" ] && [ "$STATUS" = "error" ]; then
  curl -sS -X POST https://api.pagerduty.com/incidents \
    -H "Authorization: Token token=$BRUNO_SECRET_pagerduty_token" \
    -H "Content-Type: application/json" \
    -d "{
      \"incident\": {
        \"type\": \"incident\",
        \"title\": \"$MSG\",
        \"service\": {
          \"id\": \"${BRUNO_SECRET_pagerduty_service_id:-P8KGMHG}\",
          \"type\": \"service_reference\"
        },
        \"urgency\": \"high\",
        \"body\": {
          \"type\": \"incident_body\",
          \"details\": \"Automated rotation failed at $TIMESTAMP. Manual intervention required.\"
        }
      }
    }" >/dev/null || echo "PagerDuty notification failed"
fi

# Log to audit file
echo "[$TIMESTAMP] $STATUS: $MSG" >> ~/.rotation-audit.log