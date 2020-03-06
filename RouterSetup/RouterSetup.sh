#!/bin/bash
###
#
# Raspberry PI Router Builder
# v0.3 Stuart R. Harper 2020-02-22
#
##

export CURRENTPROGRAM=$0

source $(dirname $CURRENTPROGRAM)/variables-$(basename $CURRENTPROGRAM)
source $(dirname $CURRENTPROGRAM)/functions-$(basename $CURRENTPROGRAM)

OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
output_file=""
stepwise=0

banner() {
  printf "\e[1m$@\e[0m\n"
}

alertbanner() {
  printf "\e[1m\e[31m$@\e[0m\n" 1>&2
}

stepwisebanner() {
  printf "\n\e[33mPHASE $@\e[0m\n\n"
}

greenbanner() {
  printf "\e[1m\e[32m$@\e[0m\n"
}

if [[ "${CURRENTPROGRAM}" =~ gz ]]; then CATIT=zcat; else CATIT=cat; fi
eval "$CATIT $CURRENTPROGRAM" | sed -n '/^###$/,/^##$/p' | sed 's/^#*//'

while getopts "sd:" opt; do
    case "$opt" in
    s)  STEPWISE=1
        ;;
    d)  STEPWISE=1
        echo $OPTARG > ${LASTPHASEFILE}
        ;;
    esac
done
shift $((OPTIND-1))

# Check we're running as ROOT
if [[ $EUID -ne 0 ]]; then
   alertbanner "!!!! This script must be run as root !!!!"
   exit 1
fi

REBOOT=0
PHASE=0

if [ -e ${LASTPHASEFILE} ]; then
  PHASE=`cat $LASTPHASEFILE`
  sed -i '/#ROUTERSETUP/d' ${BASHRC}
  stepwisebanner "$PHASE (Restarting)"
fi


main() {
  while [ $PHASE -gt -1 ]; do
    stepwisebanner $PHASE
    case $PHASE in
    0) banner "Please change the password for account pi:"
       passwd pi
       ;;
    1) read -p "Please enter HOSTNAME for this router (default:$DEFAULTHOSTNAME) " INHOSTNAME
       raspi-config nonint do_hostname ${INHOSTNAME:-$DEFAULTHOSTNAME}
       ;;
    2) banner "Setting RASPI-CONFIG configs"
       greenbanner "\t Network Interface Names to UNPREDICTABLE"
       raspi-config nonint do_net_names ${UNPREDICTABLEWLAN}
       greenbanner "\t TEMPORARILY Setting Boot -> Desktop/CLI -> Console Text / AUTO Login"
       raspi-config nonint do_boot_behaviour B2
       greenbanner "\t Setting Localization -> Locale -> ${LOCALE}"
       raspi-config nonint do_change_locale ${LOCALE}
       greenbanner "\t Setting Localization -> Timezone -> $TZ"
       raspi-config nonint do_change_timezone ${TZ}
       greenbanner "\t Setting Localization -> Keyboard -> Generic 101-Key PC -> Other - > English (US) -> English (US) -> Default -> No Compose"
       localectl set-keymap ${KEYMAP}
       localectl set-x11-keymap ${COUNTRY} ${KEYMAP}
       greenbanner "\t Setting Localization -> Wifi Country -> US"
       raspi-config nonint do_wifi_country ${COUNTRY}
       greenbanner "\t Enable Interface -> SSH"
       raspi-config nonint do_ssh ${STARTSSH}
       greenbanner "\t Enable Advanced Options -> Expand Filesystem"
       raspi-config nonint do_expand_rootfs ${EXPANDROOT}
       greenbanner "\t Enable Advanced Options -> Enable Screen Blanking"
       raspi-config nonint do_blanking ${ENABLEBLANKING}
       greenbanner "\t Commit Config Changes"
       raspi-config nonint do_finish
       ;;
    3) if [ "$(dirname ${CURRENTPROGRAM})" != "${DEFAULTPATH}" ]; then
          greenbanner "\t Copy from GIT Directory to HOME ${DEFAULTPATH}"
          copy_with_backup $(dirname ${CURRENTPROGRAM})/* ${DEFAULTPATH}
       fi
       chmod +x ${DEFAULTPATH}/*.sh
       ;;
    4) banner "Checking for Internet Link"
       if ! route -n | grep -E '^0.0.0.0' &>/dev/null; then
         alertbanner " !!!! No Internet link has been found !!!!"
         alertbanner " Please connect an ethernet cable or ... "
         alertbanner " Setup WIRELESS Access using 'sudo raspi-config' -> "
         alertbanner "   NETWORKING Options -> "
         alertbanner "     SSID and Password -> "
         alertbanner "       Enter a local wireles network name "
         alertbanner "       Password"
         alertbanner " <FINISH>"
         echo
         alertbanner " When you have an internet link, restart the router installation."
         exit 1
       fi
       ;;
    5) banner "Update Repos"
       apt-get update -y
       ;;
    6) banner "Upgrade current packges"
       apt-get dist-upgrade -y
       ;;
    7) banner "Install additional VPN and support packages (${ADDPACKAGELIST[@]})"
       apt-get install -y ${ADDPACKAGELIST[@]}
       REBOOT=1
       ;;
    8) banner "Creating ssh key for account pi (This may take a minute or so on a PI ZERO)"
       rm -rf "${DEFAULTPATH}/.ssh"
       printf "\n\n\n\n" | sudo -u pi ssh-keygen -t rsa -b 4096 -P ""
       ;;
    9) banner "Denote UPDATE account"
       read -p "\t Please USERNAME@SERVER for this routers UPDATE CONNECTION ([RETURN] if you do not want an update connection) " UPDATEACCOUNT
       if [[ ! -z "$UPDATEACCOUNT" ]]; then
         alertbanner "\t\t Remember to add ${DEFAULTPATH}/.ssh/id_rsa.pub into $INUPDATEACCOUNT:.ssh/authorized_keys to enable this function."
         sleep 2
       fi
       ;;
    10) banner "Move HOSTAPD and WPA_SUPPLICANT configs to /etc/"
        copy_with_backup ${DEFAULTPATH}/hostapd.conf* $(dirname ${HOSTAPDCONF})
        copy_with_backup ${DEFAULTPATH}/wpa_supplicant* $(dirname ${UPLINKCONFIGFILE})
        ;;
    11) banner "Update ${SYSCONF}, Enable _forward and .forward"
        backup_file ${SYSCONF}
        sed -i 's/^#\(.*\)\([\._\]\)forward/\1\2forward/' ${SYSCONF}
        ;;
    12) banner "Build UDEV Rules for LOCALROUTER WLAN ${LOCALROUTERWLAN}"
        build_udev_localrouterwlan
        ;;
    13) banner "Update router run script ($RCNOHUPAP)"
        var_sub_in_file ${RCNOHUPAP}
        ;;
    14) banner "Add router run script (${RCNOHUPAP}) to server auto start ${RCLOCAL}"
        BASERCNOHUPAP=$(basename ${RCNOHUPAP}) ; SEDRCNOHUPAP=$(echo $RCNOHUPAP | sed 's/\//\\\//g')
        sed -i '/'$BASERCNOHUPAP'/d;s/^exit 0/bash '$SEDRCNOHUPAP'\nexit 0/' ${RCLOCAL}
        chmod +x ${RCNOHUPAP}
        ;;
    15) banner "Update DNSMASQ to allow DHCP advertisement on $LOCALROUTERWLAN for $LOCALROUTERIPMASK + $LOCALROUTERDHCPLEASETIME lease, Lease IP range $LOCALROUTERDHCPRANGE"
        backup_file ${DNSMASQCONF}
        sed -i '/^interface=/,$d' ${DNSMASQCONF}
        cat <<EOF >> ${DNSMASQCONF}

# ROUTERSETUP
interface=$LOCALROUTERWLAN
no-dhcp-interface=$UPLINKWLAN
dhcp-range=$LOCALROUTERDHCPRANGE,$LOCALROUTERIPMASK,$LOCALROUTERDHCPLEASETIME
#dhcp-option=option:dns-server,$LOCALROUTERIP
EOF
        ;;
    16) banner "Update DHCPCD to disable $LOCALROUTERWLAN inbound on $LOCALROUTERIP"
        backup_file ${DHCPCDCONF}
        sed -i '/^interface '$LOCALROUTERWLAN'/,$d' ${DHCPCDCONF}
        cat <<EOF >> ${DHCPCDCONF}

# ROUTERSETUP
interface $LOCALROUTERWLAN
    static ip_address=$LOCALROUTERIPCIDR
    nohook wpa_supplicant
    denyinterfaces $LOCALROUTERWLAN
EOF
        ;;
    17) banner "Build AP (HOSTAPD) Configuration"
       if build_localrouterap; then
         alertbanner "!!!!! Unable to select an HOSTAPD CONFIG FILE !!!!"
         alertbanner "!!!!! Fix the files at $HOSTAPD then restart this setup script !!!!"
         exit 1
       fi
       ;;
    18) banner "Setup UPLINK WLAN ($UPLINKWLAN) Configuration"
        if build_uplink_wireless_connection; then
          alertbanner "!!!!! Unable to select an UPLINK WIFI CONFIG FILE !!!!"
          alertbanner "!!!!! Fix the files at $UPLINKCONFIGFILE then restart this setup script !!!!"
          exit 1
        fi
        ;;
    19) banner "Configurations completed. Rebooting to test auto start working correctly"
        REBOOT=1
        ;;
    20) banner "Disable OpenVPN and wireless/ethernet default gateways"
        ${DISCONNECTOPENVPN}
        disable_default_route_ethernet
        ;;
    21) banner "Disable default gateway on current wireless or ethernet connection"
        continue_script_after_reboot
        while route -n | grep -E '^0.0.0.0' &>/dev/null; do
          alertbanner "   Please disconnect USB WIFI device and/or Ethernet Cable" 1>&2
          sleep 5
        done
        remove_install_script_from_bashrc
        ;;
    22) banner "Unmask and Enable hostapd"
       touch ${HOSTAPDDIR}/hostapd-client-mac.accept
       touch ${HOSTAPDDIR}/hostapd-client-mac.deny
       systemctl unmask hostapd
       systemctl enable hostapd
       systemctl restart hostapd
       sleep 5
       ;;
    23) banner "Verify $LOCALROUTERWLAN has IP $LOCALROUTERIP"
        if ! ifconfig $LOCALROUTERWLAN | grep $LOCALROUTERIP >/dev/null; then
          alertbanner "!!!! Serious error while verifying service !!!! " 1>&2
          alertbanner "!!!! Check hardware and script !!!! " 1>&2
          exit 2
        fi
        LOCALWLANETHER=`ifconfig $LOCALROUTERWLAN | grep ether`
        #Wait until UPLINKWLAN shows up || LOCALROUTERWLAN ethernet changes (udev assign UPLINKWLAN over LOCALROUTERWLAN ??)
        while [[ `ifconfig $LOCALROUTERWLAN | grep ether` == "$LOCALWLANETHER" ]] && ! ifconfig $UPLINKWLAN &>/dev/null; do
          alertbanner "   Please connect your USB WIFI" 1>&2
          sleep 5
        done
        # Need an extra stablization sleep, Inital UPLINKWLAN insert blanks Ether field sometimes
        sleep 5
        ORIG_LOCALWLANETHER=$LOCALWLANETHER
        LOCALWLANETHER=`ifconfig $LOCALROUTERWLAN | grep ether`
        # Check if LOCALROUTERWLAN ether changed
        if [[ "$ORIG_LOCALWLANETHER" != "$LOCALWLANETHER" ]]; then
          # Add UDEV RULES to point changed ether on $LOCALROUTERWLAN to TRUE UPLINKWLAN
          add_udev_uplinkwlan $LOCALROUTERWLAN $UPLINKWLAN
          UPLINKWLANETHER=`ifconfig $LOCALROUTERWLAN &>/dev/null | grep ether`
          while [[ `ifconfig $LOCALROUTERWLAN | grep ether` == "$UPLINKWLANETHER" ]]; do
            alertbanner "!!!! Due to a configuration error, you'll need to remove our USB WIFI for 5 secs then REATTACH IT" 1>&2
            sleep 5
          done
          sleep 10
        else
          add_udev_uplinkwlan $UPLINKWLAN $UPLINKWLAN
        fi
        UPLINKWLANETHER=`ifconfig $UPLINKWLAN | grep ether`
        LOCALWLANETHER=`ifconfig $LOCALROUTERWLAN | grep ether`
        if ! ifconfig $LOCALROUTERWLAN &>/dev/null || ! ifconfig $LOCALROUTERWLAN &>/dev/null; then
          alertbanner "!!!!! $LOCALROUTERWLAN and $UPLINKWLAN Wifi devices are not settling on the correct device names !!!!! " 1>&2
          alertbanner "!!!!! System will be rebooted to fix the issue !!!!!" 1>&2
          REBOOT=1
        fi
        ;;
    24) banner "Check UPLINKWLAN ($UPLINKWLAN) and LOCALROUTERWLAN ($LOCALROUTERWLAN) are correctly assigned"
        ${DISCONNECTOPENVPN}
        disable_default_route_ethernet
        UPLINKWLANETHER=`ifconfig $UPLINKWLAN | grep ether`
        LOCALWLANETHER=`ifconfig $LOCALROUTERWLAN | grep ether`
        if grep "${LOCALWLANETHER}" ${UDEVRULESCONF} | grep -v "${LOCALROUTERWLAN}" &>/dev/null; then
          alertbanner "!!!! Serious error while verifying WIFI devices (LOCALROUTERWLAN: $LOCALROUTERWLAN) !!!! " 1>&2
          alertbanner "!!!! Check hardware and script !!!! " 1>&2
          exit 2
        fi
        if grep "${UPLINKWLANETHER}" ${UDEVRULESCONF} | grep -v "${UPLINKWLAN}" &>/dev/null; then
          alertbanner "!!!! Serious error while verifying WIFI devices (UPLINKWLAN: $UPLINKWLAN) !!!! " 1>&2
          alertbanner "!!!! Check hardware and script !!!! " 1>&2
          exit 2
        fi
        ;;
    25) banner "Waiting until UPLINKWLAN ($UPLINKWLAN USB WIFI) is ACCESSING the UPLINK WIFI NETWORK"
        disable_default_route_ethernet
        greenbanner "\t Waiting until ${CHECKPACKETS} pass through ${UPLINKWLAN}"
        while [[ `ifconfig $UPLINKWLAN | awk '/RX packets/ {print $3}'` -lt 40 ]]; do
          UPLINKIP=$(get_outside_ip)
          echo "\t\t\t OUTSIDE IP is $UPLINKIP"
          iwconfig $UPLINKWLAN
          ifconfig $UPLINKWLAN
          sleep 5
          echo
        done
        TUNNELIP=$UPLINKIP
        ;;
    26) banner "Starting Openvpn Connection and waiting until secure connection is established."
        disable_default_route_ethernet
        ${CONNECTOPENVPN}
        UPLINKIP=$(get_outside_ip)
        while [[ "$TUNNELIP" == "$UPLINKIP"  ]]; do
          TUNNELIP=$(get_outside_ip)
          echo TUNNELIP: $TUNNELIP
          sleep 5
        done
        ;;
    27) banner "Resetting Boot -> Desktop/CLI -> Console Text / Password Login"
        raspi-config nonint do_boot_behaviour B1
        ;;
    28) banner "Router Configuration has been successfully completed and confirmed!"
        banner "Please open on a phone or other device and connect them to the LOCAL AP"
        grep -Ei '^(ssid=|wpa_passphrase=)' ${HOSTAPDCONF} | xargs echo "    "
        ;;
    *) PHASE=-2; REBOOT=0 ;;
    esac

    if (( STEPWISE )); then greenbanner "--- STEPWISE COMPLETED PHASE $PHASE ----\n"; fi

    (( PHASE=PHASE+1 ))
    echo $PHASE > ${LASTPHASEFILE}

    if [ $REBOOT -eq 1 ]; then
      continue_script_after_reboot
      if (( STEPWISE )); then
        alertbanner "------------ REBOOT SUGGESTED ----------"
      else
        alertbanner "!!! $CURRENTPROGRAM will continue after reboot !!!!"
        sleep $REBOOTDELAY
        reboot
      fi
    fi

    if (( STEPWISE )); then exit 0; fi

  done

  rm ${LASTPHASEFILE}

  exit 0
}

main "$@"; exit 0
