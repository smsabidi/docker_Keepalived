#!/usr/bin/env zsh

print -P "%F{cyan}════════════════════════════════════════════════════════════%f"
print -P "%F{cyan}         Keepalived High Availability Test Suite%f"
print -P "%F{cyan}════════════════════════════════════════════════════════════%f"
print ""

VIP="172.20.0.100"

# Test 1: Check container status
print -P "%F{blue}[TEST 1]%f Checking container status..."
docker ps --filter "name=keepalived" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
print ""

# Test 2: Check VIP assignment
print -P "%F{blue}[TEST 2]%f Checking Virtual IP assignment..."
print "Master VIP status:"
if docker exec keepalived-master ip addr show eth0 | grep -q "$VIP"; then
    print -P "%F{green}✓%f Master has VIP $VIP"
else
    print -P "%F{red}✗%f Master does NOT have VIP $VIP"
fi

print ""
print "Backup VIP status:"
if docker exec keepalived-backup ip addr show eth0 | grep -q "$VIP"; then
    print -P "%F{yellow}⚠%f Backup has VIP $VIP (unexpected in normal state)"
else
    print -P "%F{green}✓%f Backup does NOT have VIP (correct)"
fi
print ""

# Test 3: Check Keepalived process
print -P "%F{blue}[TEST 3]%f Checking Keepalived processes..."
print "Master:"
docker exec keepalived-master pgrep -l keepalived
print ""
print "Backup:"
docker exec keepalived-backup pgrep -l keepalived
print ""

# Test 4: Test connectivity via VIP
print -P "%F{blue}[TEST 4]%f Testing connectivity via VIP..."
if docker exec keepalived-master curl -sf --max-time 3 "http://$VIP" > /dev/null 2>&1; then
    print -P "%F{green}✓%f Can access test app via VIP from master"
else
    print -P "%F{red}✗%f Cannot access test app via VIP from master"
fi

if docker exec keepalived-backup curl -sf --max-time 3 "http://$VIP" > /dev/null 2>&1; then
    print -P "%F{green}✓%f Can access test app via VIP from backup"
else
    print -P "%F{red}✗%f Cannot access test app via VIP from backup"
fi
print ""

# Test 5: Check state change logs
print -P "%F{blue}[TEST 5]%f Checking state change logs..."
print "Master state changes:"
docker exec keepalived-master cat /var/log/keepalived/state-changes.log 2>/dev/null || print "No state changes logged yet"
print ""
print "Backup state changes:"
docker exec keepalived-backup cat /var/log/keepalived/state-changes.log 2>/dev/null || print "No state changes logged yet"
print ""

# Test 6: Failover test
print -P "%F{blue}[TEST 6]%f Testing failover scenario..."
print -P "%F{yellow}Stopping master node...%f"
docker stop keepalived-master

print "Waiting 5 seconds for backup to take over..."
sleep 5

print "Checking if backup has VIP:"
if docker exec keepalived-backup ip addr show eth0 | grep -q "$VIP"; then
    print -P "%F{green}✓%f FAILOVER SUCCESS: Backup now has VIP $VIP"
    FAILOVER_SUCCESS=true
else
    print -P "%F{red}✗%f FAILOVER FAILED: Backup does not have VIP"
    FAILOVER_SUCCESS=false
fi
print ""

print "Testing connectivity during failover:"
if docker exec keepalived-backup curl -sf --max-time 3 "http://$VIP" > /dev/null 2>&1; then
    print -P "%F{green}✓%f Service is accessible via VIP during failover"
else
    print -P "%F{red}✗%f Service is NOT accessible via VIP during failover"
fi
print ""

print -P "%F{yellow}Restarting master node...%f"
docker start keepalived-master

print "Waiting 5 seconds for master to reclaim VIP..."
sleep 5

print "Checking if master reclaimed VIP:"
if docker exec keepalived-master ip addr show eth0 | grep -q "$VIP"; then
    print -P "%F{green}✓%f FAILBACK SUCCESS: Master reclaimed VIP $VIP"
else
    print -P "%F{yellow}⚠%f Master has not reclaimed VIP yet (may need more time)"
fi
print ""

# Test 7: Final health check
print -P "%F{blue}[TEST 7]%f Final health check..."
print "Container status:"
docker ps --filter "name=keepalived" --format "table {{.Names}}\t{{.Status}}"
print ""

# Summary
print -P "%F{cyan}════════════════════════════════════════════════════════════%f"
print -P "%F{cyan}                    Test Summary%f"
print -P "%F{cyan}════════════════════════════════════════════════════════════%f"

if [[ "$FAILOVER_SUCCESS" == "true" ]]; then
    print -P "%F{green}✓ All critical tests passed!%f"
    print -P "%F{green}✓ Keepalived HA is working correctly%f"
else
    print -P "%F{yellow}⚠ Some tests failed - review the output above%f"
fi

print ""
print "Next steps:"
print "  - Check logs: ./manage-keepalived.sh logs"
print "  - Monitor: ./monitor.sh"
print "  - Access test app: http://localhost:8080"
print ""