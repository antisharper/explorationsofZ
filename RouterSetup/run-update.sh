#!/bin/bash

PORT=2222
WAITTIME=-15

while getopts "p:w:" opt; do
    case "$opt" in
    p)  PORT=$OPTARG
        ;;
    w)  WAITTIME=$OPTARG
        ;;
    esac
done
shift $((OPTIND-1))

if [ ! -z ${UPDATEACCOUNT} ]; then
  while (true); do
          echo ---- "Trying Connectivity" --- `date`
    -u pi ssh -o ConnectTimeout=30 -N -R ${PORT}:localhost:22 ${UPDATEACCOUNT}
          echo ---- "Connection failed ... Retrying in $WAITTIME seconds" --- `date`
    sleep $WAITTIME
  done
else
  echo " !!!! No upgrade connection specified... Terminating !!! "
  exit 1
fi
