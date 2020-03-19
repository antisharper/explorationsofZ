#!/bin/bash

# Check we're running as ROOT
if [[ $EUID -ne 0 ]]; then
   alertbanner "!!!! This script must be run as root !!!!"
   exit 1
fi

case "${1:-all}" in
  all)  watch --difference -n 1 'ps -ef | grep -v grep | grep openvpn; echo -- ------- ; ls -ltr /dev/shm/no-openvpn; echo -- ------- ; iwconfig; ifconfig tun0; ifconfig wlan0; ifconfig wlan1 ; route -n ; echo -- -------; iptables -L -n -v ; echo -- ------- ; iptables -t nat -L -n -v;echo -- -------'
      ;;
  nat|n*) watch --difference -n 1 'netstat-nat -n > /dev/shm/netstat-nat.out; head -1 /dev/shm/netstat-nat.out; tail -n +2 /dev/shm/netstat-nat.out | (read -r 2>/dev/null; printf %s\n "$REPLY"; sort -k4,4 -k3,3 -k2,2 -k1,1 ); echo -- -------'
           ;;
  iptables|i*)  watch --difference -n 1 'iptables -L -n -v ; echo -- ------- ; iptables -t nat -L -n -v'
           ;;
  routes|r*)  watch --difference -n 1 'route -n'
          ;;
  openvpn|o*)  watch --difference -n 1 'ps -ef | grep -v grep | grep openvpn; echo -- ------- ; ls -ltr /dev/shm/no-openvpn; echo -- ------- ; ifconfig tun0'
           ;;
  devices|d*)  watch --difference -n 1 'iwconfig; ifconfig tun0; ifconfig wlan0; ifconfig wlan1'
          ;;
  --help|-h*|-\?)
cat <<EOF
Router Monitor

 Options:
    --nat|-n Active Nat connections
    --iptables|-i iptable rules for Forward/Input/Ouptu and -t nat Masquerade
    --route|-r Route Table
    --openvpn|-o OpenVPN connection and Process
    --devices|-d ifconfig and iwconfig wlan information
    [none]  Old All lists (openvpn,devices,routes,iptables)
EOF
      exit 0
      ;;
esac
