#!/bin/bash

CYCLETIME=${1:-5}

#watch --difference -n $CYCLETIME 'ssh root@truenas cat /tmp/openvpn-status | sed "s/Bytes //g;/LIST/,/ROUTING/!d;/Common/,/ROUTING/!d;/ROUTING/d" | awk -F, "{side=\"-\"; if (NR > 1) { side=\"\";RECVK=int(\$3/1024);SENTK=int(\$4/1024) }else {RECVK=\$3;SENTK=\$4};printf(\"%-15.15s %\"side\"22.22s %\"side\"15.15s %\"side\"12.12s %\"side\"25.25s\\n\",\$1,\$2,RECVK,SENTK,\$5)}"'

watch --difference -n $CYCLETIME 'ssh root@truenas cat /tmp/openvpn-status | sed "s/Bytes //g;s/Received/Recv M/g;s/Sent/Sent M/g;/LIST/,/ROUTING/!d;/Common/,/ROUTING/!d;/ROUTING/d" | awk -F, "{ if (NR > 1) { side=\"\"; RECVK=int(\$3/1024/1024); SENTK=int(\$4/1024/1024) } else { RECVK=\$3; SENTK=\$4 }; printf (\"%-15.15s %\"side\"22.22s %\"side\"15.15s %\"side\"12.12s %\"side\"25.25s\\n\",\$1,\$2,RECVK,SENTK,\$5)}"'

#watch --difference -n $CYCLETIME 'ssh root@truenas cat /tmp/openvpn-status | sed "s/Bytes //g;s/Received/Recv K/g;s/Sent/Sent K/g;/LIST/,/ROUTING/!d;/Common/,/ROUTING/!d;/ROUTING/d" | awk -F, "{ if (NR > 1) { side=\"\"; RECVK=int(\$3/1024); SENTK=int(\$4/1024) } else { RECVK=\$3; SENTK=\$4 }; printf (\"%-15.15s %\"side\"22.22s %\"side\"15.15s %\"side\"12.12s %\"side\"25.25s\\n\",\$1,\$2,RECVK,SENTK,\$5)}"'
