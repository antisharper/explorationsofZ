#!/bin/bash

touch /dev/shm/no-openvpn
ps -ef | grep openvpn | grep config | grep ovpn |grep -v grep | awk '{print $2}' | xargs kill 2>/dev/null
