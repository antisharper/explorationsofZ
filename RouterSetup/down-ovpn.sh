#!/bin/bash
#env
echo "Down Options: $@"
/etc/openvpn/update-resolv-conf $@
iptables -t nat -F 
iptables -t nat -X 
iptables-restore < /home/pi/iptables.ipv4.nat
