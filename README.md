# Keepalived High Availability Setup - README

Here's a comprehensive README for your project:

**README.md:**


# Keepalived High Availability Docker Setup

A production-ready Keepalived high availability setup using Docker Compose with automated failover, health checking, and notification capabilities.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Usage](#usage)
- [Testing](#testing)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Overview

This project provides a containerized Keepalived setup for implementing high availability (HA) using VRRP (Virtual Router Redundancy Protocol). It includes automated failover between master and backup nodes, health checking, and multiple notification methods.

### What is Keepalived?

Keepalived is a routing software that provides simple and robust facilities for load balancing and high availability. It uses VRRP protocol to provide failover capabilities for services.

## ✨ Features

- **Automated Failover**: Seamless transition between master and backup nodes
- **Health Checking**: Multiple health check modes (HTTP, TCP, process, Docker container)
- **Notifications**: Support for Slack, Microsoft Teams, email, webhooks, and SMS
- **Dynamic Configuration**: Environment variable-based configuration
- **Monitoring Tools**: Built-in monitoring and testing scripts
- **Docker-based**: Easy deployment and management
- **Multi-platform**: Supports ARM64 and AMD64 architectures
- **Comprehensive Logging**: Detailed logs for troubleshooting

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Docker Network                       │
│                   (172.20.0.0/16)                       │
│                                                         │
│  ┌──────────────────┐         ┌──────────────────┐      │
│  │  Master Node     │         │  Backup Node     │      │
│  │  172.20.0.10     │◄───────►│  172.20.0.11     │      │
│  │  Priority: 100   │  VRRP   │  Priority: 90    │      │
│  └────────┬─────────┘         └────────┬─────────┘      │
│           │                             │               │
│           └──────────┬──────────────────┘               │
│                      │                                  │
│              ┌───────▼────────┐                         │
│              │  Virtual IP    │                         │
│              │  172.20.0.100  │                         │
│              └───────┬────────┘                         │
│                      │                                  │
│              ┌───────▼────────┐                         │
│              │  Application   │                         │
│              │  172.20.0.50   │                         │
│              └────────────────┘                         │
└─────────────────────────────────────────────────────────┘
```

## 📦 Prerequisites

### Required Software

- **Docker**: Version 20.10 or higher
- **Docker Compose**: Version 2.0 or higher (or `docker compose` plugin)
- **Bash/ZSH**: For running management scripts
- **Git**: For cloning the repository

### System Requirements

- **CPU**: 2+ cores recommended
- **Memory**: 4GB+ RAM
- **Disk**: 10GB+ free space
- **OS**: Linux, macOS, or Windows with WSL2

### Platform-Specific Notes

#### macOS
- Docker Desktop or Colima/OrbStack
- Note: Host networking not supported on macOS Docker Desktop
- Uses bridge networking mode

#### Linux
- Native Docker installation
- Supports host networking and macvlan
- Best for production deployments

#### Windows
- Docker Desktop with WSL2 backend
- Uses bridge networking mode

## 🚀 Quick Start

### 1. Clone the Repository


### 2. Make Scripts Executable

```bash
chmod +x *.sh
```

### 3. Configure Environment (Optional)

Create a `.env` file:

```bash
cat > .env << 'EOF'
# Keepalived Configuration
KEEPALIVED_VIRTUAL_IP=172.20.0.100/16
KEEPALIVED_AUTH_PASS=SecPass01
KEEPALIVED_VIRTUAL_ROUTER_ID=51

# Health Check Configuration
HEALTH_CHECK_MODE=http
HEALTH_CHECK_URL=http://172.20.0.50:80
HEALTH_CHECK_TIMEOUT=3

# Notification Configuration
NOTIFICATION_METHODS=log,slack
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
EOF
```

### 4. Start the Cluster

```bash
./manage-keepalived.sh up
```

### 5. Verify Setup

```bash
./status.sh
```

## ⚙️ Configuration

### Environment Variables

#### Keepalived Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `KEEPALIVED_STATE` | `MASTER` | Initial state (MASTER/BACKUP) |
| `KEEPALIVED_PRIORITY` | `100` | Node priority (higher = preferred) |
| `KEEPALIVED_INTERFACE` | `eth0` | Network interface |
| `KEEPALIVED_VIRTUAL_ROUTER_ID` | `51` | VRRP router ID (1-255) |
| `KEEPALIVED_VIRTUAL_IP` | `172.20.0.100/16` | Virtual IP address |
| `KEEPALIVED_AUTH_PASS` | `SecPass01` | Authentication password (max 8 chars) |
| `ENABLE_HEALTH_CHECK` | `true` | Enable/disable health checks |

#### Health Check Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `HEALTH_CHECK_MODE` | `http` | Check mode (http/tcp/process/docker/all) |
| `HEALTH_CHECK_URL` | `http://localhost:8080/health` | HTTP endpoint to check |
| `HEALTH_CHECK_PORT` | `8080` | TCP port to check |
| `HEALTH_CHECK_TIMEOUT` | `3` | Timeout in seconds |
| `HEALTH_CHECK_PROCESS` | `nginx` | Process name to monitor |
| `HEALTH_CHECK_CONTAINER` | `app` | Docker container to check |
| `DISK_THRESHOLD` | `90` | Disk usage threshold (%) |
| `MEM_THRESHOLD` | `90` | Memory usage threshold (%) |

#### Notification Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `NOTIFICATION_METHODS` | `log` | Comma-separated list (log,slack,email,webhook,teams,sms) |
| `EMAIL_TO` | `admin@google.com` | Email recipient |
| `EMAIL_FROM` | `keepalived@google.com` | Email sender |
| `SLACK_WEBHOOK_URL` | - | Slack webhook URL |
| `WEBHOOK_URL` | - | Generic webhook URL |
| `TEAMS_WEBHOOK_URL` | - | Microsoft Teams webhook URL |
| `SMS_API_URL` | - | SMS API endpoint |
| `SMS_TO` | - | SMS recipient number |

### Network Configuration

Edit `docker-compose.yml` to customize network settings:

```yaml
networks:
  keepalived_net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
          gateway: 172.20.0.1
```

## 📖 Usage

### Management Script

The main management script provides all necessary operations:

```bash
./manage-keepalived.sh [COMMAND] [OPTIONS]
```

#### Available Commands

| Command | Description |
|---------|-------------|
| `up` | Build and start all services |
| `down` | Stop and remove all services |
| `start` | Start stopped services |
| `stop` | Stop running services |
| `restart` | Restart all services |
| `status` | Show service status |
| `logs [service]` | Show logs (optionally for specific service) |
| `exec <service> <cmd>` | Execute command in container |
| `validate` | Validate Keepalived configuration |
| `test-failover` | Test failover scenario |
| `cleanup` | Remove all containers, images, and volumes |
| `help` | Show help message |

#### Examples

```bash
# Start the cluster
./manage-keepalived.sh up

# View master logs
./manage-keepalived.sh logs keepalived-master

# View all logs in real-time
./manage-keepalived.sh logs

# Execute command in master
./manage-keepalived.sh exec keepalived-master ip addr show

# Test failover
./manage-keepalived.sh test-failover

# Stop everything
./manage-keepalived.sh down
```

### Quick Status Check

```bash
./status.sh
```

Output example:
```
Keepalived Status
════════════════════════════════════════
VIP Owner: MASTER (172.20.0.100)

Container Health:
  keepalived-master: Up 5 minutes (healthy)
  keepalived-backup: Up 5 minutes (healthy)

Network Info:
  Master IP: 172.20.0.10
  Backup IP: 172.20.0.11
  VIP: 172.20.0.100
```

## 🧪 Testing

### Comprehensive Test Suite

Run the full test suite:

```bash
./test-keepalived.sh
```

This will test:
1. Container status
2. Virtual IP assignment
3. Keepalived processes
4. Connectivity via VIP
5. State change logs
6. Failover scenario
7. Failback scenario

### Manual Testing

#### Test VIP Assignment

```bash
# Check master
docker exec keepalived-master ip addr show eth0 | grep 172.20.0.100

# Check backup
docker exec keepalived-backup ip addr show eth0 | grep 172.20.0.100
```

#### Test Connectivity

```bash
# From master
docker exec keepalived-master curl http://172.20.0.100

# From backup
docker exec keepalived-backup curl http://172.20.0.100

# From host (if using port mapping)
curl http://localhost:8080
```

#### Test Failover Manually

```bash
# 1. Stop master
docker stop keepalived-master

# 2. Wait 5 seconds
sleep 5

# 3. Check if backup has VIP
docker exec keepalived-backup ip addr show eth0 | grep 172.20.0.100

# 4. Restart master
docker start keepalived-master

# 5. Wait 5 seconds
sleep 5

# 6. Check if master reclaimed VIP
docker exec keepalived-master ip addr show eth0 | grep 172.20.0.100
```

## 📊 Monitoring

### View Logs

```bash
# Real-time logs for all services
docker compose logs -f

# Master logs only
docker logs -f keepalived-master

# Backup logs only
docker logs -f keepalived-backup

# Last 50 lines
docker logs --tail 50 keepalived-master
```

### Check Health

```bash
# Container health status
docker ps --format "table {{.Names}}\t{{.Status}}"

# Detailed health check
docker inspect keepalived-master | grep -A 10 Health

# Run health check manually
docker exec keepalived-master /usr/local/bin/check_service.sh
echo $?  # Should return 0 for success
```

### State Change Logs

```bash
# View state changes on master
docker exec keepalived-master cat /var/log/keepalived/state-changes.log

# View state changes on backup
docker exec keepalived-backup cat /var/log/keepalived/state-changes.log

# View health check logs
docker exec keepalived-master cat /var/log/keepalived/health-check.log
```

## 🔧 Troubleshooting

### Common Issues

#### 1. VIP Not Assigned

**Symptoms**: Neither master nor backup has the VIP

**Solutions**:
```bash
# Check Keepalived logs
docker logs keepalived-master

# Verify network interface
docker exec keepalived-master ip addr show

# Check VRRP configuration
docker exec keepalived-master cat /etc/keepalived/keepalived.conf

# Restart services
./manage-keepalived.sh restart
```

#### 2. Failover Not Working

**Symptoms**: Backup doesn't take over when master fails

**Solutions**:
```bash
# Check backup logs
docker logs keepalived-backup

# Verify priority settings
docker exec keepalived-backup cat /etc/keepalived/keepalived.conf | grep priority

# Check network connectivity
docker exec keepalived-backup ping -c 3 172.20.0.10

# Verify authentication password matches
docker exec keepalived-master cat /etc/keepalived/keepalived.conf | grep auth_pass
docker exec keepalived-backup cat /etc/keepalived/keepalived.conf | grep auth_pass
```

#### 3. Health Check Failing

**Symptoms**: Keepalived reports health check failures

**Solutions**:
```bash
# Test health check manually
docker exec keepalived-master /usr/local/bin/check_service.sh

# Check health check logs
docker exec keepalived-master cat /var/log/keepalived/health-check.log

# Verify health check URL
docker exec keepalived-master curl -v http://172.20.0.50:80

# Disable health check temporarily
# Edit docker-compose.yml and set ENABLE_HEALTH_CHECK=false
```

#### 4. Containers Not Starting

**Symptoms**: Containers exit immediately or fail to start

**Solutions**:
```bash
# Check Docker logs
docker logs keepalived-master

# Validate configuration
./manage-keepalived.sh validate

# Check for port conflicts
docker ps -a

# Rebuild images
./manage-keepalived.sh down
docker rmi custom-keepalived:latest
./manage-keepalived.sh up --build
```

#### 5. Permission Denied Errors

**Symptoms**: Script execution fails with permission errors

**Solutions**:
```bash
# Make scripts executable
chmod +x *.sh

# Check script permissions
ls -la *.sh

# Fix permissions in container
docker exec keepalived-master chmod +x /usr/local/bin/*.sh
```

### Debug Mode

Enable verbose logging:

```bash
# Edit docker-compose.yml and add to environment:
- LOG_LEVEL=DEBUG

# Or restart with debug flags
docker compose down
docker compose up --build
```

### Network Debugging

```bash
# Check network configuration
docker network inspect keepalived-ha_keepalived_net

# Test connectivity between containers
docker exec keepalived-master ping -c 3 keepalived-backup

# Check routing
docker exec keepalived-master ip route

# Capture VRRP packets (requires tcpdump)
docker exec keepalived-master tcpdump -i eth0 -n vrrp
```

## 🔐 Security Considerations

### Authentication

- Change default password in `.env` file
- Use strong passwords (max 8 characters due to VRRP limitation)
- Keep passwords consistent across all nodes

### Network Security

- Use private networks for VRRP traffic
- Implement firewall rules to restrict VRRP protocol (IP protocol 112)
- Consider using IPsec for VRRP authentication in production

### Container Security

- Run containers with minimal privileges
- Use read-only root filesystem where possible
- Regularly update base images
- Scan images for vulnerabilities

```bash
# Scan image for vulnerabilities
docker scan custom-keepalived:latest
```

## 🚀 Advanced Configuration

### Custom Health Checks

Create a custom health check script:

```bash
# custom-health-check.sh
#!/usr/bin/env bash

# Your custom logic here
if [ condition ]; then
    exit 0  # Healthy
else
    exit 1  # Unhealthy
fi
```

Add to `docker-compose.yml`:

```yaml
environment:
  - HEALTH_CHECK_MODE=custom
  - CUSTOM_HEALTH_CHECK_SCRIPT=/usr/local/bin/custom-health-check.sh
volumes:
  - ./custom-health-check.sh:/usr/local/bin/custom-health-check.sh:ro
```

### Multiple Virtual IPs

Edit `entrypoint.sh` to support multiple VIPs:

```bash
virtual_ipaddress {
    172.20.0.100/16
    172.20.0.101/16
    172.20.0.102/16
}
```

### Integration with Load Balancers

```yaml
services:
  nginx-lb:
    image: nginx:alpine
    networks:
      keepalived_net:
        ipv4_address: 172.20.0.50
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - keepalived-master
      - keepalived-backup
```

### Slack Notifications Setup

1. Create a Slack webhook:
   - Go to https://api.slack.com/apps
   - Create new app
   - Enable Incoming Webhooks
   - Copy webhook URL

2. Add to `.env`:
```bash
NOTIFICATION_METHODS=log,slack
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

3. Restart services:
```bash
./manage-keepalived.sh restart
```

### Email Notifications Setup

1. Install mail utilities in Dockerfile (already included)

2. Configure email settings:
```bash
NOTIFICATION_METHODS=log,email
EMAIL_TO=admin@google.com
EMAIL_FROM=keepalived@google.com
```

3. Configure SMTP relay (if needed):
```bash
# Add to docker-compose.yml
environment:
  - SMTP_HOST=smtp.office365.com
  - SMTP_PORT=587
  - SMTP_USER=your-email@google.com
  - SMTP_PASS=your-password
```

## 📁 Project Structure

```
keepalived-ha/
├── README.md                 # This file
├── Dockerfile               # Container image definition
├── docker-compose.yml       # Service orchestration
├── .env                     # Environment variables (create this)
├── .dockerignore           # Docker build exclusions
├── entrypoint.sh           # Container startup script
├── check_service.sh        # Health check script
├── notify.sh               # Notification script
├── manage-keepalived.sh    # Main management script
├── quick-start.sh          # Quick setup script
├── monitor.sh              # Monitoring script
├── test-keepalived.sh      # Test suite
├── status.sh               # Quick status check
├── check-network.sh        # Network interface checker
└── logs/                   # Log directory
    ├── master/             # Master node logs
    └── backup/             # Backup node logs
```

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup

```bash
# Clone your fork
git clone https://github.com/your-username/keepalived-ha.git
cd keepalived-ha

# Create feature branch
git checkout -b feature/my-feature

# Make changes and test
./manage-keepalived.sh up
./test-keepalived.sh

# Commit and push
git add .
git commit -m "Description of changes"
git push origin feature/my-feature
```

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


## 🔄 Changelog

### Version 2.0.0 (2024-01-XX)

- Added comprehensive health checking
- Multiple notification methods (Slack, Teams, Email, SMS)
- Enhanced monitoring scripts
- Improved error handling
- macOS compatibility
- Full test suite

### Version 1.0.0 (2024-01-XX)

- Initial release
- Basic Keepalived setup
- Docker Compose configuration
- Management scripts

## 🗺️ Roadmap

- [ ] Kubernetes deployment support
- [ ] Prometheus metrics exporter
- [ ] Grafana dashboards
- [ ] Ansible playbooks for bare-metal deployment
- [ ] Multi-region support
- [ ] Advanced load balancing integration
- [ ] Web UI for management

---