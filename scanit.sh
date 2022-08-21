#!/bin/bash

if [ -z "$1" ]; then
  WLAN=`ifconfig -a | grep -E ^wl | awk '{print $1}' | sed 's/://' | sort | head -1`
else
  WLAN=$1
fi
iwlist $WLAN scan | mawk '
function banner() {
  print "0 ESSID,ADDRESS,PROTOCOL,FREQUENCY,CHANNEL,ENCRYPT,BITRATE,QUALITY,SIGNAL"
}
function PRINTIT() {
    if (ESSID == "") { ESSID = "<< NONE >>" }
    print ESSID "," ADDRESS "," PROTOCOL "," FREQUENCY "," CHANNEL "," ENCRYPT "," BITRATE "," QUALITY "," SIGNAL
}
function OUTARRAY(A,name) {
  for ( aval in A ) { print name": "aval"="A[aval] };
}

BEGIN { banner() }
/Cell/ { if (ESSID != "") { ADDRESS=$5 ; PRINTIT () } }
/ESSID/ { split($0,A,/:/); gsub(/"/,"",A[2]); ESSID=A[2] }
/Protocol/ { split($0,B,/:/); split(B[2],A,/ /); PROTOCOL=A[2] }
/Frequency/ { split($0,B,/:/); split(B[2],A,/ /); FREQUENCY=A[1]; CHANNEL=+A[4] }
/Encryption/ { split($0,A,/:/); ENCRYPT=A[2] }
/Bit Rate/ { split($0,A,/:/); BITRATE=A[2] }
/Quality/ { split($0,A,/=/); QUALITY=+A[2];SIGNAL=+A[3] }
END { PRINTIT() }
'
exit 0
