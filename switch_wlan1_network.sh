#!/bin/bash

NEWNETWORK=${1}
KILLOPEN=${2:-y}
SWITCHSLEEP=${3:-10}
WAITSLEEP=${4:-15}

echo Start TIme: $(date)
echo "  Current:"
sudo sudo wpa_cli -i wlan1 list_networks | sed 's/^/    /'
if [ -z "$NEWNETWORK" ]; then exit 0; fi

sudo wpa_cli -i wlan1 enable_network all  >/dev/null 2<&1
NEWNETWORK=$(sudo wpa_cli -i wlan1 list_networks | awk '/'$NEWNETWORK'/ {print $1}' | head -1)
sudo sudo wpa_cli -i wlan1 select_network $NEWNETWORK | sed 's/^/  Switch to network '$NEWNETWORK' >>>> /'
echo "  Waiting ${SWITCHSLEEP} seconds for WLAN to settle." ; sleep ${SWITCHSLEEP}
sudo wpa_cli -i wlan1 enable_network all | sed 's/^/   Re-enable Network Scans >>> /'
echo "  Updated:"
sudo wpa_cli -i wlan1 list_networks | sed 's/^/     /'
if [ ! -x /dev/shm/no-openvpn ]; then
	if [ "$KILLOPEN" == "y" ]; then
		echo "     Killing OPENVPN"
		ps -ef | grep openvpn | grep config | grep -v watch | awk '{print $2}' | sudo xargs -n1 kill -9 
        fi
	echo "  Waiting for OpenVPN to re-connect (Wait times $WAITSLEEP)"
	while ! ping -W 1 -c 1 192.168.1.1 >/dev/null 2>&1; do echo "  >>> $(date)"; sleep ${WAITSLEEP}; done
fi
echo Completed $(date)
