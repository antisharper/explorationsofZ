#!/bin/bash

while (true); do
  bash /home/pi/CheckConnection.sh | tee  /dev/shm/CheckConnection.hold
  mv /dev/shm/CheckConnection.hold /dev/shm/ledpattern.txt
  sleep 5
done
