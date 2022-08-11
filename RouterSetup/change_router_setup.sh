#!/usr/bin/bash

NEWHOST=
NEWNETWORK=
NEWAP=
NEWAPPW=
NEWCONNECTPORT=
NEWSSHHOSTKEY=
NEWCHANNEL=

if [ -z "$1" ]; then
	cat <<EOF
$0 [-h Host_Name|-n Network_Octet#|-a AP_NAME|-p AP_PASSWORD|-c Remote_Port#|-b AP Channel#|-k]
	
	-h new_host_name   -- New Host Name for This Router
	-n new_3rd_octect# -- New 3rd Octect 192.168.XX.1 for Router Access Point Network
	-a new_ap_name     -- New Name for Router Access Point
	-p new_password    -- New Access Point Password
	-c New_port#       -- New Remote Connection Port for Router for Updates
  -b New AP Channel# -- New Acce4ss Point Broadcast Channel # (1-11 bgn|other# a or ax)
	-k                 -- Rebuild Routers SSH Host Keys
EOF

	exit 0
fi

while getopts "h:n:a:p:c:b:k" opt; do
  case "$opt" in
    h)  NEWHOST=$OPTARG
        ;;
    n)  NEWNETWORK=192.168.$OPTARG
        ;;
    a)  NEWAP=$OPTARG
        ;;
    p)  NEWAPPW=$OPTARG
        ;;
    c)  NEWCONNECTPORT=$OPTARG
        ;;
    b)  NEWCHANNEL=$OPTARG
    		;;
    k)  NEWSSHHOSTKEY=1
    ;;
  esac
done
shift $((OPTIND-1))

if [ ! -z "$NEWHOST" ]; then
  echo Updating Hostname to $NEWHOST
	sudo hostname $NEWHOST
	echo $NEWHOST| sudo tee /etc/hostname &>/dev/null
	sudo sed -i '/127.0.1.1/s/^.*$/127.0.1.1 '$NEWHOST'/' /etc/hosts &>/dev/null
fi

if [ ! -z "$NEWCONNECTPORT" ]; then
  echo Updating Connectionport to ${NEWCONNECTPORT}
	sudo sed -i 's/-p 12[0-9]* /-p '${NEWCONNECTPORT}' /' /home/pi/rc.nohup.ap
	ps -ef | grep -v grep | grep "localhost:22" | awk '{print $2}' | sudo xargs kill -9
	ps -ef | grep -v grep | grep "run-update" | awk '{print $2}' | sudo xargs kill -9
	grep run-update rc.nohup.ap > /tmp/new-run.sh
	sudo bash /tmp/new-run.sh
	rm -rf /tmp/new-run.sh
fi

if [ ! -z "$NEWSSHHOSTKEY" ]; then
  echo Updating AP Password to ${NEWAPPW}.1
	sudo rm -r /etc/ssh/ssh*key
	sudo dpkg-reconfigure openssh-server
fi

if [ ! -z "$NEWNETWORK" ]; then
	echo Updating base network to ${NEWNETWORK}.1
	sudo grep -RiE '192\.168\.[0-9]{,3}\.' /home/pi* /etc/* 2>/dev/null | grep -vE '192\.168\.[0|1]\.'  | grep -v '~' | grep -v :\# |  sed 's/:.*$//' | while read FILE; do echo --------------- $FILE; sudo sed -i '/^[^#]/s/192.168.[0-9]*\./'$NEWNETWORK'./g' $FILE; done
	sudo systemctl restart dhcpcd
	sudo systemctl restart dnsmasq
	sudo systemctl restart hostapd
fi
	
if [ ! -z "$NEWAP" ]; then
  echo Updating AP Name to ${NEWAP}.1
	sudo sed -i 's/^ssid=.*/ssid='$NEWAP'/g' /etc/hostapd/hostapd.conf
	sudo systemctl restart hostapd
fi

if [ ! -z "$NEWAPPW" ]; then
  echo Updating AP Password to ${NEWAPPW}.1
	sudo sed -i 's/^wpa_passphrase=.*/wpa_passphrase='$NEWAPPW'/g' /etc/hostapd/hostapd.conf
	sudo systemctl restart hostapd
fi

if [ ! -z "$NEWCHANNEL" ]; then
  echo Updating AP Channel to ${NEWCHANNEL}.1
	sudo sed -i 's/^channel=.*/channel='$NEWCHANNEL'/g' /etc/hostapd/hostapd.conf
	sudo systemctl restart hostapd
fi
