#!/bin/bash

PATH=/usr/sbin:$PATH
bash /home/pi/monitor-single.sh &>> /dev/shm/log-monitor.out

