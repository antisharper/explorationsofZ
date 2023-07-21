#!/bin/bash

WAITTIME=${1:-15}
while (true); do
  echo ---- "Running Button Watcher" --- `date`
  python3 /home/pi/Button-OpenVPN.py 
  echo ---- "Restarting Button Watcher in $WAITTIME seconds" --- `date`
  sleep $WAITTIME
done
