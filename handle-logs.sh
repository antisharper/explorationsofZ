#!/bin/bash

ADATE=$(date +%Y%m%d)
FILES=$(ls -1 /dev/shm/run* /dev/shm/log-monitor.out)

cd /dev/shm
mkdir TEMP
cp $FILES /dev/shm/TEMP/
rm -f $FILES
cd TEMP
tar jcf ../log-monitor-$(hostname)-$ADATE.tb2 *
cd ..
rm -rf TEMP
pi@router-piz-
