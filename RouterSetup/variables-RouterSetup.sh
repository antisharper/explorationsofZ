#!/bin/#!/usr/bin/env bash

# variables-RouterSetup.sh

export REBOOTDELAY=10

export DEFAULTUSER=pi

export DEFAULTPATH=/home/${DEFAULTUSER}
export TEMPDIR=/dev/shm
export ETCDIR=/etc
export SURVIVEDIR=${DEFAULTPATH}
export LASTPHASEFILE=${SURVIVEDIR}/.phase-routersetup
export BASHRC=${DEFAULTPATH}/.bashrc
export DOWNLOADSPATH=${DEFAULTPATH}/Downloads

export DEFAULTHOSTNAME=testrouter

export RCLOCAL=${ETCDIR}/rc.local
export RCNOHUPAP=${DEFAULTPATH}/rc.nohup.ap

export SYSCONF=${ETCDIR}/sysctl.conf
export HOSTAPDDIR=${ETCDIR}/hostapd
export HOSTAPDCONF=${HOSTAPDDIR}/hostapd.conf
export DNSMASQCONF=${ETCDIR}/dnsmasq.conf
export DHCPCDCONF=${ETCDIR}/dhcpcd.conf

export UDEVRULESCONF=${ETCDIR}/udev/rules.d/99-com.rules

export LOCALROUTERWLAN=wlan0
export LOCALROUTERCHANNEL=7
export LOCALROUTERIP=192.168.127.1
export LOCALROUTERIPMASK=255.255.255.0
export LOCALROUTERIPCIDR=192.168.127.1/24
export LOCALROUTERDHCPRANGE=192.168.127.100,192.168.127.200
export LOCALROUTERDHCPLEASETIME=24h

export UPLINKWLAN=wlan1
export UPLINKWIFICONFIGFILE=${ETCDIR}/wpa_supplicant/wpa_supplicant-${UPLINKWLAN}.conf

export CHECKCONNECTION=${DEFAULTPATH}/CheckConnection.sh
export DISCONNECTOPENVPN=${DEFAULTPATH}/disconnect-openvpn.sh
export CONNECTOPENVPN=${DEFAULTPATH}/connect-openvpn.sh

export RUNUPDATE=${DEFAULTPATH}/run-update.sh

export ADDPACKAGELIST=(openvpn hostapd dnsmasq curl wget netstat-nat tcpdump nmap python-gpiozero)

export CHECKURL=https://api.ipify.org

export UPDATEACCOUNT=connectivity@theharpers.homedns.org
export UPDATEPORT=$(shuf -i 12000-12250 -n 1)
# raspi-config values
export UNPREDICTABLEWLAN=1
export TZ="America/New_York"
export LOCALE="en.US-UTF-8"
export COUNTRY=us
export KEYMAP=pc101
export STARTSSH=0 # This is inverted 0 means start
export EXPANDROOT=0 # This is inverted 0 means start
export ENABLEBLANKING=1
