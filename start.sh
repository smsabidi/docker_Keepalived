# Clean up any existing containers
./manage-keepalived.sh down

# Remove old images
docker rmi custom-keepalived:latest

# Start services
./manage-keepalived.sh up

# Check status
./manage-keepalived.sh status

# Check logs
./manage-keepalived.sh logs

# Check logs
./manage-keepalived.sh logs keepalived-master

# Verify VIP assignment
docker exec keepalived-master ip addr show eth0

# Test VIP from within network
docker exec keepalived-master ip addr show
docker exec keepalived-master ping -c 3 172.20.0.100

# Test failover
./manage-keepalived.sh test-failover







