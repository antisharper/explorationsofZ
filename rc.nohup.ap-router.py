#!/bin/bash
#
# NOHUP important AP Scripts
#

nohup /home/pi/down-ovpn.sh tun0 # By Default, force WLAN0 to MASQ all traffic thru WLAN1
nohup /home/pi/run-openvpn.sh &>/dev/shm/run-openvpn.out &
nohup /home/pi/run-checkConnect.sh -c "https://api.ipify.org" &>/dev/shm/run-checkConnect.out &
nohup /home/pi/run-ledpattern.sh &>/dev/shm/run-ledpattern.out &
nohup /home/pi/run-update.sh -r pi -p 12018 -u "connectivity@theharpers.homedns.org" &>/dev/shm/run-update.out &
nohup /home/pi/run-Button-OpenVPN.sh &>/dev/shm/run-button-openvpn.out &
nohup /home/pi/run-recycle.sh -c "https://api.ipify.org" &>/dev/shm/run-recycle.out &
nohup /home/pi/run-reroute.sh &>/dev/shm/run-reroute.out &
nohup /home/pi/run-router.sh &>/dev/shm/run-router.out &
echo 0 | tee /sys/class/leds/led0/brightness
