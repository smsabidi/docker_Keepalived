#!/usr/bin/env zsh

print -P "%F{cyan}Network Interfaces:%f"
print ""

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    ifconfig | grep -E "^[a-z]|inet " | grep -v "127.0.0.1"
else
    # Linux
    ip addr show | grep -E "^[0-9]|inet "
fi

print ""
print -P "%F{yellow}Common interface names:%f"
print "  - eth0, eth1 (Ethernet)"
print "  - en0, en1 (macOS Ethernet/WiFi)"
print "  - wlan0, wlan1 (WiFi)"
print "  - ens33, ens160 (VM interfaces)"
print ""
print -P "%F{blue}Update the HOST_INTERFACE variable in setup-macvlan.sh with your interface name%f"