#!/bin/bash

OLDWLANDRIVER=/dev/shm/.OLD_WLAN_DRIVER
USBPATH=/sys/bus/usb/drivers

if [ ! -e $OLDWLANDRIVER ]; then
  echo "  No Saved State --- EXITING! "
  exit 1
fi
echo "Connect WLAN1"
USBDRIVER=`cat $OLDWLANDRIVER | head -1`
DRIVERPATH=`cat $OLDWLANDRIVER| head -2 | tail -1`
REOPENVPN=`cat $OLDWLANDRIVER| head -3 | tail -1`
rm $OLDWLANDRIVER
echo -n $DRIVERPATH | tee $USBPATH/$USBDRIVER/bind >/dev/null 2>&1
if [ ! -z "$REOPENVPN" ]; then ~pi/connect-openvpn.sh; fi
