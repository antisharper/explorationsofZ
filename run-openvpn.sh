#!/bin/bash

while (true); do 
  date
  if [ -e /dev/shm/no-openvpn ]; then
    echo "... skip openvpn..."
    sleep 5
  else
  	FOUNDVPNCFG=$(ls -1tr /home/pi/*.ovpn | head -1)
    openvpn --config ${FOUNDVPNCFG:-testpi.ovpn} --script-security 2 --up /home/pi/up-ovpn.sh --down /home/pi/down-ovpn.sh 
    sleep 15
  fi
done
