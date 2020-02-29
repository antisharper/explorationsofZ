#!/bin/bash
###
#
# Raspberry PI Router Builder
# v0.1 Stuart R. Harper 2020-02-22
#
##

export CURRENTPROGRAM=$0

export REBOOTDELAY=10
export DEFAULTUSER=pi
export DEFAULTPATH=/home/${DEFAULTUSER}
export LASTPHASEFILE=${DEFAULTPATH}/.phase-routersetup
export TEMPDIR=/dev/shm
export ETCDIR=/etc
export SURVIVEDIR=${DEFAULTPATH}
export BASHRC=${DEFAULTPATH}/.bashrc
export DOWNLOADSPATH=${DEFAULTPATH}/Downloads
export DEFAULTHOSTNAME=testrouter
export SYSCONF=${ETCDIR}/sysctl.conf
export RCLOCAL=${ETCDIR}/rc.local
export RCNOHUPAP=${DEFAULTPATH}/rc.nohup.ap
export CHECKCONNECTION=${DEFAULTPATH}/CheckConnection.sh
export HOSTAPDCONF=${ETCDIR}/hostapd/hostapd.conf
export DNSMASQCONF=${ETCDIR}/dnsmasq.conf
export LOCALROUTERWLAN=wlan0
export LOCALROUTERCHANNEL=0
export LOCALROUTERIP=192.168.127.1
export LOCALROUTERIPMASK=255.255.255.0
export LOCALROUTERIPCIDR=192.168.127.1/24
export LOCALROUTERDHCPRANGE=192.168.127.100,192.168.127.200
export LOCALROUTERDHCPLEASETIME=24h
export UPLINKWLAN=wlan1
export UPLINKWIFICONFIGFILE=${ETCDIR}/wpa_supplicant/wpa_supplicant-${UPLINKWLAN}.conf
export DHCPCDCONF=${ETCDIR}/dhcpcd.conf
export DISCONNECTOPENVPN=${DEFAULTPATH}/disconnect-openvpn.sh
export CONNECTOPENVPN=${DEFAULTPATH}/connect-openvpn.sh
export ADDPACKAGELIST=(openvpn hostapd dnsmasq curl wget netstat-nat tcpdump nmap python-gpiozero)
export CHECKURL=https://api.ipify.org
export UDEVRULESCONF=${ETCDIR}/udev/rules.d/99-com.rules
export RUNUPDATE=${DEFAULTPATH}/run-update.sh
export UPDATEACCOUNT=connectivity@theharpers.homedns.org
export UPDATEPORT=$[12000+(RANDOM%250)]
# raspi-config values
export UNPREDICTABLEWLAN=1
export TZ="America/New_York"
export LOCALE="en.US-UTF-8"
export COUNTRY=us
export KEYMAP=pc101
export STARTSSH=0 # This is inverted 0 means start
export EXPANDROOT=0 # This is inverted 0 means start
export ENABLEBLANKING=1

OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
output_file=""
stepwise=0


banner() {
  echo -e "\e[1m" "$@" "\e[0m"
}

alertbanner() {
  echo -e "\e[1m\e[31m" "$@" "\e[0m" 1>&2
}

stepwisebanner() {
  echo -e "\n\e[33m" "PHASE $@" "\e[0m\n"
}

greenbanner() {
  echo -e "\e[1m\e[32m" "$@" "\e[0m"
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
    0) banner "   Please change the password for account pi:"
       passwd pi
       ;;
    1) read -p "   Please enter HOSTNAME for this router (default:$DEFAULTHOSTNAME) " INHOSTNAME
       raspi-config nonint do_hostname ${INHOSTNAME:-$DEFAULTHOSTNAME}
       ;;
    2) banner "   Setting RASPI-CONFIG configs"
       greenbanner "     Network Interface Names to UNPREDICTABLE"
       raspi-config nonint do_net_names ${UNPREDICTABLEWLAN}
       greenbanner "     TEMPORARILY Setting Boot -> Desktop/CLI -> Console Text / AUTO Login"
       raspi-config nonint do_boot_behaviour B2
       greenbanner "     Setting Localization -> Locale -> ${LOCALE}"
       raspi-config nonint do_change_locale ${LOCALE}
       greenbanner "     Setting Localization -> Timezone -> $TZ"
       raspi-config nonint do_change_timezone ${TZ}
       greenbanner "     Setting Localization -> Keyboard -> Generic 101-Key PC -> Other - > English (US) -> English (US) -> Default -> No Compose"
       localectl set-keymap ${KEYMAP}
       localectl set-x11-keymap ${COUNTRY} ${KEYMAP}
       greenbanner "     Setting Localization -> Wifi Country -> US"
       raspi-config nonint do_wifi_country ${COUNTRY}
       greenbanner "     Enable Interface -> SSH"
       raspi-config nonint do_ssh ${STARTSSH}
       greenbanner "     Enable Advanced Options -> Expand Filesystem"
       raspi-config nonint do_expand_rootfs ${EXPANDROOT}
       greenbanner "     Enable Advanced Options -> Enable Screen Blanking"
       raspi-config nonint do_blanking ${ENABLEBLANKING}
       greenbanner "     Commit Config Changes"
       raspi-config nonint do_finish
       ;;
    3) banner "   Update apt repositories and install needed upgrades and packages"
       echo "     Checking for Internet Link"
       if ! route -n | grep -E '^0.0.0.0' >/dev/null 2>&1; then
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
       greenbanner "     Update Repos"
       apt-get -y update
       greenbanner "     Upgrade current packges"
       apt-get -y upgrade
       greenbanner "   Install additional VPN and support packages (${ADDPACKAGELIST[@]})"
       apt-get install -y ${ADDPACKAGELIST[@]}
       REBOOT=1
       ;;
    4) banner "   Create ssh key for pi"
       rm -rf "${DEFAULTPATH}/.ssh"
       printf "\n\n\n\n" | sudo -u pi ssh-keygen -t rsa -b 4096 -P ""
       ;;
    5) banner "   Unmask and Enable hostapd"
       systemctl unmask hostapd
       systemctl enable hostapd
       ;;
    6) banner "   Move static configs from this directory to /etc/"
       mv hostapd.conf* /etc/hostapd/
       mv wpa_supplicant* /etc/wpa_supplicant/
       chmod +x *.sh
       ;;
    7) banner "   Update dyanmic Configs"
       greenbanner "     Update ${SYSCONF}, Enable _forward and .forward"
       cp -p --force --backup t ${DHCPCDCONF} "${DHCPCDCONF}_BACKUP" >/dev/null 2>&1
       sed -i 's/^#\(.*\)\([\._\]\)forward/\1\2forward/' ${SYSCONF}
       greenbanner "     Build UDEV Rules for LOCALROUTER WLAN ${LOCALROUTERWLAN}"
       build_udev_localrouterwlan
       greenbanner "     Update ROUTER Software Auto start ($RCNOHUPAP)"
       var_sub_in_file ${RCNOHUPAP}
       greenbanner "     Update CheckConnection script ($CHECKCONNECTION)"
       var_sub_in_file ${CHECKCONNECTION}
       greenbanner "     Add ROUTER Software Auto Start (${RCNOHUPAP}) to ${RCLOCAL}"
       BASERCNOHUPAP=$(basename ${RCNOHUPAP}) ; SEDRCNOHUPAP=$(echo $RCNOHUPAP | sed 's/\//\\\//g')
       sed -i '/'$BASERCNOHUPAP'/d;s/^exit 0/bash '$SEDRCNOHUPAP'\nexit 0/' ${RCLOCAL}
       chmod +x ${RCNOHUPAP}
       greenbanner "     Update DNSMASQ to allow DHCP advertisement on $LOCALROUTERWLAN for $LOCALROUTERIPMASK + $LOCALROUTERDHCPLEASETIME lease, Lease IP range $LOCALROUTERDHCPRANGE"
       cp -p --force --backup t ${DNSMASQCONF} "${DNSMASQCONF}_BACKUP" >/dev/null 2>&1
       sed -i '/^interface=/,$d' ${DNSMASQCONF}
       cat <<EOF >> ${DNSMASQCONF}

# ROUTERSETUP
interface=$LOCALROUTERWLAN
no-dhcp-interface=$UPLINKWLAN
dhcp-range=$LOCALROUTERDHCPRANGE,$LOCALROUTERIPMASK,$LOCALROUTERDHCPLEASETIME
#dhcp-option=option:dns-server,$LOCALROUTERIP
EOF
        greenbanner "     Update DHCPCD to disable $LOCALROUTERWLAN inbound on $LOCALROUTERIP"
        cp -p --force --backup t ${DHCPCDCONF} "${DHCPCDCONF}_BACKUP" >/dev/null 2>&1
        sed -i '/^interface '$LOCALROUTERWLAN'/,$d' ${DHCPCDCONF}
        cat <<EOF >> ${DHCPCDCONF}

# ROUTERSETUP
interface $LOCALROUTERWLAN
    static ip_address=$LOCALROUTERIPCIDR
    nohook wpa_supplicant
    denyinterfaces $LOCALROUTERWLAN
EOF
        ;;
    8) banner "   Setup UPDATE account"
       read -p "      Please USERNAME@SERVER for this routers UPDATE CONNECTION ([RETURN] if you do not want an update connection) " INUPDATEACCOUNT
       if [[ ! -z "$INUPDATEACCOUNT" ]]; then
         var_sub_in_file ${RUNUPDATE}
         alertbanner "        Remember to add ${DEFAULTPATH}/.ssh/id_rsa.pub into $INUPDATEACCOUNT:.ssh/authorized_keys to enable this function."
         sleep 5
       fi
       ;;
    9) banner "   Build LOCAL ROUTER AccessPoint Configuration"
       build_localrouterap
       ;;
    10) banner "   Setup UPLINK WLAN ($UPLINKWLAN) Configuration"
        build_uplink_wireless_connection
        ;;
    11) banner "   Configurations completed. Rebooting to verify auto start working correctly"
        REBOOT=1
        ;;
    12) banner "   Disable OpenVPN and ethernet default gateways"
        ${DISCONNECTOPENVPN}
        disable_default_route_ethernet
        ;;
    13) banner "   Disable default gateway on WLAN connection"
        while route -n | grep -E '^0.0.0.0' >/dev/null 2>&1; do
          alertbanner "   Please disconnect USB WIFI device and ethernet" 1>&2
          sleep 5
        done
        ;;
    14) banner "   Verify $LOCALROUTERWLAN has IP $LOCALROUTERIP"
        if ! ifconfig $LOCALROUTERWLAN | grep $LOCALROUTERIP >/dev/null; then
          alertbanner "!!!! Serious error while verifying service !!!! " 1>&2
          alertbanner "!!!! Check hardware and script !!!! " 1>&2
          exit 2
        fi
        LOCALWLANETHER=`ifconfig $LOCALROUTERWLAN | grep ether`
        #Wait until UPLINKWLAN shows up || LOCALROUTERWLAN ethernet changes (udev assign UPLINKWLAN over LOCALROUTERWLAN ??)
        while [[ `ifconfig $LOCALROUTERWLAN | grep ether` == "$LOCALWLANETHER" ]] && ! ifconfig $UPLINKWLAN >/dev/null 2>&1; do
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
          UPLINKWLANETHER=`ifconfig $LOCALROUTERWLAN >/dev/null 2>&1 | grep ether`
          while [[ `ifconfig $LOCALROUTERWLAN | grep ether` == "$UPLINKWLANETHER" ]]; do
            alertbanner "   Due to a configuration error, you'll need to remove our USB WIFI for 5 secs then REATTACH IT" 1>&2
            sleep 5
          done
          sleep 10
        else
          add_udev_uplinkwlan $UPLINKWLAN $UPLINKWLAN
        fi
        UPLINKWLANETHER=`ifconfig $UPLINKWLAN | grep ether`
        LOCALWLANETHER=`ifconfig $LOCALROUTERWLAN | grep ether`
        if ! ifconfig $LOCALROUTERWLAN >/dev/null 2>&1 || ! ifconfig $LOCALROUTERWLAN >/dev/null 2>&1; then
          alertbanner "!!!!! $LOCALROUTERWLAN and $UPLINKWLAN Wifi devices are not settling on the correct device names !!!!! " 1>&2
          alertbanner "!!!!! System will be rebooted to fix the issue !!!!!" 1>&2
          REBOOT=1
        fi
        ;;
    15) banner "   Check UPLINKWLAN ($UPLINKWLAN) and LOCALROUTERWLAN ($LOCALROUTERWLAN) are correctly assigned"
        ${DISCONNECTOPENVPN}
        disable_default_route_ethernet
        UPLINKWLANETHER=`ifconfig $UPLINKWLAN | grep ether`
        LOCALWLANETHER=`ifconfig $LOCALROUTERWLAN | grep ether`
        if grep "${LOCALWLANETHER}" ${UDEVRULESCONF} | grep -v "${LOCALROUTERWLAN}" >/dev/null 2>&1; then
          alertbanner "!!!! Serious error while verifying WIFI devices (LOCALROUTERWLAN: $LOCALROUTERWLAN) !!!! " 1>&2
          alertbanner "!!!! Check hardware and script !!!! " 1>&2
          exit 2
        fi
        if grep "${UPLINKWLANETHER}" ${UDEVRULESCONF} | grep -v "${UPLINKWLAN}" >/dev/null 2>&1; then
          alertbanner "!!!! Serious error while verifying WIFI devices (UPLINKWLAN: $UPLINKWLAN) !!!! " 1>&2
          alertbanner "!!!! Check hardware and script !!!! " 1>&2
          exit 2
        fi
        ;;
    16) banner "   Waiting until UPLINKWLAN ($UPLINKWLAN USB WIFI) is ACCESSING the UPLINK WIFI NETWORK"
        disable_default_route_ethernet
        while [[ `ifconfig $UPLINKWLAN | awk '/RX packets/ {print $3}'` -lt 40 ]]; do
          UPLINKIP=$(get_outside_ip)
          echo "                 OUTSIDE IP is $UPLINKIP"
          iwconfig $UPLINKWLAN
          ifconfig $UPLINKWLAN
          sleep 5
          echo
        done
        TUNNELIP=$UPLINKIP
        ;;
    17) banner "    Starting Openvpn Connection and waiting until secure connection is established."
        disable_default_route_ethernet
        ${CONNECTOPENVPN}
        UPLINKIP=$(get_outside_ip)
        while [[ "$TUNNELIP" == "$UPLINKIP"  ]]; do
          TUNNELIP=$(get_outside_ip)
          echo TUNNELIP: $TUNNELIP
          sleep 5
        done
        ;;
    18) banner "   Resetting Boot -> Desktop/CLI -> Console Text / Password Login"
        raspi-config nonint do_boot_behaviour B1
        ;;
    19) banner "   Router Configuration has been successfully completed and confirmed!"
        banner "   Please open on a phone or other device and connect them to the LOCAL AP"
        grep -Ei '^(ssid=|wpa_passphrase=)' ${HOSTAPDCONF} |column
        ;;
    *) PHASE=-2; REBOOT=0 ;;
    esac

    if (( STEPWISE )); then greenbanner "--- STEPWISE COMPLETED PHASE $PHASE ----\n"; fi

    (( PHASE=PHASE+1 ))
    echo $PHASE > ${LASTPHASEFILE}

    if [ $REBOOT -eq 1 ]; then
      sed -i '/#ROUTERSETUP/d' ${BASHRC}
      echo "sudo bash $CURRENTPROGRAM $(if (( STEPWISE )); then echo "-s"; fi) #ROUTERSETUP" >> ${BASHRC}
      if (( STEPWISE )); then
        alertbanner "------------ REBOOT SUGGESTED ----------"
      else
        alertbanner "   Router Setup will continue after reboot!"
        sleep $REBOOTDELAY
        reboot
      fi
    fi

    if (( STEPWISE )); then exit 0; fi

  done

  rm ${LASTPHASEFILE}

  exit 0
}

disable_default_route_ethernet() {
  route -n | grep -E '^0.0.0.0.*(eth|en)[0-9]' | awk '{print $NF}' | while read DADEVICE; do
    route del -net dev $DADEVICE >/dev/null 2>&1
  done
}

disable_default_route() {
  route -n | grep -E '^0.0.0.0' | awk '{print $NF}' | while read DADEVICE; do
    route del -net dev $DADEVICE >/dev/null 2>&1
  done
}

get_outside_ip() {
  curl -s ${CHECKURL}; echo
}

unstack_configs() {
  if [[ "$CURRENTPROGRAM" =~ "gz" ]]; then CATIT=zcat; else CATIT=cat; fi
  eval "$CATIT $CURRENTPROGRAM" | grep -E '^::::: ' | awk '{print $2}' | while read OUTFILE; do
    if [[ ! -z "${OUTFILE}" ]]; then
      OUTIT=`basename ${OUTFILE}`
      NEWOUT=$(echo $OUTFILE | sed 's/\//\\\//g')
      if [ -e ${OUTFILE} ]; then cp -p --force --backup t ${OUTFILE} "${OUTFILE}_BACKUP" >/dev/null 2>&1; fi
      echo "      ----- $OUTFILE ----- "
      eval "$CATIT $CURRENTPROGRAM" | sed -n '/^::::: '$NEWOUT'/,/^::::: /p' | grep -vE "^::::: " > ${OUTFILE}
      if [ ! -s ${OUTFILE} ]; then
        rm ${OUTFILE}
      else
        if [[ "$OUTFILE" =~ "${DEFAULTPATH}" ]]; then
          chown ${DEFAULTUSER}:${DEFAULTUSER} ${OUTFILE}
          echo "         CHOWN to ${DEFAULTUSER}:${DEFAULTUSER}"
        fi
        if [[ "$OUTFILE" =~ ".py" ]] || [[ "$OUTFILE" =~ ".sh" ]] || [[ "$OUTFILE" =~ "rc." ]]; then
          chmod a+x ${OUTFILE}
          echo "         Make EXECUTABLE"
        fi
      fi
    fi
  done
}

var_sub_in_file() {
  for PROCCESSFILE in "$@"; do
    DAFILE="$1"
    TEMPFILE=$(mktemp --tmpdir ${TEMPDIR})
    cat $DAFILE | envsubst > $TEMPFILE
    cat $TEMPFILE > $DAFILE
    rm $TEMPFILE
  done
}

build_uplink_wireless_connection() {
  echo "    Setting up UPLINK Wifi information"
  read -p "    UPLINK Wifi Name? [Default:DangerWIFI] " INUPLINKWIFINAME
  export UPLINKWIFINAME=${INUPLINKWIFINAME:-DangerWIFI}
  read -p "    UPLINK Wifi Quick description or Owner of this link? " INUPLINKWIFIDESCRIPTION
  export UPLINKWIFIDESCRIPTION=${INUPLINKWIFIDESCRIPTION:-Current Localtion Wifi}
  read -p "    UPLINK Wifi Password? [No Default] " INUPLINKWIFIPASSWORD
  export UPLINKWIFIPASSWORD="${INUPLINKWIFIPASSWORD}"
  UPLINKWIFICONFIGS=$(dirname ${UPLINKWIFICONFIGFILE})/*wlan1.conf*
  cp -p --force --backup t ${UPLINKWIFICONFIGFILE} "${UPLINKWIFICONFIGFILE}_BACKUP" >/dev/null 2>&1

  UPLINKWIFICONFIGS=($(echo $(echo "${UPLINKWIFICONFIGS[@]}" | sed 's/ /\n/g' | grep -i default | sort -u) $(echo "${UPLINKWIFICONFIGS[@]}" | sed 's/ /\n/g' | grep -vi default | sort -u)))

  echo "                  UPLINK WiFi Configurations found:"
  CNT=0; echo ${UPLINKWIFICONFIGS[@]} | sed 's/ /\n/g' | while read UPLINKWIFICONFIG; do (( CNT=CNT+1 )); echo "$CNT) $UPLINKWIFICONFIG"; done | column
  if [ ${#UPLINKWIFICONFIGS[@]} -ne 1 ]; then
    read -p "         Which UPLINK Wifi config version will you use? [Default:1] " INUPLINKWIFICONFIGS
  fi
  INUPLINKWIFICONFIGS=${INUPLINKWIFICONFIGS:-1}; (( INUPLINKWIFICONFIGS=INUPLINKWIFICONFIGS-1 ))
  cp ${UPLINKWIFICONFIGS[$INUPLINKWIFICONFIGS]} ${UPLINKWIFICONFIGFILE}

  echo "                  Updating AccessPoint Configs $UPLINKWIFICONFIGFILE"

  if [ -z "${UPLINKWIFIPASSWORD}" ]; then
    export UPLINKWIFIKEYMGMT="NONE"
    export UPLINKWIFIHASPASSWORD="#"
  else
    export UPLINKWIFIKEYMGMT="WPA-PSK"
    export UPLINKWIFIHASPASSWORD=""
  fi

  var_sub_in_file ${UPLINKWIFICONFIGFILE}
}

build_localrouterap() {
  echo "    Setting up LOCALROUTER Wifi AccessPoint information"
  read -p "    LOCALROUTER AccessPoint Name? [Default:TestZone] " INLOCALROUTERNAME
  export LOCALROUTERNAME=${INlOCALROUTERNAME:-TestZone}
  read -p "    LOCALROUTER AccessPoint Password? [Default:ChangeMe] " INLOCALROUTERPASSWORD
  exprot LOCALROUTERPASSWORD=${INLOCALROUTERPASSWORD:-ChangeMe}

  LOCALROUTERFILES=$(dirname ${HOSTAPDCONF})/*hostapd.conf*
  cp -p --force --backup t ${HOSTAPDCONF} "${HOSTAPDCONF}_BACKUP" >/dev/null 2>&1
  LOCALROUTERFILES=($(echo $(echo "${LOCALROUTERFILES[@]}" | sed 's/ /\n/g' | grep -i default | sort -u) $(echo "${LOCALROUTERFILES[@]}" | sed 's/ /\n/g' | grep -vi default | sort -u)))

  echo "                  LOCALROUTER AccessPoint Configs (per wireless network type)"
  CNT=0; echo ${LOCALROUTERAPFILES[@]} | sed 's/ /\n/g' | while read HOSTAPD; do (( CNT=CNT+1 )); echo "$CNT) $HOSTAPD"; done | column
  if [ ${#LOCALROUTERAPFILES[@]} -ne 1 ]; then
    read -p "         Which Wireless network version will you use? [Default:1] " INLOCALROUTERAPNETWORKFILE
  fi
  INLOCALROUTERNETWORKFILE=${INLOCALROUTERNETWORKFILE:-1} ;  (( INLOCALROUTERNETWORKFILE=INLOCALROUTERNETWORKFILE-1 ))
  export LOCALROUTERNETWORKFILE=${HOSTAPDCONF}
  cp ${LOCALROUTERFILES[$INLOCALROUTERNETWORKFILE]} ${LOCALROUTERNETWORKFILE}

  var_sub_in_file ${LOCALROUTERNETWORKFILE}
}

build_udev_localrouterwlan() {
  WLANS=`ifconfig -a | grep -E '^[A-Za-z]' | grep -vE '(eno|lo|eth|tun)' | sed 's/:.*$//'`
  if [ `echo $WLANS | wc -w` -gt 1 ]; then
    alertbanner "!!!! Multiple WLANS detected ($WLANS) !!!!" 1>&2
    alertbanner "!!!! Please disconnect external WLAN and restart this script !!!!" 1>&2
    exit 1
  fi
  WLAN=`echo $WLANS | awk '{print $1}'`
  ETHER=`ifconfig $WLAN | awk '/ether/ {print $2}'`
  cp -p --force --backup t ${UDEVRULESCONF} "${UDEVRULESCONF}_BACKUP" >/dev/null 2>&1
  cat << EOF >> ${UDEVRULESCONF}
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="$ETHER", NAME="$WLAN"
EOF
}

add_udev_uplinkwlan() {
  WLAN=$1
  TARGETWLAN=$2
  ETHER=`ifconfig $WLAN | awk '/ether/ {print $2}'`
  cp -p --force --backup t ${UDEVRULESCONF} "${UDEVRULESCONF}_BACKUP" >/dev/null 2>&1
  cat <<EOF >> ${UDEVRULESCONF}
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="$ETHER", NAME="$UPLINKWLAN"
EOF
}

main "$@"; exit 0
