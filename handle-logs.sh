#!/bin/bash

ADATE=$(date +%Y%m%d-%H%M%S)
FILES=$(ls -1 /dev/shm/run* /dev/shm/log-monitor.out)
CONNECTIVITYHOST=connectivity@theharpers.homedns.org

cd /dev/shm
mkdir TEMP
cp $FILES /dev/shm/TEMP/
truncate -s 0 $FILES
cd TEMP
tar jcf ../log-monitor-$(hostname)-$ADATE.tb2 *
cd ..
chmod a+r log-monitor-$(hostname)-$ADATE.tb2
rm -rf TEMP
sudo -u pi scp log-monitor-$(hostname)-$ADATE.tb2 ${CONNECTIVITYHOST}:logs
