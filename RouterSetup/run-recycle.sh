#!/bin/bash

CHECKURL=https://api.ipify.org
WAITTIME=1800
RECHECKTIME=299
DONTREBOOTFILE=/dev/shm/dontreboot

while getopts "c:w:r:" opt; do
  case "$opt" in
    c)  CHECKURL=$OPTARG
        ;;
    w)  WAITTIME=$OPTARG
        ;;
    r)  RECHECKTIME=$OPTARG
        ;;
    d)  DONTREBOOTFILE=$OPTARG
        ;;
  esac
done
shift $((OPTIND-1))

current_secs() {
    date +%s
}
echo "Init CHECKURL:$CHECKURL WAITTIME:$WAITTIME RECHECKTIME=$RECHECKTIME"

LASTGOOD=current_secs
while (true); do
  CURRENTIP=$(curl -s ${CHECKURL})

  if [ -z "$CURRENTIP" ]; then
    MISSEDTIME=(( $LASTGOOD-current_secs ))
    echo "`date +%Y%m%d-%H%M%S` - No Internet IP ($MISSEDTIME secs)"
    if (( $MISSEDTIME > $WAITTIME )); then
      echo "!!!!! Too many missed IP Checks.... Rebooting !!!!!" >&2
      if [ -e "$DONTREBOOTFILE" ]; then
        echo "!!!!! Skipping Reboot -- Dont reboot file $DONTREBOOTFILE exists !!!!!" >&2
      else
        reboot
      fi
    fi
  else
    LASTGOOD=current_secs
  fi

  sleep $RECHECKTIME
done
