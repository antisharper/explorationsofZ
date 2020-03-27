#!/bin/bash

PORT=${1:-2222}
WAITTIME=${2:-15}

while getopts "p:w:u:" opt; do
    case "$opt" in
    p)  PORT=$OPTARG
        ;;
    w)  WAITTIME=$OPTARG
        ;;
    u)  UPDATEACCOUNT=$OPTARG
        ;;
    esac
done
shift $((OPTIND-1))

if [ ! -z ${UPDATEACCOUNT} ]; then
  while (true); do
          echo ---- "Trying Connectivity" --- `date`
          ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -N -R ${PORT}:localhost:22 ${UPDATEACCOUNT}
          echo ---- "Connection failed ... Retrying in $WAITTIME seconds" --- `date`
    sleep $WAITTIME
  done
else
  echo " !!!! No upgrade connection specified... Terminating !!! "
  exit 1
fi
