#!/bin/bash

USBPATH=/sys/bus/usb/drivers
OLDWLANDRIVER=/dev/shm/.OLD_WLAN_DRIVER
COUNTOPENVPN=`ps -ef | grep -v grep | grep openvpn | wc -l`

if [ -e $OLDWLANDRIVER ]; then
  echo "   STATE File $OLDWLANDRIVER exists ..... EXITING!!! "
  exit 1
fi

if [ -z "$1" ]; then
  echo DISCONNECT WLAN1
  if [ $COUNTOPENVPN -gt 1 ]; then
    echo Disconnect OPENVPN
    ./disconnect-openvpn.sh
    REOPENVPN=OPENVPN
  fi
else
  echo "... Skipping OPENVPN CHECK...."
fi

USBDRIVER=`lsusb -t | sed 's/ /\n/g;s/,//g' | grep Driver | grep -v usbhid | sed 's/.*=//' | grep -v "\/"`
DRIVERPATH=`ls -1 $USBPATH/$USBDRIVER | head -1`

printf "$USBDRIVER\n$DRIVERPATH\n$REOPENVPN" > $OLDWLANDRIVER
echo -n $DRIVERPATH | tee $USBPATH/$USBDRIVER/unbind >/dev/null 2>&1
