#!/bin/bash

HOGSFILE=/dev/shm/hogs.out
ROUTESNEW=/dev/shm/routelist.new
ROUTESFOUND=/dev/shm/routelist.FOUND
DISABLEFILE=/dev/shm/no-reroute

BWLIMIT=10
ERASELIMIT=10
HOGSDELAY=10
HOGSSAMPLES=1
WAITTIME=30
MAXCOUNT=3
VPNHOST="theharpers.homedns.org"

while getopts "b:s:d:w:m:e:g:hv" opt; do
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
    v)  DEBUG=1
        ;;
    h) cat <<EOF
 $0 [-b $BWLIMIT|-d $HOGSDELAY|-w $WAITTIME|-s $HOGSSAMPLES|-m $MAXCOUNT|-e $ERASEBWLIMIT]

	-b #    -- Bandwidth trigger over this amount add route to wlan for wlan1 (KBPS)
	-e #    -- Erase route if bandwidth falls below this level (KBPS)
        -w #    -- Time to wait between test cycles
        -m #    -- Number of cycle to wait before trigger route removals
        -d #    -- How long to sample traffic
        -s #    -- Numbre of traffic samples	
	-g fqdn -- VPN Service HostName
	-v      -- Enable DEBUG Output
	-h      -- This HELP message

        Program runs continuously.

EOF
	exit 1
	;;
  esac
done
shift $((OPTIND-1))

if [ -z "$ERASEBWLIMIT" ]; then ERASEBWLIMIT=$BWLIMIT; fi

if [ ! -z "$DEBUG" ]; then echo ERASEBWLIMIT:$ERASEBWLIMIT MAXCOUNT:$MAXCOUNT WAITTIME:$WAITTIME BWLIMIT:$BWLIMIT HOGSDELAY:$HOGSDELAY HOGSSAMPLES:$HOGSSAMPLES VPNHOST:$VPNHOST; fi

COUNT=1

while (true); do
	TUNIPMATCH=$(ip route | grep -v link | awk '/tun0/ {print $(NF-2)}' | head -1 | sed 's/\.[^\.]$/\\\./')
	LOCALNET=$(ip route | awk '/wlan0/ {print $(NF-2)}' | sed 's/\.[^\.]$/./')
	#VPNGATEWAY=$(ip route | grep wlan1 | grep -v metric | head -1 | awk '{print $1}')
	VPNGATEWAY=$(host ${VPNHOST} | awk '{print $NF}')
	UPLINK=$(ip route | grep wlan1 | grep -v metric | head -1 | awk '{print $3}')
	ULIPMATCH=$(echo $UPLINK | sed 's/\.[^\.]$/\\\./')
	if [ ! -z "$DEBUG" ]; then echo LOCALNET:$LOCALNET TUNIPMATCH:$TUNIPMATCH VPNGATEWAY:$VPNGATEWAY UPLINK:$UPLINK ULIPMATCH:$ULIPMATCH; fi

	if [ ! -z "$TUNIPMATCH" ]; then

		echo `date` Get NetHogs Sample CNT:$COUNT
		sudo nethogs -t -d $HOGSDELAY -c $[HOGSSAMPLES+1] 2>/dev/null | grep -- - | sed '/0\x090\x2e0/d;s/-/\t/g;s/:[0-9\/]*//g' | awk '$4 > '$ERASEBWLIMIT > $HOGSFILE 
		if [ ! -z "$DEBUG" ]; then awk '{printf("\t\t\t\t\t%s\n",$0)}' $HOGSFILE; fi

		if [ ! -s $HOGSFILE ]; then (( COUNT = COUNT + 1 )); fi

		if [ $COUNT -gt $MAXCOUNT ] || [ -s $HOGSFILE ]; then 
			COUNT=1

			echo `date` -- Process for Active Connections Limit:$ENABLEBWLIMIT $UPLIPMATCH $ROUTESNEW $LOCALNET
			rm $ROUTESNEW &>/dev/null
			awk '$4 > '$BWLIMIT' && $1!~/'$ULIPMATCH'/ {print $2}' $HOGSFILE | grep -v "$LOCALNET" | sort -u > $ROUTESNEW 
			if [ -s $ROUTESNEW ]; then
				echo `date` -- Update new re-routes 
				if [ ! -z "$DEBUG" ]; then awk '{printf("\t\t\t\t\t%s\n",$0)}' $ROUTESNEW; fi
				cat $ROUTESNEW | while read NEWROUTE; do 
					if ! ip route | grep "$NEWROUTE " &>/dev/null; then 
						echo `date` -----  Didnot find $NEWROUTE... Adding it to $UPLINK
						if [ -x $DISABLEFILE ]; then 
							echo `date` --- \!\!\!\! DISABLED - NO REROUTING
						else
							sudo ip route add $NEWROUTE via $UPLINK
						fi
					else
						echo `date` -----  $NEWROUTE aleady in reroute list
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
						if [ -x $DISABLEFILE ]; then 
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
