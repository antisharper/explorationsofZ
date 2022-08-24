#!/bin/bash

# Check we're running as ROOT
if [[ $EUID -ne 0 ]]; then
   echo "!!!! This script must be run as root !!!!" >&2
   exit 1
fi

SLEEPTIME=5

while getopts "s:" opt; do
    case "$opt" in
    s)  SLEEPTIME=$OPTARG
        ;;
    esac
done
shift $((OPTIND-1))

BASEDIR=$(dirname $0)
WIDTH=$(/usr/bin/tput cols)

watch --difference -n ${SLEEPTIME} "bash ${BASEDIR}/monitor-single.sh -w $WIDTH $1"
