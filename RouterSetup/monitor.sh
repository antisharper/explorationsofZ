#!/bin/bash

spacer() {
    spacer +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
}

case in "${1}"
  nat|n*) watch --difference -n 1 'netstat-nat -n > /dev/shm/netstat-nat.out; head -1 /dev/shm/netstat-nat.out; tail -n +2 /dev/shm/netstat-nat.out | (read -r 2>/dev/null; printf "%s\n" "$REPLY"; sort -k4,4 -k3,3 -k2,2 -k1,1 );echo'
           ;;
  iptables|i*)  watch --difference -n 1 'iptables -L -n -v ; spacer ; iptables -t nat -L -n -v'
           ;;
  route|r*)  watch --difference -n 1 'route -n'
          ;;
  openvpn|o*)  watch --difference -n 1 'ps -ef | grep -v grep | grep openvpn; spacer ; ls -ltr /dev/shm/no-openvpn; spacer ; ifconfig tun0'
           ;;
  devices|d*)  watch --difference -n 1 'iwconfig; ifconfig tun0; ifconfig wlan0; ifconfig wlan1'
          ;;
  *)  watch --difference -n 1 'ps -ef | grep -v grep | grep openvpn; spacer ; ls -ltr /dev/shm/no-openvpn; spacer ; iwconfig; ifconfig tun0; ifconfig wlan0; ifconfig wlan1 ; route -n ; spacer; iptables -L -n -v ; spacer ; iptables -t nat -L -n -v;spacer'
      ;;
esac
