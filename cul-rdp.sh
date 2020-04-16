#!/bin/bash

##########################################################
#
# CUL REMOTE DESKTOP GUI
# John Munzo - 2020
# Columbia University Libraries
#
# Based on xfreerdp-gui by Prof. Wyllian Bezerra da Silva
#
##########################################################

# Set some vars
ICON=/usr/share/cul/cu_crown.png

# Check for Dependencies

string=""

if ! hash xfreerdp 2>/dev/null; then
 string="\nfreerdp-x11"
fi

if !hash awk 2>/dev/null; then
 string="\ngawk"
fi

if ! hash xdpyinfo 2>/dev/null; then
 string="${string}\nx11-utils"
fi

if ! hash yad 2>/dev/null; then
 string="${string}\nyad"
fi

if [ -n "$string" ]; then
 if hash amixer 2>/dev/null; then
  amixer set Master 80% > /dev/null 2>&1;
 else
  pactl set-sink-volume 0 80%
 fi
 if hash speaker-test 2>/dev/null; then
  ((speaker-test -t sine -f 880 > /dev/null 2>&1) & pid=$!; sleep 0.2s; kill -9 $pid) > /dev/null 2>&1
 else
  if hash play 2>/dev/null; then
   play -n synth 0.1 sin 880 > /dev/null 2>&1
  else
   cat /dev/urandom | tr -dc '0-9' | fold -w 32 | sed 60q | aplay -r 9000 > /dev/null 2>&1
  fi
 fi
 (zenity --info --title="Requirements" --width=300 --text="You need to install these packages: <b>$string</b> ") > /dev/null 2>&1
 exit
fi

# Get System Information
dim=$(xdpyinfo | grep dimensions | sed -r 's/^[^0-9]*([0-9]+x[0-9]+).*$/\1/')
wxh1=$(echo $dim | sed -r 's/x.*//')"x"$(echo $dim | sed -r 's/.*x//')
wxh2=$(($(echo $dim | sed -r 's/x.*//')-70))"x"$(($(echo $dim | sed -r 's/.*x//')-70))

# Prompt for Input

while true
do

LOGIN=
PASSWORD=
DOMAIN=
SERVER=
RESOLUTION=
BPP=
FSCREEN=
varFull=

[ -n "$USER" ] && until xdotool search "xfreerdp-gui" windowactivate key Right Tab 2>/dev/null ; do sleep 0.03; done &
MAINFORM=$(yad --center --width=480 --title "CUL RDP" --item-separator="," --window-icon=$ICON \
 --form \
 --field="Workstation" $SERVER "TS10BU1A1" \
 --field="Domain" $DOMAIN "CC.COLUMBIA.EDU" \
 --field="UNI" $LOGIN "" \
 --field="Password":H $PASSWORD "" \
 --field="Resolution":CBE $RESOLUTION "$wxh1,$wxh2,800x600,1024x768,1280x1024,1600x1200,1920x1080" \
 --field="Color Depth":CBE $BPP "32,24,16" \
 --field="Full Screen":CHK $varFull \
 --button="Cancel":1 --button="Connect":0)
[ $? != 0 ] && exit
SERVER=$(echo $MAINFORM | awk -F '|' '{print $1}')
DOMAIN=$(echo $MAINFORM | awk -F '|' '{print $2}')
LOGIN=$(echo $MAINFORM | awk -F '|' '{print $3}')
PASSWORD=$(echo $MAINFORM | awk -F '|' '{print $4}')
RESOLUTION=$(echo $MAINFORM | awk -F '|' '{print $5}')
BPP=$(echo $MAINFORM | awk -F '|' '{print $6}')
varFull=$(echo $MAINFORM | awk -F '|' '{print $7}')

if [ "$varFull" = "TRUE" ]; then
 FSCREEN="/f"
else
 FSCREEN=""
fi

if [ "$SERVER" == "" ]; then 
yad --center --width=480 --window-icon="error" --title "Missing Information" \
 --text="<b>ERROR: No Workstation Provided!</b>\n\n<i>Please check to make sure your workstation name was entered in the appropriate field!</i>" \
 --text-align=center --button=gtk-ok --buttons-layout=spread && continue

elif [ "$LOGIN" == "" ]; then 
yad --center --width=480 --window-icon="error" --title "Missing Information" \
 --text="<b>ERROR: No UNI Provided!</b>\n\n<i>Please check to make sure your UNI was entered in the appropriate field!</i>" \
 --text-align=center --button=gtk-ok --buttons-layout=spread && continue

elif [ "$PASSWORD" == "" ]; then 
 yad --center --width=480 --window-icon="error" --title "Missing Information" \
 --text="<b>ERROR: No Password Provided!</b>\n\n<i>Please check to make sure your password was entered in the appropriate field!</i>" \
 --text-align=center --button=gtk-ok --buttons-layout=spread && continue

elif [ "$DOMAIN" == "" ]; then 
 yad --center --width=480 --window-icon="error" --title "Missing Information" \
 --text="<b>ERROR: No Domain Provided!</b>\n\n<i>Please check to make sure your domain was entered in the appropriate field!</i>" \
 --text-align=center --button=gtk-ok --buttons-layout=spread && continue

else
 yad --center --width=480 --window-icon="gnome-dev-computer" --title "Attempting Connection" \
 --text="Attempting to connect to remote workstation..." \
 --text-align=center --no-buttons & yad_pid=$(echo $!)

RES=$(xfreerdp \
 /v:"$SERVER".cul.columbia.edu:3389 \
 /sec-tls $GEOMETRY \
 /cert-tofu /cert-ignore \
 /d:"$DOMAIN" \
 /u:"$LOGIN" \
 /p:"$PASSWORD" \
 /bpp:$BPP \
 /size:$RESOLUTION \
 /sound \
 /decorations \
 /window-drag \
 2>&1)
fi

kill $yad_pid

echo $RES | grep --line-buffered -q "ERROR*" && \
yad --center --image="error" --window-icon="error" --title="Authentication Failure" \
 --text="<b>Could not authenticate to server\!</b>\n\n<i>Please check to make sure your information was entered correctly.</i>" \
 --text-align=center --width=480 --button=gtk-ok --buttons-layout=spread && continue

break
done
