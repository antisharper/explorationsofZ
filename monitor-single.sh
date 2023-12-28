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
	ps -ef | grep -Ev \(grep\|sudo\|run-\) | grep -E \(openvpn\)
	ps -ef | grep -Ev \(grep\|sudo\|run-\) | grep -E \(localhost:22\)
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

function netstat-nat() {
        echo "Proto   NATed Address     Destination Address      State "
        sudo conntrack -L -n 2>/dev/null | perl -nE '{chomp;if( $_ =~/(\w+) .* (\w+) src=(\d+.\d+.\d+.\d+) .* sport=(\d+) .* src=(\d+.\d+.\d+.\d+) .* sport=(\d+)/){print("$1 $3:$4 $5:$6 $2\n");}}'
}

function ipmasqstatus () {
	netstat-nat -n > /dev/shm/netstat-nat.out 
(	head -1 /dev/shm/netstat-nat.out
	tail -n +2 /dev/shm/netstat-nat.out > /dev/shm/netstat-nat.out.2 
	grep -Ev \(UNREPLIED\|CLOSE\|TIME\|FIN\|SYN\) /dev/shm/netstat-nat.out.2 | (readline -r 2>/dev/null; printf %s "$REPLY"; sort -k4,4 -k3,3n)
	grep CLOSE /dev/shm/netstat-nat.out.2 | (readline -r 2>/dev/null; printf %s "$REPLY"; sort -k4,4 -k3,3n)
	grep UNREPLIED /dev/shm/netstat-nat.out.2 | (readline -r 2>/dev/null; printf %s "$REPLY"; sort -k4,4 -k3,3n)
	grep -E \(TIME\|FIN\|SYN\) /dev/shm/netstat-nat.out.2 | (readline -r 2>/dev/null; printf %s "$REPLY"; sort -k4,4 -k3,3n) ) | \
          awk -vCOUNT=1 ' {if (DEBUG) {print ":::"$0}; CUR=$0;sub(/:[0-9]*/,"");UPD=$0;if (UPD != LAST) { if (LAST != "") {if (COUNT>1) {CNT=COUNT; sub(/:[0-9]*/,":*",WHOLELAST)} else { CNT=""}; print WHOLELAST " " CNT ; COUNT=1 }; LAST=UPD} else { COUNT+=1 }; WHOLELAST=CUR; if (NR==1) { WHOLELAST=WHOLELAST"      Count"}} END { if (COUNT>1) { CNT=COUNT; sub(/:[0-9]*/,":*",WHOLELAST) } else { CNT="" };print WHOLELAST " " CNT } ' | sed 's/ Addres/_Address/g' | awk '{printf ("%-5.5s %-21.21s %-21.21s %-12.12s %8.8s\n",$1,$2,$3,$4,$5) }'
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
  connect|c*)	header
  						linebreak
  						connectstatus
           		;;
  devices|d*)	header
  						linebreak
  						networkstatus
           		;;
  help|h*|\?)
cat <<EOF
Router Monitor
 Options:
    --connect|-c connect status
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
