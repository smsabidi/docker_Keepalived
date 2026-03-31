#!/usr/bin/env bash

# Advanced notification script for Keepalived state changes
# Supports multiple notification methods: log, email, Slack, webhook, SMS

set -e

# Configuration
TYPE="$1"
NAME="${2:-VI_1}"
PRIORITY="${3:-100}"

LOG_FILE="/var/log/keepalived/state-changes.log"
NOTIFICATION_METHODS="${NOTIFICATION_METHODS:-log}"  # log, email, slack, webhook, sms

# Notification configuration
EMAIL_TO="${EMAIL_TO:-admin@google.com}"
EMAIL_FROM="${EMAIL_FROM:-keepalived@google.com}"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
WEBHOOK_URL="${WEBHOOK_URL:-}"
SMS_API_URL="${SMS_API_URL:-}"
SMS_TO="${SMS_TO:-}"

# Get hostname and IP
HOSTNAME=$(hostname)
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Logging function
log_message() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ${message}" >> "$LOG_FILE"
}

# Get state emoji for better visualization
get_state_emoji() {
    case "$TYPE" in
        MASTER) echo "🟢" ;;
        BACKUP) echo "🟡" ;;
        FAULT)  echo "🔴" ;;
        STOP)   echo "⚫" ;;
        *)      echo "⚪" ;;
    esac
}

# Get state color for notifications
get_state_color() {
    case "$TYPE" in
        MASTER) echo "good" ;;      # Green
        BACKUP) echo "warning" ;;   # Yellow
        FAULT)  echo "danger" ;;    # Red
        *)      echo "#808080" ;;   # Gray
    esac
}

# Send email notification
send_email() {
    log_message "Sending email notification to ${EMAIL_TO}"
    
    local subject="Keepalived State Change: ${TYPE} on ${HOSTNAME}"
    local body="Keepalived Instance: ${NAME}
Hostname: ${HOSTNAME}
IP Address: ${IP_ADDRESS}
New State: ${TYPE}
Priority: ${PRIORITY}
Timestamp: $(date '+%Y-%m-%d %H:%M:%S')

This is an automated notification from the Keepalived high availability service."
    
    if command -v mail &> /dev/null; then
        echo "$body" | mail -s "$subject" -r "$EMAIL_FROM" "$EMAIL_TO"
        log_message "Email sent successfully"
    elif command -v sendmail &> /dev/null; then
        echo -e "Subject: ${subject}\nFrom: ${EMAIL_FROM}\nTo: ${EMAIL_TO}\n\n${body}" | sendmail -t
        log_message "Email sent via sendmail"
    else
        log_message "ERROR: No mail command available"
    fi
}

# Send Slack notification
send_slack() {
    if [[ -z "$SLACK_WEBHOOK_URL" ]]; then
        log_message "WARN: Slack webhook URL not configured"
        return 1
    fi
    
    log_message "Sending Slack notification"
    
    local emoji=$(get_state_emoji)
    local color=$(get_state_color)
    
    local payload=$(cat <<EOF
{
    "username": "Keepalived Monitor",
    "icon_emoji": ":shield:",
    "attachments": [
        {
            "color": "${color}",
            "title": "${emoji} Keepalived State Change: ${TYPE}",
            "fields": [
                {
                    "title": "Instance",
                    "value": "${NAME}",
                    "short": true
                },
                {
                    "title": "Hostname",
                    "value": "${HOSTNAME}",
                    "short": true
                },
                {
                    "title": "IP Address",
                    "value": "${IP_ADDRESS}",
                    "short": true
                },
                {
                    "title": "Priority",
                    "value": "${PRIORITY}",
                    "short": true
                },
                {
                    "title": "New State",
                    "value": "${TYPE}",
                    "short": true
                },
                {
                    "title": "Timestamp",
                    "value": "$(date '+%Y-%m-%d %H:%M:%S')",
                    "short": true
                }
            ],
            "footer": "Keepalived HA Monitor",
            "footer_icon": "https://www.keepalived.org/images/keepalived.png"
        }
    ]
}
EOF
)
    
    if curl -sf -X POST -H 'Content-type: application/json' \
        --data "$payload" "$SLACK_WEBHOOK_URL" > /dev/null 2>&1; then
        log_message "Slack notification sent successfully"
    else
        log_message "ERROR: Failed to send Slack notification"
    fi
}

# Send generic webhook notification
send_webhook() {
    if [[ -z "$WEBHOOK_URL" ]]; then
        log_message "WARN: Webhook URL not configured"
        return 1
    fi
    
    log_message "Sending webhook notification"
    
    local payload=$(cat <<EOF
{
    "event": "keepalived_state_change",
    "instance": "${NAME}",
    "hostname": "${HOSTNAME}",
    "ip_address": "${IP_ADDRESS}",
    "state": "${TYPE}",
    "priority": ${PRIORITY},
    "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
}
EOF
)
    
    if curl -sf -X POST -H 'Content-Type: application/json' \
        --data "$payload" "$WEBHOOK_URL" > /dev/null 2>&1; then
        log_message "Webhook notification sent successfully"
    else
        log_message "ERROR: Failed to send webhook notification"
    fi
}

# Send SMS notification (example using Twilio-like API)
send_sms() {
    if [[ -z "$SMS_API_URL" ]] || [[ -z "$SMS_TO" ]]; then
        log_message "WARN: SMS configuration incomplete"
        return 1
    fi
    
    log_message "Sending SMS notification to ${SMS_TO}"
    
    local message="Keepalived Alert: ${TYPE} state on ${HOSTNAME} (${IP_ADDRESS})"
    
    local payload=$(cat <<EOF
{
    "to": "${SMS_TO}",
    "message": "${message}"
}
EOF
)
    
    if curl -sf -X POST -H 'Content-Type: application/json' \
        --data "$payload" "$SMS_API_URL" > /dev/null 2>&1; then
        log_message "SMS notification sent successfully"
    else
        log_message "ERROR: Failed to send SMS notification"
    fi
}

# Send Microsoft Teams notification
send_teams() {
    if [[ -z "$TEAMS_WEBHOOK_URL" ]]; then
        log_message "WARN: Teams webhook URL not configured"
        return 1
    fi
    
    log_message "Sending Microsoft Teams notification"
    
    local emoji=$(get_state_emoji)
    local color=$(get_state_color)
    
    # Convert color names to hex
    case "$color" in
        good) color="00FF00" ;;
        warning) color="FFA500" ;;
        danger) color="FF0000" ;;
    esac
    
    local payload=$(cat <<EOF
{
    "@type": "MessageCard",
    "@context": "https://schema.org/extensions",
    "summary": "Keepalived State Change: ${TYPE}",
    "themeColor": "${color}",
    "title": "${emoji} Keepalived State Change: ${TYPE}",
    "sections": [
        {
            "facts": [
                {
                    "name": "Instance:",
                    "value": "${NAME}"
                },
                {
                    "name": "Hostname:",
                    "value": "${HOSTNAME}"
                },
                {
                    "name": "IP Address:",
                    "value": "${IP_ADDRESS}"
                },
                {
                    "name": "New State:",
                    "value": "${TYPE}"
                },
                {
                    "name": "Priority:",
                    "value": "${PRIORITY}"
                },
                {
                    "name": "Timestamp:",
                    "value": "$(date '+%Y-%m-%d %H:%M:%S')"
                }
            ]
        }
    ]
}
EOF
)
    
    if curl -sf -X POST -H 'Content-Type: application/json' \
        --data "$payload" "$TEAMS_WEBHOOK_URL" > /dev/null 2>&1; then
        log_message "Teams notification sent successfully"
    else
        log_message "ERROR: Failed to send Teams notification"
    fi
}

# Execute custom script if provided
execute_custom_script() {
    local custom_script="${CUSTOM_NOTIFY_SCRIPT:-}"
    
    if [[ -n "$custom_script" ]] && [[ -x "$custom_script" ]]; then
        log_message "Executing custom notification script: ${custom_script}"
        "$custom_script" "$TYPE" "$NAME" "$PRIORITY" "$HOSTNAME" "$IP_ADDRESS"
    fi
}

# Main notification logic
main() {
    log_message "Keepalived state changed to: ${TYPE} (Instance: ${NAME}, Priority: ${PRIORITY})"
    
    # Parse notification methods (comma-separated)
    IFS=',' read -ra METHODS <<< "$NOTIFICATION_METHODS"
    
    for method in "${METHODS[@]}"; do
        method=$(echo "$method" | xargs)  # Trim whitespace
        
        case "$method" in
            log)
                # Already logged above
                ;;
            email)
                send_email || log_message "ERROR: Email notification failed"
                ;;
            slack)
                send_slack || log_message "ERROR: Slack notification failed"
                ;;
            webhook)
                send_webhook || log_message "ERROR: Webhook notification failed"
                ;;
            sms)
                send_sms || log_message "ERROR: SMS notification failed"
                ;;
            teams)
                send_teams || log_message "ERROR: Teams notification failed"
                ;;
            custom)
                execute_custom_script || log_message "ERROR: Custom script failed"
                ;;
            *)
                log_message "WARN: Unknown notification method: ${method}"
                ;;
        esac
    done
    
    log_message "Notification processing completed"
}

# Run main function
main "$@"