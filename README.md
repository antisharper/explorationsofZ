# RouterSetup - Raspberry PI (Zero/3/4) - Wireless Router and AP with OpenVPN

Based on https://www.raspberrypi.org/documentation/configuration/wireless/access-point.md,
         https://pimylifeup.com/raspberry-pi-wireless-access-point/,
     and https://gist.github.com/dmytro/0606cb32e42fc0918466


## Simple script taking a bare OS on Raspberry PI 0/3/4 to a fully working Wireless-to-Wireless Router/AP with OpenVPN Client.

### Using PI Zero and External USB 2.0 WiFi Adapter is easily capable of handling
- 1080p video stream
- RDP/NoMachine sessions to desktops
- Mundane browsing/APP needs.

Currently no web/gui controls for status

With 10000 AHr battery a PI Zero W can run for 2 days.

### Prerequisites:
1. PI of your choosing (Zero for easy portable deployments)
2. Minimum 4GB SD card.
3. Base Raspian Buster install.
4. External USB Wifi Device
 - Any Cheap USB Wifi will do, better performance on better HW
5. USB Micro to USB 2.0 extender.
6. PI must have an internet connection to get needed files, with connected ethernet or WiFi.
  - __Note:__ For wifi setup on a clean system use ```sudo raspi-config``` and Setup WIFI with ```Networking Options``` and ```Wi-fi SSID```
7. OpenVPN Config file with ```<key></key>```,```<cert></cert>```, and ```<ca></ca>``` items in the ovpn file.
 - __Note:__ I use *easy-rsa* scripts at https://gist.github.com/dmytro/0606cb32e42fc0918466 to build these for client.

### Setup
On PI (with Internet Connection):
1. Login to pi account.
2. Download this repo ```git clone https://github.com/antisharper/explorationsofZ.git```
3. Download you OpenVPN config (.ovpn) into /home/pi. ```scp myaccount@mysourceserver:myconfig.ovpn .```
4. Run install script. ```cd /home/pi; sudo explorationsofZ/RouterSetup.sh```  
- Answer prompts and after 3 reboots you'll have a working all wireless AP to Router with openvpn service.
- __Note__ Write down your passwords for the Direct access to the PI and the PI's AccessPoint

### Optional fun:
####  Router status -> Wire LED to pin 17 for router status:
- **OFF**         < External Wireless device is not connected/detect
- **Short Pulse** < External Wireless is not associated to an AP / Doesn't have IP
- **Slow Blink**  < External Wireless cannot access internet and VPN connection is not up.
- **Fast Blink**  < VPN Connection is up but not internet is available from the VPN
- **Long Pulse**  < Internet is available but VPN is down/disabled
- **ON**          < Internet available and VPN is up -> You're Secure!

#### Switch to Control VPN Connection -> Wire switch to pin 21.
- Hold Switch for 1/2 second to toggle status of VPN (file /dev/shm/no-openvpn is created/removed). This stops and starts the OPENVPN connection.

## Future
- [ ] Web Status
- [ ] Web Controls
- [ ] Support Wireguard
- [ ] Better Supprot for 802.11 g/n/a/c External Wireless connectors
- [ ] Better Support for g/n on internal wirless
- [ ] Support ETH0 as either internet source or clients.
