#!/bin/bash

watch --difference -n 1 'netstat-nat -n > /dev/shm/netstat-nat.out; head -1 /dev/shm/netstat-nat.out; tail -n +2 /dev/shm/netstat-nat.out | (read -r 2>/dev/null; printf "%s\n" "$REPLY"; sort -k4,4 -k3,3 -k2,2 -k1,1 );echo'
