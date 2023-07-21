#!/bin/bash
WAITTIME=30
#while getopts "c:w:r:" opt; do
#  case "$opt" in
#    c)  CHECKURL=$OPTARG
#        ;;
#    w)  WAITTIME=$OPTARG
#        ;;
#    r)  REBOOTTIME=$OPTARG
#        ;;
#    d)  DONTREBOOTFILE=$OPTARG
#        ;;
#  esac
#done
#shift $((OPTIND-1))

current_secs() {
    date +%s
}

# echo "Init CHECKURL:$CHECKURL WAITTIME:$WAITTIME REBOOTTIME=$REBOOTTIME"

sleep 60

cd /home/pi
while (true); do

  #WLAN0IP=$(ifconfig wlan0 | grep inet | awk '{print $2}' | head -1):8443
  WLAN0IP=0.0.0.0:8443
  echo $(date +%Y%m%d-%H%M%S) "Starting Router.py on $WLAN0IP"
    python3 router.py --bindaddrport $WLAN0IP --debug


  sleep $WAITTIME
done

