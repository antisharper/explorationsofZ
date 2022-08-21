#!/bin/bash

HOGSFILE=/dev/shm/hogs.out
ROUTESNEW=/dev/shm/routelist.new
ROUTESFOUND=/dev/shm/routelist.FOUND
DISABLEFILE=/dev/shm/no-reroute

BWLIMIT=75
ERASEBWLIMIT=10
HOGSDELAY=10
HOGSSAMPLES=1
TOTALSLEEPTIME=120
WAITTIME=$[TOTALSLEEPTIME-(HOGSDELAY*HOGSSAMPLES)]
MAXCOUNT=3
INTERFACE=wlan1
TUNDEV=tun0
VPNHOST="theharpers.homedns.org"

BOLDSTART="\e[1m"
BOLDEND="\e[0m"

while getopts "b:s:d:w:m:e:g:i:t:hv" opt; do
  case "$opt" in
    b)  BWLIMIT=$OPTARG
        ;;
    w)  WAITTIME=$OPTARG
        ;;
    d)  HOGSDELAY=$OPTARG
        ;;
    s)  HOGSSAMPLES=$OPTARG
        ;;
    m)  MAXCOUNT=$OPTARG
        ;;
    e)  ERASEBWLIMIT=$OPTARG
        ;;
    g)  VPNHOST=$OPTARG
        ;;
    t)  INTERFACE=$OPTARG
				;;
    t)  TUNDEV=$OPTARG
    		;;
    v)  DEBUG=1
        ;;
    h) cat <<EOF
 $0 [-t TUNDEV|-b BWLIMIT|-e ERASEBWLIMIT|-w WAITTIME|-m MAXCOUNT|-d HOGSDELAY|-s HOGSSAMPLES|-g VPNHOST]
 
       Reduce VPN traffic by automatically find heavily used IP (> BWLIMIT) over tunnel ($TUNDEV) and add routes directly over $INTERFACE gateway. 
       When added route usage goes back below ERASEBWLIMIT, remove these routes so trafic goes over VPN again.

			 Program runs continuously.

  -t dev  -- Tunnel device ($TUNDEV)
  -b #    -- Bandwidth trigger over this amount add route to wlan for $INTERFACE (KBPS) ($BWLIMIT)
  -e #    -- Erase route if bandwidth falls below this level (KBPS) ($ERASEBWLIMIT)
  -w #    -- Time to wait between test cycles ($WAITTIME)
  -m #    -- Number of cycles to wait before forced route removals ($MAXCOUNT)
  -d #    -- How long to sample traffic ($HOGSDELAY)
  -s #    -- Numbre of traffic samples	($[HOGSSAMPLES + 1])
  -g fqdn -- VPN Service HostName ($VPNHOST)
  -v      -- Enable DEBUG Output
  -h      -- This HELP message

EOF
	exit 1
	;;
  esac
done
shift $((OPTIND-1))

if [ -z "$ERASEBWLIMIT" ]; then ERASEBWLIMIT=$BWLIMIT; fi

echo `date` +++ BWLIMIT:$BWLIMIT ERASEBWLIMIT:$ERASEBWLIMIT WAITTIME:$WAITTIME MAXCOUNT:$MAXCOUNT HOGSDELAY:$HOGSDELAY HOGSSAMPLES:$HOGSSAMPLES VPNHOST:$VPNHOST TUNDEV:$TUNDEV INTERFACE:$INTERFACE

COUNT=1

while (true); do
	TUNIPMATCH=$(ip route | grep -v link | awk '/'$TUNDEV'/ {print $(NF-2)}' | head -1 | sed 's/\.[^\.]$/\\\./')
	LOCALNET=$(ip route | awk '/wlan0/ {print $(NF-2)}' | sed 's/\.[^\.]$/./')
	#VPNGATEWAY=$(ip route | grep $INTERFACE | grep -v metric | head -1 | awk '{print $1}')
	VPNGATEWAY=$(host ${VPNHOST} | awk '{print $NF}')
	UPLINK=$(ip route | grep $INTERFACE | grep default | head -1 | awk '{print $3}')
	ULIPMATCH=$(echo $UPLINK | sed 's/\.[^\.]$/\\\./')
	if [ ! -z "$DEBUG" ]; then echo `date` LOCALNET:$LOCALNET TUNIPMATCH:$TUNIPMATCH VPNGATEWAY:$VPNGATEWAY UPLINK:$UPLINK ULIPMATCH:$ULIPMATCH; fi

	if [ ! -z "$TUNIPMATCH" ]; then

		echo `date` Get NetHogs Sample CNT:$COUNT
		sudo nethogs -t -d $HOGSDELAY -c $[HOGSSAMPLES+1] 2>/dev/null | grep -- - | sed '/0\x090\x2e0/d;s/-/\t/g;s/:[0-9\/]*//g' | awk '$4 > '$ERASEBWLIMIT > $HOGSFILE 
		if [ ! -z "$DEBUG" ]; then awk '{printf("\t\t\t\t\t%s\n",$0)}' $HOGSFILE; fi

		if [ ! -s $HOGSFILE ]; then (( COUNT = COUNT + 1 )); fi

		if [ $COUNT -gt $MAXCOUNT ] || [ -s $HOGSFILE ]; then 
			COUNT=1

			echo `date` -- Process for Active Connections Limit:$BWLIMIT UPLIPMATCH:$ULIPMATCH ROUTESNEW:$ROUTESNEW LOCALNET:$LOCALNET
			rm $ROUTESNEW &>/dev/null
			awk '$4 > '$BWLIMIT' && $1!~/'$ULIPMATCH'/ {print $2}' $HOGSFILE | grep -v "$LOCALNET" | sort -u > $ROUTESNEW 
			if [ -s $ROUTESNEW ]; then
				echo `date` -- Update new re-routes 
				if [ ! -z "$DEBUG" ]; then awk '{printf("\t\t\t\t\t%s\n",$0)}' $ROUTESNEW; fi
				cat $ROUTESNEW | while read NEWROUTE; do 
					if ! ip route | grep "$NEWROUTE " &>/dev/null; then 
						echo `date` -----  Didnot find wlan1 route to $NEWROUTE... Adding it to $UPLINK
						if [ -e $DISABLEFILE ]; then 
							echo `date` --- \!\!\!\! DISABLED - NO REROUTING
						else
							sudo ip route add $NEWROUTE via $UPLINK
						fi
					else
						echo `date` -----  $NEWROUTE already in reroute list
					fi
				done
			fi	

			ip route | grep -v $VPNGATEWAY | grep -v metric | grep "via $UPLINK " | awk '{print $1}' > $ROUTESFOUND
			if [ -s $ROUTESFOUND ]; then
				echo `date` -- Remove unused re-routes 
				grep -vFf $ROUTESNEW $ROUTESFOUND |  while read FOUNDROUTE; do 
					echo `date` ----- FOUNDROUTE $FOUNDROUTE
					#grep $FOUNDROUTE $HOGSFILE
					if ! grep $FOUNDROUTE $HOGSFILE &>/dev/null; then 
						echo `date` --------  Remove low BW route $FOUNDROUTE
						if [ -e $DISABLEFILE ]; then 
							echo `date` --- \!\!\!\! DISABLED - NO REROUTING
						else
							sudo ip route del $FOUNDROUTE
						fi
					fi
				done
			fi

		fi

	fi

	echo `date` - WAITTIME $WAITTIME
	sleep $WAITTIME
done
