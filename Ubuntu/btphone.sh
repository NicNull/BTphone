#!/bin/bash
## Bluetooth phone presence script for Ubuntu 18.04 (xdg desktop) - called via cron each minute. (* * * * * /usr/local/bin/btphone.sh)
## https://github.com/NicNull/BTphone
## Requires hcitool and bluetoothctl via 'apt install bluez'

MAC="00:00:00:00:00:00"					#Phone BT MAC adr to monitor
RSSIlevel="2"						#RSSI threshold for away status, depends on dongle - use 'btphone.sh -v' to manually assess return value
LOCK="2"						#Threshold for actual lock
NOTIFY="normal"						#Desktop notify level. low, normal, critical. A critical level makes notify sticky.
btutil="/usr/bin/hcitool"				#hcitool used for polling RSSI values
btconnect="/usr/bin/bluetoothctl"			#bluetoothctl used to force reconnect to phone
scrsave="/usr/bin/xdg-screensaver activate" 		#1:st stage screen saver command 
scrlock="/usr/bin/xdg-screensaver lock" 		#2:nd stage lock command 
scrunlock="/usr/bin/xdg-screensaver reset" 		#scrsave clear command      (Doesn't work on xdg-utils <1.1.3-1 , ubuntu 18.04 uses 1.1.2-1) 
#scrunlock="/usr/bin/xset s reset" 			#alt scrsave clear command  (See: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=914613) 
enabledisp="/usr/bin/xset dpms force on" 		#monitor on command 
disabledisp="/usr/bin/xset dpms force off" 		#monitor off command 

##Set up Display Session Address for crontabs sake
export $(egrep -z DBUS_SESSION_BUS_ADDRESS /proc/$(pgrep -u $LOGNAME gnome-session)/environ |tr -d '\0') 
export DISPLAY=":1" 					#Might be different for other Desktop Environments that of Ubuntu default DE

echo $(date) > /tmp/btphone

#Try to connect 3 times and find lowest RSSI
RSSI=255
for retry in {1..3}; do 
    if [ "x$1" == "x-v" ]; then
        echo -n "Connecting to: $MAC "
    fi
    init=$(echo connect $MAC |$btconnect)
    sleep 2 						#Sleep just enough to establish connection, 1s is too low, 3s is too long.

    result=$($btutil rssi $MAC 2>&1)
    echo "result($retry): [$result]" >> /tmp/btphone
    if [ "x$result" = "xNot connected." ]; then
        result="$result: 255"
    fi
    myRSSI=$(echo "$result" |cut -f 2 -d ':' |cut -f 2 -d ' '|sed s/-//)
    if [ "x$myRSSI" = "xInput/output" ]; then
        myRSSI=255
    fi
    if [ "x$myRSSI" = "x" ]; then
        myRSSI=255
    fi
    echo "RSSI($retry): [$myRSSI]" >> /tmp/btphone
    if [ $myRSSI -lt $RSSI ]; then
        RSSI=$myRSSI 
    fi
    if [ "x$1" == "x-v" ]; then
        echo "RSSI: $myRSSI ($retry)"
    fi
    init=$(echo disconnect $MAC |$btconnect 2>&1)	#Comment out to disable force disconnect if phone needs a permanent connection for calls and audio
done

echo "RSSI: [$RSSI]" >> /tmp/btphone
if [ "x$1" == "x-v" ]; then
    echo "$MAC BT Signal level: -$RSSI dB"
fi
if [ $RSSI -le $RSSIlevel ]; then
    if [ -f /tmp/nophone ]; then
	$enabledisp
        $scrunlock
	sleep 1
        notify-send -u $NOTIFY -t 20000 -i info "Phone Presence" "Phone presence detected  RSSI: -$RSSI dB"
        rm /tmp/nophone
    fi
fi
if [ $RSSI -gt $RSSIlevel ]; then
    if [ ! -f /tmp/nophone ]; then
            notify-send -u $NOTIFY -t 20000 -i info "Phone Presence" "Auto started screen saver - Phone away detected!  RSSI: -$RSSI dB"
        if [ "x$1" == "x-v" ]; then
	    echo "SCREEN SAVER ACTIVE"
        fi
	sleep 3
        $scrsave
    	echo 0 > /tmp/nophone
    fi
    count=$((`cat /tmp/nophone` + 1))
    echo $count > /tmp/nophone
    if [ $count -eq $LOCK ]; then
            notify-send -u $NOTIFY -t 20000 -i info "Phone Presence" "Auto locked screen - No phone detected ($count)!  RSSI: -$RSSI dB"
        if [ "x$1" == "x-v" ]; then
	    echo "SCREEN LOCK ACTIVE"
        fi
	sleep 2
	$disabledisp
        $scrlock
    fi
fi
