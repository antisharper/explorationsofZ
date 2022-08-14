#!/bin/bash

WAITTIME=60
while (true); do
  sleep $WAITTIME
  bash /home/pi/reroute.sh 
done
