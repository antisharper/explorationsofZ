#!/bin/bash

# Check we're running as ROOT
if [[ $EUID -ne 0 ]]; then
   alertbanner "!!!! This script must be run as root !!!!"
   exit 1
fi

CHECKTIME=5

case "${1:-all}" in
  all)  watch --difference -n ${CHECKTIME} 'echo Router: $(hostname) $(vcgencmd measure_temp) Connection Status:$(cat /dev/shm/ledpattern.txt) ---- $(uptime); echo -- ------; ps -ef | grep -v grep | grep openvpn; ls -ltr /dev/shm/no-openvpn 2>/dev/null; echo -- ------- ; echo -n Access Point:\ ; sudo hostapd_cli -i wlan0 status | grep ^ssid | sed 's/.*=//'; ifconfig wlan0 2>/dev/null; iwconfig wlan1 2>/dev/null; ifconfig wlan1 2>/dev/null; ifconfig tun0 2>/dev/null; if ethtool eth0 2>/dev/null | grep Speed | grep -vi unknown; then ifconfig eth0 2>/dev/null; fi ; echo -- -------; route -n ; echo -- -------; iptables -L -n -v ; echo -- ------- ; iptables -t nat -L -n -v; echo -- ------; netstat -tn | grep -E \(Address\|ESTAB\|CLOSE\|LISTEN\); echo -- ------- ; netstat-nat -n > /dev/shm/netstat-nat.out; head -1 /dev/shm/netstat-nat.out; tail -n +2 /dev/shm/netstat-nat.out | grep -E \(ASSURED\|ESTABLISHED\|CLOSE\|REPLIED\) | (read -r 2>/dev/null; printf %s "$REPLY"; sort -k4,4 -k3,3)'
      ;;
  nat|n*) watch --difference -n ${CHECKTIME} 'netstat-nat -n > /dev/shm/netstat-nat.out; head -1 /dev/shm/netstat-nat.out; tail -n +2 /dev/shm/netstat-nat.out | grep -E \(ASSURED\|ESTABLISHED\) | (read -r 2>/dev/null; printf %s "$REPLY"; sort -k4,4 -k3,3 -k2,2 -k1,1 ); tail -n +2 /dev/shm/netstat-nat.out | grep -vE \(ASSURED\|ESTABLISHED\) | (read -r 2>/dev/null; printf %s "$REPLY"; sort -k4,4 -k3,3 -k2,2 -k1,1 ); echo -- -------; netstat -tn | grep -E \(ESTAB\|CLOSE\|LISTEN\)'
           ;;
  iptables|i*)  watch --difference -n ${CHECKTIME} 'iptables -L -n -v ; echo -- ------- ; iptables -t nat -L -n -v'
           ;;
  routes|r*)  watch --difference -n ${CHECKTIME} 'route -n'
          ;;
  openvpn|o*)  watch --difference -n ${CHECKTIME} 'ps -ef | grep -v grep | grep openvpn; echo -- ------- ; ls -ltr /dev/shm/no-openvpn; echo -- ------- ; ifconfig tun0'
           ;;
  devices|d*)  watch --difference -n ${CHECKTIME} 'iwconfig; ifconfig tun0; sudo hostapd_cli -i wlan0 status | grep ^ssid | sed 's/.*=//'; ifconfig wlan0; ifconfig wlan1'
          ;;
  help|h*|\?)
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
