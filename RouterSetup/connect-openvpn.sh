#!/bin/bash
echo "Connect OPENVPN"
ps -ef | grep openvpn | grep config | grep ovpn |grep -v grep | awk '{print $2}' | xargs kill 2>/dev/null
rm /dev/shm/no-openvpn
