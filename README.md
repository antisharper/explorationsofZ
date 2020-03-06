# RouterSetup - Raspberry PI (Zero/3/4) - Wireless Router and AP with OpenVPN

Based on https://www.raspberrypi.org/documentation/configuration/wireless/access-point.md,
         https://pimylifeup.com/raspberry-pi-wireless-access-point/,
     and https://gist.github.com/dmytro/0606cb32e42fc0918466


Single to run and take a Raspberry PI 0/3/4 to a fully working Wireless-to-wireless Router/AP with OpenVPN

Using PI Zero and External USB 2.0 network is all 802.11b based and easily capable of handling
 - 1080p video stream
 - RDP/NoMachine sessions to desktops
 - more orless more mundance networking needs.

Currently no web/gui controls or status - All command line for now

With 10000 AHr battery a PI-Zero can run for 1 day without issues.

## Pre-requisites:
1. PI of you choosing (Zero for tiny deployments)
2. External USB Wifi Device (Any Cheap USB Wifi will do, better performance on better HW)
3. USB Micro to USB 2.0 extender.
4. Base Raspian install.
5. Minimum 2GB SD microcard.
6. PI must have an internet connection to get needed files, with connected ethernet or WiFi.
   - __Note:__ For wifi setup, on clean system use ```sudo raspi-config``` and Setup WIFI Association with ```Networking Options``` and ```Wi-fi```
7. OpenVPN Config file with ```<key></key>```,```<cert></cert>```, and ```<ca></ca>``` items in the ovpn file.
   - __Note:__ I use https://gist.github.com/dmytro/0606cb32e42fc0918466

## Setup
On PI (with Internet Connection):
1. Login to pi account.
2. Download this repo ```git clone https://github.com/antisharper/explorationsofZ.git```
3. Download you OpenVPN config (.ovpn) into /home/pi. ```scp myaccount@mysourceserver:myconfig.ovpn .```
4. Run install script. ```cd /home/pi; sudo explorationsofZ/RouterSetup.sh```  
- Answer prompts and after 3 reboots you'll have a working all wireless AP to Router with openvpn service.
- __Note__ Write down your passwords for the Direct access to the PI and the PI's AccessPoint

## Additional fun (optional only):
###Router status -> Wire LED to pin 17 for router status:
- **OFF**         < External Wireless device is not connected/detect
- **Short Pulse** < External Wireless is not associated to an AP / Doesn't have IP
- **Slow Blink**  < External Wireless cannot access internet and VPN connection is not up.
- **Fast Blink**  < VPN Connection is up but not internet is available from the VPN
- **Long Pulse**  < Internet is available but VPN is down
- **ON**         < Internet available and VPN is up -> You're Secure!
###Switch to Control VPN Connection -> Wire switch to pin 21.
- Hold Switch for 1/2 second to toggle status of VPN (file /dev/shm/no-openvpn is created/removed)

## Future
- Web Status
- Web Controls
- Better Supprot for 802.11 g/n/a/c External Wireless connectors
- Better Support for g/n on internal wirless
- Support ETH0 as either internet source or clients.
