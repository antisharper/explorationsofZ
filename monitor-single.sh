#!/bin/bash

# Check we're running as ROOT
if [[ $EUID -ne 0 ]]; then
   alertbanner "!!!! This script must be run as root !!!!"
   exit 1
fi

function header () {
	echo "$(hostname)   $(vcgencmd measure_temp)   Connection Status:$(cat /dev/shm/ledpattern.txt)"
	echo $(uptime) 
}

function openvpnstatus () {
	ls -ltr /dev/shm/no-openvpn 2>/dev/null
	ps -ef | grep -Ev \(grep\|sudo\|run-\) | grep -E \(localhost:22\|openvpn\)
}

function networkstatus () {
	echo -n Access Point:\ 
	sudo hostapd_cli -i wlan0 status | grep ^ssid | sed 's/.*=//'; ifconfig wlan0 2>/dev/null
	iwconfig wlan1 2>/dev/null
	ifconfig wlan1 2>/dev/null
	ifconfig tun0 2>/dev/null
	if ethtool eth0 2>/dev/null | grep Speed | grep -vi unknown; then ifconfig eth0 2>/dev/null; fi
}

function routestatus () {
	route -n
}

function iptablesstatus () {
	iptables -L -n -v | sed 's/       //g'
	linebreak
	iptables -t nat -L -n -v
}

function connectstatus () {
	netstat -tn | grep -E \(Address\|ESTAB\|CLOSE\|LISTEN\)
}

function ipmasqstatus () {
	netstat-nat -n > /dev/shm/netstat-nat.out 
	head -1 /dev/shm/netstat-nat.out
	tail -n +2 /dev/shm/netstat-nat.out > /dev/shm/netstat-nat.out.2 
	grep UNREPLIED /dev/shm/netstat-nat.out.2 | (readline -r 2>/dev/null; printf %s "$REPLY"; sort -k4,4 -k3,3n)
	grep -Ev \(UNREPLIED\|CLOSE\|TIME\|FIN\|SYN\) /dev/shm/netstat-nat.out.2 | (readline -r 2>/dev/null; printf %s "$REPLY"; sort -k4,4 -k3,3n)
	grep -E \(CLOSE\|TIME\|FIN\|SYN\) /dev/shm/netstat-nat.out.2 | (readline -r 2>/dev/null; printf %s "$REPLY"; sort -k4,4 -k3,3n)
}

function linebreak () {
	cat /tmp/lineout
}

WIDTH=40
while getopts "w:" opt; do
    case "$opt" in
    w)  WIDTH=$OPTARG
        ;;
    esac
done
shift $((OPTIND-1))

WIDTH=$(/usr/bin/tput cols)
(ARRAYIT=$(seq 1 $WIDTH); printf -- '*%.0s' ${ARRAYIT[@]}; echo) > /tmp/lineout

case "${1:-all}" in
  all)  header
  			linebreak
  			openvpnstatus
  			linebreak
  			networkstatus
  			linebreak
  			routestatus
  			linebreak
  			iptablesstatus
  			linebreak
  			connectstatus
  			linebreak
  			ipmasqstatus
      	;;
  nat|n*) header
  				linebreak
  				ipmasqstatus
          ;;
  iptables|i*)  header
  				linebreak
  				iptablesstatus
          ;;
  routes|r*)	header
  						linebreak
  						routestatus
           		;;
  openvpn|o*)	header
  						linebreak
  						openvpnstatus
           		;;
  devices|d*)	header
  						linebreak
  						networkstatus
           		;;
  help|h*|\?)
cat <<EOF
Router Monitor
 Options:
    --nat|-n Active Nat connections
    --iptables|-i iptable rules for Forward/Input/Ouptu and -t nat Masquerade
    --route|-r Route Table
    --openvpn|-o OpenVPN connection and Process
    --devices|-d ifconfig and iwconfig wlan information
    [none]  Old All lists (openvpn,devices,routes,iptables)
EOF
      exit 0
      ;;
esac
