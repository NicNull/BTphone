#!/bin/bash
## Bluetooth phone presence script for ubuntu 18.04 (xdg desktop) - called via cron each minute. (* * * * * /bin/bash /usr/local/bin/btphone.sh)
## https://github.com/NicNull/BTphone
## requires hciutil via apt install bluez
 
MAC="00:00:00:00:00:00"                                 #Phone BT MAC adr to monitor
RSSIlevel="2"                                           #RSSI threshold for away status, depends on dongle - use btphone -v to manually assess return value
LOCK="2"                                                #Threshold for actual lock
btutil="/usr/bin/hcitool"                               #
scrsave="/usr/bin/xdg-screensaver activate"             #1:st stage screen saver command
scrlock="/usr/bin/xdg-screensaver lock"                 #2:nd stage lock command
scrunlock="/usr/bin/xdg-screensaver reset"              #scrsave clear command  (Doensnât work on ubuntu 18.04)
scrunlock2="/usr/bin/xset s reset"                      #scrsave clear command  (-- ââ --)
enabledisp="/usr/bin/xset dpms force on"                #monitor on command
disabledisp="/usr/bin/xset dpms force off"              #monitor off command
 
##Set up Display session address for crontabs sake
export $(egrep -z DBUS_SESSION_BUS_ADDRESS /proc/$(pgrep -u $LOGNAME gnome-session)/environ |tr -d '\0')
export DISPLAY=":1"
 
echo "`date`" > /tmp/btphone
result="`$btutil rssi $MAC 2>&1`"
echo "result: [$result]" >> /tmp/btphone
if [ "x$result" = "xNot connected." ]; then
    result="$result: 255"
fi
 
RSSI="`echo "$result" |cut -f 2 -d ':' |cut -f 2 -d ' '|sed s/-//`"
if [ "x$RSSI" = "xInput/output error" ]; then
    RSSI=255
fi
if [ "x$RSSI" = "x" ]; then
    RSSI=255
fi
echo "RSSI: [$RSSI]" >> /tmp/btphone
if [ "x$1" == "x-v" ]; then
    echo "$MAC BT Signal level: -$RSSI dB"
fi
if [ $RSSI -le $RSSIlevel ]; then
    if [ -f /tmp/nophone ]; then
        $enabledisp
        $scrunlock2
        $scrunlock
        sleep 1
        notify-send -u normal -t 20000 -i info "Phone Presence" "Phone presence detected  RSSI: -$RSSI dB"
        rm /tmp/nophone
    fi
if [ $RSSI -gt $RSSIlevel ]; then
    if [ ! -f /tmp/nophone ]; then
        notify-send -u critical -i info "Phone Presence" "Auto started screen saver - Phone away detected!  RSSI: -$RSSI dB"
        if [ "x$1" == "-v" ]; then
            echo "SCREEN SAVER ACTIVE"
        fi
        sleep 5
        $scrsave
        echo 0 > /tmp/nophone
    fi
    count=$((`cat /tmp/nophone` + 1))
    echo $count > /tmp/nophone
    if [ $count -eq $LOCK ]; then
        notify-send -u critical -i info "Phone Presence" "Auto locked screen - No phone detected ($count)!  RSSI: -$RSSI dB"
        if [ "x$1" == "-v" ]; then
            echo "SCREEN LOCK ACTIVE"
        fi
        sleep 2
        $disabledisp
        $scrlock
    fi
fi
