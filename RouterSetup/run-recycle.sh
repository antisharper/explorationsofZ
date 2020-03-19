#!/bin/bash

CHECKURL=https://api.ipify.org
WAITTIME=299
REBOOTTIME=1800
DONTREBOOTFILE=/dev/shm/dontreboot

while getopts "c:w:r:" opt; do
  case "$opt" in
    c)  CHECKURL=$OPTARG
        ;;
    w)  WAITTIME=$OPTARG
        ;;
    r)  REBOOTTIME=$OPTARG
        ;;
    d)  DONTREBOOTFILE=$OPTARG
        ;;
  esac
done
shift $((OPTIND-1))

current_secs() {
    date +%s
}
echo "Init CHECKURL:$CHECKURL WAITTIME:$WAITTIME REBOOTTIME=$REBOOTTIME"

LASTGOOD=$(current_secs)
while (true); do
  CURRENTIP=$(curl -s --connect-timeout 5 ${CHECKURL})

  if [ -z "$CURRENTIP" ]; then
    MISSEDTIME=$[$(current_secs)-LASTGOOD]
    echo "`date +%Y%m%d-%H%M%S` - No Internet IP ($MISSEDTIME secs)"
    if (( $MISSEDTIME > $REBOOTTIME )); then
      echo "!!!!! Too many missed IP Checks.... Rebooting !!!!!" >&2
      if [ -e "$DONTREBOOTFILE" ]; then
        echo "!!!!! Skipping Reboot -- Dont reboot file $DONTREBOOTFILE exists !!!!!" >&2
      else
        reboot
      fi
    fi
  else
    LASTGOOD=$(current_secs)
  fi

  sleep $WAITTIME
done
