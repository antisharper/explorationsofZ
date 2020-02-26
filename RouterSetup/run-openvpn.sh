#!/bin/bash
OPENVPNCFG=${1:-testpi.ovpn}

while (true); do 
  date
  if [ -e /dev/shm/no-openvpn ]; then
    echo "... skip openvpn..."
    sleep 5
  else
    openvpn --config ${OPENVPNCFG} --script-security 2 --up /home/pi/up-ovpn.sh --down /home/pi/down-ovpn.sh 
    sleep 15
  fi
done
