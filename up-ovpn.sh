#!/bin/bash
#env
echo "OPTIONS $@"
/etc/openvpn/update-resolv-conf $@
iptables-restore < /home/pi/iptables.opv.nat
