#!/bin/bash

echo $(cat /proc/net/xt_recent/DEFAULT | wc -l) /proc/net/xt_recent/DEFAULT
echo
#echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo $(sudo iptables -L f2b-sshd -n | wc -l) iptables -L f2b-sshd -n
echo
#echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ps -ef | grep -v grep | grep ssh | grep connect\+
echo
#echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
netstat -an | grep -E ':(400[0-9]|22|12...|13[0-9]{3}|[0-9]*389|9999) ' | grep -v "::" | sort +3.0n +4.0n
