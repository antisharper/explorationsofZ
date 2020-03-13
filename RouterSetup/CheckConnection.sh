#!/bin/bash

LOCALDEVICE=wlan1
TUNDEVICE=tun0
CHECKURL=https://api.ipify.org:443
HOLDFILE=/dev/shm/tracerouteCheck.txt

while getopts "l:t:c:h:" opt; do
  case "$opt" in
    h)  HOLDFILE=$OPTARG
        ;;
    c)  CHECKURL=$OPTARG
        if [[ "$CHECKURL" !~ ":" ]]; then
          if [[ "$CHECKURL" =~ "https" ]]; then
            CHECKURL="${CHECKURL}:443"
          else
            CHECKURL="${CHECKURL}:80"
          fi
        fi
        ;;
    t)  TUNDEVICE=$OPTARG
        ;;
    l)  LOCALDEVICE=$OPTARG
        ;;
  esac
done
shift $((OPTIND-1))

> $HOLDFILE

PORT=`echo $CHECKURL | sed 's/^.*\/\///'| cut -d: -f2`
SITE=`echo $CHECKURL | sed 's/^.*\/\///'| cut -d: -f1`

# Cant find WLAN, RETURNVAL=0
if ! ifconfig $LOCALDEVICE >/dev/null 2>&1; then
  echo 0
  exit 1
fi

# WLAN does not have IP, RETURNVAL=1
if ! ifconfig $LOCALDEVICE | grep "inet " >/dev/null 2>&1; then
  echo 1
  exit 1
fi

VPNGATEWAY=$(ifconfig $TUNDEVICE 2>/dev/null | awk '/inet / {print $2}' | sed 's/\.[^\.]*$/.1/')

CURLINTERNETIP=$(timeout 5 curl -q $CHECKURL 2>/dev/null)

timeout 30 traceroute -n -T -p $PORT $SITE > $HOLDFILE 2>&1
TRACEERROR=$?

if [ ! -z "$CURLINTERNETIP" ]; then
  # On Internet
  RETURNVAL=4
else
  # Failed INTERNET
  RETURNVAL=2
fi

# Are WE on VPN
if [[  ! -z "$VPNGATEWAY" ]]; then
  if  grep $VPNGATEWAY $HOLDFILE >/dev/null 2>&1; then
    (( RETURNVAL=RETURNVAL+1 ))
  fi
fi

echo $RETURNVAL

# 0 - OFF    < No WLAN1
# 1 - Short Pulse < No Internet IP
# 2 - Slow Blink  < No Internet + NO VPN
# 3 - Fast Blink  < No Internet + VPN
# 4 - Long Pulse  < Internet + NO VPN
# 5 - ON    < Internet + VPN
