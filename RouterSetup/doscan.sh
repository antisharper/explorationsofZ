#!/bin/bash

SORT=$1
SORTSTRING=
TEMPSORTFILE=`mktemp`
if [ -z "$SORT" ]; then
  SORT="1,5,7"
fi
  echo $SORT | sed 's/,/\n/g' | while read COLUMN; do
    case $COLUMN in
      ES*|SID|SSID|1) ADDSTRING="-k1,1";;
      A*|2) ADDSTRING="-k2,2";;
      P*|3) ADDSTRING="-k3,3";;
      F*|4) ADDSTRING="-k4,4n";;
      C*|5) ADDSTRING="-k5,5n";;
      E*|6) ADDSTRING="-k6,6";;
      B*|7) ADDSTRING="-k7,7n";;
      Q*|8) ADDSTRING="-k8,8n";;
      SIG*|9) ADDSTRING="-k9,9n";;
      default) ADDSTRING="";;
    esac
    SORTSTRING=`echo "$SORTSTRING $ADDSTRING" | tee $TEMPSORTFILE`
  done

SORTSTRING=`cat $TEMPSORTFILE`
rm -f $TEMPSORTFILE
#echo EXCEUTE $SORTSTRING
bash /home/pi/scanit.sh | sort -t, $SORTSTRING | awk -F,  '{printf ("%-22.22s %-17.17s %-9.9s %9.9s %7.7s %-7.7s %8.8s %7.7s %7.7s\n",$1,$2,$3,$4,$5,$6,$7,$8,$9)}'
