#!/bin/bash

SORT="SID,CHANNEL,B"
WLAN=wlan0
OUTIT=

while getopts "i:s:c" opt; do
    case "$opt" in
    i)  WLAN=$OPTARG
        ;;
    c)  OUTIT=csv
        ;;
    s)  SORT=$OPTARG
        ;;
    esac
done
shift $((OPTIND-1))

SORTSTRING=
TEMPSORTFILE=`mktemp`

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
    ES*|SID|SSID|10) ADDSTRING="-k1,1";;
    rA*|12) ADDSTRING="-k2,2r";;
    rP*|13) ADDSTRING="-k3,3r";;
    rF*|14) ADDSTRING="-k4,4rn";;
    rC*|15) ADDSTRING="-k5,5rn";;
    rE*|16) ADDSTRING="-k6,6r";;
    rB*|17) ADDSTRING="-k7,7rn";;
    rQ*|18) ADDSTRING="-k8,8rn";;
    rSIG*|19) ADDSTRING="-k9,9rn";;
    default) ADDSTRING="";;
  esac
  SORTSTRING=`echo "$SORTSTRING $ADDSTRING" | tee $TEMPSORTFILE`
done

SORTSTRING=`cat $TEMPSORTFILE`
rm -f $TEMPSORTFILE
#echo EXCEUTE $SORTSTRING
bash /home/pi/scanit.sh $WLAN >  $TEMPSORTFILE
head -1 $TEMPSORTFILE | sed 's/0 ESSID/Network/'
FORMATOUT="%-22.22s %-17.17s %-9.9s %9.9s %7.7s %-7.7s %8.8s %7.7s %7.7s\n"
if [ "$OUTIT" == "csv" ]; then FORMATOUT="%s,%s,%s,%s,%s,%s,%s,%s,%s\n"; fi
grep -v CHANNEL $TEMPSORTFILE | \
   sort -t, $SORTSTRING | \
	awk -F, "-vFORMATOUT=$FORMATOUT" '{printf (FORMATOUT,$1,$2,$3,$4,$5,$6,$7,$8,$9)}'
rm  "$TEMPSORTFILE"
