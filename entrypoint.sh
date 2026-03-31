#!/usr/bin/env bash

set -e

# Default values
KEEPALIVED_STATE=${KEEPALIVED_STATE:-MASTER}
KEEPALIVED_PRIORITY=${KEEPALIVED_PRIORITY:-100}
KEEPALIVED_INTERFACE=${KEEPALIVED_INTERFACE:-eth0}
KEEPALIVED_VIRTUAL_ROUTER_ID=${KEEPALIVED_VIRTUAL_ROUTER_ID:-51}
KEEPALIVED_VIRTUAL_IP=${KEEPALIVED_VIRTUAL_IP:-192.168.1.100/24}
KEEPALIVED_AUTH_PASS=${KEEPALIVED_AUTH_PASS:-YourStrongPassword123!}
ENABLE_HEALTH_CHECK=${ENABLE_HEALTH_CHECK:-true}

# Truncate password to 8 characters (Keepalived limitation)
KEEPALIVED_AUTH_PASS_TRUNCATED="${KEEPALIVED_AUTH_PASS:0:8}"

CONFIG_FILE="/etc/keepalived/keepalived.conf"

echo "=========================================="
echo "Configuring Keepalived Node"
echo "=========================================="
echo "State:             ${KEEPALIVED_STATE}"
echo "Priority:          ${KEEPALIVED_PRIORITY}"
echo "Interface:         ${KEEPALIVED_INTERFACE}"
echo "Virtual Router ID: ${KEEPALIVED_VIRTUAL_ROUTER_ID}"
echo "Virtual IP:        ${KEEPALIVED_VIRTUAL_IP}"
echo "Auth Pass:         ${KEEPALIVED_AUTH_PASS_TRUNCATED} (truncated)"
echo "Health Check:      ${ENABLE_HEALTH_CHECK}"
echo "=========================================="

# Start building configuration
cat > ${CONFIG_FILE} <<EOF
global_defs {
    router_id DOCKER_NODE_${KEEPALIVED_STATE}
EOF

# Add script security settings if health check is enabled
if [[ "${ENABLE_HEALTH_CHECK}" == "true" ]]; then
    cat >> ${CONFIG_FILE} <<EOF
    enable_script_security
    script_user root
EOF
fi

cat >> ${CONFIG_FILE} <<EOF
}

EOF

# Add health check script definition if enabled
if [[ "${ENABLE_HEALTH_CHECK}" == "true" ]]; then
    cat >> ${CONFIG_FILE} <<EOF
vrrp_script check_service {
    script "/usr/local/bin/check_service.sh"
    interval 2
    weight -20
    fall 3
    rise 2
    user root
}

EOF
fi

# Add VRRP instance configuration
cat >> ${CONFIG_FILE} <<EOF
vrrp_instance VI_1 {
    state ${KEEPALIVED_STATE}
    interface ${KEEPALIVED_INTERFACE}
    virtual_router_id ${KEEPALIVED_VIRTUAL_ROUTER_ID}
    priority ${KEEPALIVED_PRIORITY}
    advert_int 1

    authentication {
        auth_type PASS
        auth_pass ${KEEPALIVED_AUTH_PASS_TRUNCATED}
    }

    virtual_ipaddress {
        ${KEEPALIVED_VIRTUAL_IP}
    }
EOF

# Add track_script if health check is enabled
if [[ "${ENABLE_HEALTH_CHECK}" == "true" ]]; then
    cat >> ${CONFIG_FILE} <<EOF

    track_script {
        check_service
    }
EOF
fi

# Add notification scripts
cat >> ${CONFIG_FILE} <<EOF

    notify_master "/usr/local/bin/notify.sh MASTER"
    notify_backup "/usr/local/bin/notify.sh BACKUP"
    notify_fault  "/usr/local/bin/notify.sh FAULT"
}
EOF

echo "✓ Configuration file generated successfully"
echo ""

# Display the generated config
echo "Generated Configuration:"
echo "----------------------------------------"
cat ${CONFIG_FILE}
echo "----------------------------------------"
echo ""

# Validate configuration
echo "Validating configuration..."
if keepalived --config-test 2>&1 | tee /tmp/keepalived-test.log; then
    echo "✓ Configuration validation passed"
else
    echo "✗ Configuration validation failed!"
    echo ""
    echo "Error details:"
    cat /tmp/keepalived-test.log
    exit 1
fi

echo ""
echo "Starting Keepalived..."

# Execute the CMD
exec "$@"