#!/usr/bin/bash

NEWHOST=
NEWNETWORK=
NEWAP=
NEWAPPW=
NEWCONNECTPORT=
NEWSSHHOSTKEY=
NEWSSHKEY=
NEWCHANNEL=

BOLDSTART="\e[1m"
BOLDEND="\e[0m"

if [ -z "$1" ]; then
  echo -e "$BOLDSTART$0$BOLDEND [-h Host_Name|-n Network_Octet#|-a AP_NAME|-p AP_PASSWORD|-c Remote_Port#|-b AP Channel#|-k|-s]"
	cat <<EOF
  -h new_host_name   -- New Host Name for This Router
  -n new_3rd_octect# -- New 3rd Octect 192.168.XX.1 for Router Access Point Network (R = random)
  -a new_ap_name     -- New Name for Router Access Point
  -p new_password    -- New Access Point Password
	-c New_port#       -- New Remote Connection Port for Router for Updates (R - random)
  -b New AP Channel# -- New Acce4ss Point Broadcast Channel # (1-11 bgn|other# a or ax) (R = random)
  -u                 -- Update SSH key (and display new pub Key) 
  -k                 -- Rebuild Routers SSH Host Keys
EOF

	exit 0
fi

while getopts "h:n:a:p:c:b:ks" opt; do
  case "$opt" in
    h)  NEWHOST=$OPTARG
        ;;
    n)  if echo $OPTARG | grep -i R &>/dev/null; then
    			NEWNETWORK=127
    			while [[ "$NEWNETWORK" =~ ^(127|128|137|97|0|1)$ ]]; do
    				NEWNETWORK=192.168.$(( ( RANDOM % 256 ) ))
    			done
    		else
    			NEWNETWORK=192.168.$OPTARG
    		fi
        ;;
    a)  NEWAP=$OPTARG
        ;;
    p)  NEWAPPW=$OPTARG
        ;;
    c)  if echo $OPTARG | grep -i R &>/dev/null; then
    			NEWCONNECTIONPORT=12245
    			while [[ "$NEWCONNECTIONPORT" =~ 12245|12255|12386 ]]; do
    				NEWCONNECTIONPORT=$(( ( RANDOM % 1000 ) + 12000))
    			done
    		else
    			NEWCONNECTPORT=$OPTARG
    		fi
        ;;
    b)  if echo $OPTARG | grep -i R &>/dev/null; then
    			NEWCHANNEL=$(( ( RANDOM % 11 ) + 1))
    		else
    			NEWCHANNEL=$OPTARG
    		fi
    		;;
    k)  NEWSSHHOSTKEY=1
        ;;
    s)  NEWSSHKEY=1
        ;;
  esac
done
shift $((OPTIND-1))

if [ ! -z "$NEWHOST" ]; then
  echo -e "Updating Hostname to ${BOLDSTART}$NEWHOST${BOLDEND} (was $(hostname))"
	sudo hostname $NEWHOST
	echo $NEWHOST| sudo tee /etc/hostname &>/dev/null
	sudo sed -i '/127.0.1.1/s/^.*$/127.0.1.1 '$NEWHOST'/' /etc/hosts &>/dev/null
  echo --------------
fi

if [ ! -z "$NEWSSHKEY" ]; then
  echo "Updating SSHKEY  (this will take a minute...)"
	printf "\ny\n" | ssh-keygen -q -b 4096 -t rsa -P ""; echo
	echo " --------- New PUB Key to add to conectivity account --------------- "
	cat ~/.ssh/id_rsa.pub
  echo --------------
fi

if [ ! -z "$NEWCONNECTPORT" ]; then
  echo -e "Updating Connectionport to ${BOLDSTART}${NEWCONNECTPORT}${BOLDEND}"
	sudo sed -i 's/-p 12[0-9]* /-p '${NEWCONNECTPORT}' /' /home/pi/rc.nohup.ap
	ps -ef | grep -v grep | grep "localhost:22" | awk '{print $2}' | sudo xargs kill -9 &>/dev/null
	ps -ef | grep -v grep | grep "run-update" | awk '{print $2}' | sudo xargs kill -9 &>/dev/null
	grep run-update rc.nohup.ap > /tmp/new-run.sh
	sudo bash /tmp/new-run.sh
	rm -rf /tmp/new-run.sh
	echo --------------
fi

if [ ! -z "$NEWSSHHOSTKEY" ]; then
  echo -e "Updating SSH HOST KEY"
	sudo rm -r /etc/ssh/ssh*key
	sudo dpkg-reconfigure openssh-server
	echo --------------
fi

if [ ! -z "$NEWNETWORK" ]; then
	echo -e "Updating base network to ${BOLDSTART}${NEWNETWORK}.1${BOLDEND}"
	sudo grep -RiE '192\.168\.[0-9]{,3}\.' /home/pi* /etc/* 2>/dev/null | grep -vE '192\.168\.[0|1]\.'  | grep -v '~' | grep -v :\# |  sed 's/:.*$//' | while read FILE; do sudo sed -i '/^[^#]/s/192.168.[0-9]*\./'$NEWNETWORK'./g' $FILE; done
	RESTARTHOSTAPD=1
	RESTARTOTHERS=1
	RECONNECTTOAP=1
  echo --------------
fi
	
if [ ! -z "$NEWAP" ]; then
  echo -e "Updating AP Name to ${BOLDSTART}${NEWAP}.1${BOLDEND}"
	sudo sed -i 's/^ssid=.*/ssid='$NEWAP'/g' /etc/hostapd/hostapd.conf
	RESTARTHOSTAPD=1
	RECONNECTTOAP=1
	echo --------------
fi

if [ ! -z "$NEWAPPW" ]; then
  echo -e "Updating AP Password to ${BOLDSTART}${NEWAPPW}.1${BOLDEND}"
	sudo sed -i 's/^wpa_passphrase=.*/wpa_passphrase='$NEWAPPW'/g' /etc/hostapd/hostapd.conf
	RESTARTHOSTAPD=1
	RECONNECTTOAP=1
	echo --------------
fi

if [ ! -z "$NEWCHANNEL" ]; then
  echo -e "Updating AP Channel to ${BOLDSTART}${NEWCHANNEL}.1${BOLDEND}"
	sudo sed -i 's/^channel=.*/channel='$NEWCHANNEL'/g' /etc/hostapd/hostapd.conf
	RESTARTHOSTAPD=1
	echo --------------
fi

if [ ! -z "$RECONNECTTOAP" ]; then
	echo -e "${BOLDSTART}****** Restarting AP Services, you will need to reconnect to AP ******${BOLDEND}"
fi
	
if [ ! -z "$RESTARTOTHERS" ]; then
	sudo systemctl restart dhcpcd
	sudo systemctl restart dnsmasq
fi
	
if [ ! -z "$RESTARTHOSTAPD" ]; then
	sudo systemctl restart hostapd
fi
