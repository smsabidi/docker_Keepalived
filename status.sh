#!/usr/bin/env zsh

VIP="172.20.0.100"

print -P "%F{cyan}Keepalived Status%f"
print "════════════════════════════════════════"

# Check which node has VIP
if docker exec keepalived-master ip addr show eth0 2>/dev/null | grep -q "$VIP"; then
    print -P "VIP Owner: %F{green}MASTER%f ($VIP)"
elif docker exec keepalived-backup ip addr show eth0 2>/dev/null | grep -q "$VIP"; then
    print -P "VIP Owner: %F{yellow}BACKUP%f ($VIP)"
else
    print -P "VIP Owner: %F{red}NONE%f (VIP not assigned!)"
fi

print ""
print "Container Health:"
docker ps --filter "name=keepalived" --format "  {{.Names}}: {{.Status}}"

print ""
print "Network Info:"
print "  Master IP: $(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' keepalived-master)"
print "  Backup IP: $(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' keepalived-backup)"
print "  VIP: $VIP"

print ""
print "Quick Actions:"
print "  View logs:     docker logs keepalived-master"
print "  Test failover: ./test-keepalived.sh"
print "  Full status:   ./manage-keepalived.sh status"
