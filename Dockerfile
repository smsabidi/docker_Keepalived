# Dockerfile for custom Keepalived image with dynamic configuration
FROM --platform=linux/arm64 alpine:latest

# Install Keepalived and essential utilities
RUN apk add --no-cache \
    keepalived \
    curl \
    bash \
    iputils \
    iproute2 \
    net-tools \
    bind-tools \
    ca-certificates \
    procps \
    coreutils \
    && rm -rf /var/cache/apk/*

# Create necessary directories
RUN mkdir -p /etc/keepalived \
             /usr/local/bin \
             /var/log/keepalived \
    && touch /var/log/keepalived/health-check.log \
    && touch /var/log/keepalived/state-changes.log

# Copy scripts
COPY check_service.sh /usr/local/bin/check_service.sh
COPY notify.sh /usr/local/bin/notify.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# Set proper permissions
RUN chmod +x /usr/local/bin/check_service.sh \
    && chmod +x /usr/local/bin/notify.sh \
    && chmod +x /usr/local/bin/entrypoint.sh

# Healthcheck
HEALTHCHECK --interval=10s --timeout=5s --start-period=15s --retries=3 \
    CMD pgrep keepalived > /dev/null || exit 1

# Environment variables
ENV KEEPALIVED_STATE=MASTER \
    KEEPALIVED_PRIORITY=100 \
    KEEPALIVED_INTERFACE=eth0 \
    KEEPALIVED_VIRTUAL_ROUTER_ID=51 \
    KEEPALIVED_VIRTUAL_IP=192.168.1.100/24 \
    KEEPALIVED_AUTH_PASS=SecPass01 \
    ENABLE_HEALTH_CHECK=true \
    HEALTH_CHECK_MODE=http \
    HEALTH_CHECK_URL=http://localhost:8080/health \
    HEALTH_CHECK_TIMEOUT=3 \
    NOTIFICATION_METHODS=log

# Labels
LABEL maintainer="smsabidi" \
      description="Custom Keepalived image for high availability" \
      version="2.0"

# Entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["keepalived", "--dont-fork", "--log-console", "--log-detail"]