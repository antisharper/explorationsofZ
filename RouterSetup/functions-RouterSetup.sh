disable_default_route_ethernet() {
  route -n | grep -E '^0.0.0.0.*(eth|en)[0-9]' | awk '{print $NF}' | while read DADEVICE; do
    route del -net dev $DADEVICE &>/dev/null
  done
}

disable_default_route() {
  route -n | grep -E '^0.0.0.0' | awk '{print $NF}' | while read DADEVICE; do
    route del -net dev $DADEVICE &>/dev/null
  done
}

get_outside_ip() {
  curl -s ${CHECKURL}; echo
}

backup_file() {
  BACKUPFILE=$1

  CNT=1
  while [ -e "${BACKUPFILE}.~${CNT}~" ]; do (( CNT=CNT+1 )); done
  cp -p -v $BACKUPFILE "${BACKUPFILE}.~${CNT}~"
}

copy_with_backup() {
  COPYFILES=( $@ )
  if [ -d ${COPYFILES[-1]} ]; then
      DESTDIR=${COPYFILES[-1]};
      unset 'COPYFILES[${#COPYFILES[@]}-1]'
  else DESTDIR=$(dirname ${COPYFILES[0]}); fi
  cp -v -p --backup=t ${COPYFILES[@]} ${DESTDIR}
}

unstack_configs() {
  if [[ "$CURRENTPROGRAM" =~ "gz" ]]; then CATIT=zcat; else CATIT=cat; fi
  eval "$CATIT $CURRENTPROGRAM" | grep -E '^::::: ' | awk '{print $2}' | while read OUTFILE; do
    if [[ ! -z "${OUTFILE}" ]]; then
      OUTIT=`basename ${OUTFILE}`
      NEWOUT=$(echo $OUTFILE | sed 's/\//\\\//g')
      if [ -e ${OUTFILE} ]; then copy_with_backup "$(dirname ${OUTFILE})"; fi
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
  for PROCESSFILE in "$@"; do
    #echo "                    Substituting variables in file $PROCESSFILE"
    TEMPFILE=$(mktemp ${TEMPDIR}/temp.XXXXXXXX)
    backup_file $PROCESSFILE ${PROCESSFILE}_backup
    cat $PROCESSFILE | envsubst > $TEMPFILE
    cat $TEMPFILE > $PROCESSFILE
    rm $TEMPFILE
  done
}

remove_install_from_bashrc(){
  sed -i '/#ROUTERSETUP/d' ${BASHRC}
}

continue_script_after_reboot(){
  remove_install_from_bashrc
  echo "sudo bash $CURRENTPROGRAM $(if (( STEPWISE )); then echo "-s"; fi) #ROUTERSETUP" >> ${BASHRC}
}

select_from_file_list_default_first() {
  NOMINALFILE=$1
  MATCHFILE=${2:-$(basename ${NOMINALFILE})}

  ALLFILES=( $(dirname ${NOMINALFILE})/*${MATCHFILE}* )
  DEFAULTFIRST=( $(echo "${ALLFILES[@]}" | sed 's/ /\n/g' | grep -i default | sort -u) \
                $(echo "${ALLFILES[@]}" | sed 's/ /\n/g' | grep -vi default | sort -u))

  if [ ${#DEFAULTFIRST[@]} -eq 0 ] || [[ "$DEFAULTFIRST" =~ "*" ]]; then
    alertbanner "!!!! File list is empty !!!!"
    export RETURNEDVAL=
  elif [ ${#DEFAULTFIRST[@]} -eq 1 ]; then
    SELECTEDFILENUM=0
    export RETURNEDVAL=${DEFAULTFIRST[$SELECTEDFILENUM]}
  else
    CNT=0; for AFILE in ${DEFAULTFIRST[@]}; do (( CNT=CNT+1 )); echo "$CNT) $AFILE"; done | column
    SELECTEDFILENUM=-1
    while (( SELECTEDFILENUM == -1 )); do

      read -p "         Which config file will you use? [Default: 1] " INSELECTEDFILENUM
      SELECTEDFILENUM=${INSELECTEDFILENUM:-1}

      if [ $SELECTEDFILENUM -lt 1 ] || [ $SELECTEDFILENUM -gt "${#DEFAULTFIRST[@]}" ]; then
        printf "\n\n            Selected value $SELECTEDFILENUM is out of range (1..${#DEFAULTFIRST[@]})\n             Please choose again!\n\n"
        SELECTEDFILENUM=-1
      fi
    done

    (( SELECTEDFILENUM=SELECTEDFILENUM-1 ))
    export RETURNEDVAL=${DEFAULTFIRST[$SELECTEDFILENUM]}
   fi
}

build_uplink_wireless_connection() {
  echo "    Setting up UPLINK Wifi information"
  read -p "    UPLINK Wifi Name? [Default:DangerWIFI] " INUPLINKWIFINAME
  export UPLINKWIFINAME=${INUPLINKWIFINAME:-DangerWIFI}
  read -p "    UPLINK Wifi Quick description or Owner of this link? " INUPLINKWIFIDESCRIPTION
  export UPLINKWIFIDESCRIPTION=${INUPLINKWIFIDESCRIPTION:-Current Localtion Wifi}
  read -p "    UPLINK Wifi Password? [No Default] " INUPLINKWIFIPASSWORD

  export UPLINKWIFIPASSWORD="${INUPLINKWIFIPASSWORD}"
  select_from_file_list_default_first "${UPLINKWIFICONFIGFILE}" "${UPLINKWLAN}"

  echo "                  UPLINK WiFi Configurations found:"
  SOURCEUPLINKCONFIGFILE=${RETURNEDVAL}

  if [ -z ${SOURCEUPLINKCONFIGFILE} ]; then
    return 0
  else
    echo "                  Updating AccessPoint Configs $UPLINKWIFICONFIGFILE"

    if [ -z "${UPLINKWIFIPASSWORD}" ]; then
      export UPLINKWIFIKEYMGMT="NONE"
      export UPLINKWIFIHASPASSWORD="#"
    else
      export UPLINKWIFIKEYMGMT="WPA-PSK"
      export UPLINKWIFIHASPASSWORD=""
    fi

    cp -p -v --backup=t ${SOURCEUPLINKCONFIGFILE} ${UPLINKWIFICONFIGFILE}
    var_sub_in_file ${UPLINKWIFICONFIGFILE}
    return 1
  fi
}

build_localrouterap() {
  echo "    Setting up LOCALROUTER Wifi AccessPoint information"
  read -p "    LOCALROUTER AccessPoint Name? [Default:TestZone] " INLOCALROUTERNAME
  export LOCALROUTERNAME=${INlOCALROUTERNAME:-TestZone}
  read -p "    LOCALROUTER AccessPoint Password? [Default:ChangeMe] " INLOCALROUTERPASSWORD
  export LOCALROUTERPASSWORD=${INLOCALROUTERPASSWORD:-ChangeMe}

  select_from_file_list_default_first "${HOSTAPDCONF}"
  SOURCELOCALROUTERFILE=${RETURNEDVAL}

  if [ -z ${SOURCELOCALROUTERFILE} ]; then
    return 0
  else
    echo "                  Updating AccessPoint Configs $HOSTAPDCONF"

    echo "                     Select Access Point's Channel"
    if echo $SOURCELOCALROUTERFILE | grep -E '(2.4)' &>/dev/null; then
      POSSIBLECHANNELS=( $(seq 1 11) )
      VIEWCHANNELS="1 through 11"
      DEFAULTCHANNEL=7
      RADIORATE="2.4GHz"
    else
      POSSIBLECHANNELS=( 36 44 52 60 100 108 116 124 132 140 149 157 184 192 )
      VIEWCHANNELS=${POSSIBLECHANNELS[@]}
      DEFAULTCHANNEL=36
      RADIORATE="5GHz"
    fi

    #Randomly pick a channel
    DEFAULTCHANNEL=$(shuf -i 1-${#POSSIBLECHANNELS[@]} -n 1); (( DEFAULTCHANNEL=DEFAULTCHANNEL-1 ))
    DEFAULTCHANNEL=${POSSIBLECHANNELS[$DEFAULTCHANNEL]}

    export LOCALROUTERCHANNEL=0
    while [ $LOCALROUTERCHANNEL -eq 0 ]; do
      echo "                       For $RADIORATE radio, available channels are $VIEWCHANNELS"
      read -p "                     LOCALROUTER AccessPoint Channel? [Default: $DEFAULTCHANNEL] " INLOCALROUTERCHANNEL

      export INLOCALROUTERCHANNEL=${INLOCALROUTERCHANNEL:-$DEFAULTCHANNEL}
      if echo " ${POSSIBLECHANNELS[@]} " | grep " $INLOCALROUTERCHANNEL " &>/dev/null; then
        export LOCALROUTERCHANNEL=$INLOCALROUTERCHANNEL
      else
        echo; echo "                       Sorry... value entered is not valid!"
      fi
    done

    if [ "$RADIORATE" == "5GHz" ]; then
      POSSIBLEVOCF=( 42 58 106 122 138 155 )
      DEFAULTVOCF=42

      #Randomly pick a channel
      DEFAULTVOCF=$(shuf -i 1-${#POSSIBLEVOCF[@]} -n 1); (( DEFAULTVOCF=DEFAULTVOCF-1 ))
      DEFAULTVOCF=${POSSIBLEVOCF[$DEFAULTVOCF]}

      LOCALROUTERVHTOPERCENTRFREQ=0
      while [ $LOCALROUTERVHTOPERCENTRFREQ -eq 0 ]; do
        echo "                       Please select the VHT Center Channel Frequency ${POSSIBLEVOCF[@]}"
        read -p "                     LOCALROUTER AccessPoint Channel? [Default: $DEFAULTVOCF] " INLOCALROUTERVHTOPERCENTRFREQ

        export INLOCALROUTERVHTOPERCENTRFREQ=${INLOCALROUTERVHTOPERCENTRFREQ:-$DEFAULTVOCF}
        if echo " ${POSSIBLEVOCF[@]} " | grep " $INLOCALROUTERVHTOPERCENTRFREQ " &>/dev/null; then
          export LOCALROUTERVHTOPERCENTRFREQ=$INLOCALROUTERVHTOPERCENTRFREQ
        else
          echo; echo "                       Sorry... value entered is not valid!"
        fi
      done
    fi

    cp -p -v --backup=t ${SOURCELOCALROUTERFILE} ${HOSTAPDCONF}
    var_sub_in_file ${HOSTAPDCONF}
    return 1
  fi
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
  backup_file ${UDEVRULESCONF}
  cat << EOF >> ${UDEVRULESCONF}
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="$ETHER", NAME="$WLAN"
EOF
}

add_udev_uplinkwlan() {
  WLAN=$1
  TARGETWLAN=$2
  ETHER=`ifconfig $WLAN | awk '/ether/ {print $2}'`
  backup_file ${UDEVRULESCONF}
  cat <<EOF >> ${UDEVRULESCONF}
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="$ETHER", NAME="$UPLINKWLAN"
EOF
}
