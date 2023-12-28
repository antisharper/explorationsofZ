#!/bin/bash

while (true); do
  bash /home/pi/CheckConnection.sh | tee  /dev/shm/CheckConnection.hold
  mv /dev/shm/CheckConnection.hold /dev/shm/ledpattern.txt
  LAST=$(cat /dev/shm/ledpattern.txt) 
  if [ "$LAST" == "5" ]; then sleep 60; else sleep 15; fi
done
