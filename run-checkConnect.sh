#!/bin/bash

while (true); do
  bash /home/pi/CheckConnection.sh | tee  /dev/shm/CheckConnection.hold
  mv /dev/shm/CheckConnection.hold /dev/shm/ledpattern.txt
  LAST=$(cat /dev/shm/ledpattern.txt) 
  if [ $LAST -eq 5 ]; then sleep 60; elif [ $LAST -eq 4 ]; then sleep 15; else sleep 5; fi
done