#!/bin/bash

watch --difference -n 1 'ps -ef | grep -v grep | grep openvpn; echo ; ls -ltr /dev/shm/no-openvpn; echo ; iwconfig; ifconfig tun0; ifconfig wlan0; ifconfig wlan1 ; route -n ; echo; iptables -L -n -v ; echo ; iptables -t nat -L -n -v;echo'
