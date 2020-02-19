#!/bin/bash
## Bluetooth phone presence script for ubuntu 18.04 (xdg desktop) - called via cron each minute. (* * * * * /usr/local/bin/btphone.sh)
## https://github.com/NicNull/BTphone
## requires hciutil and bluetoothctl via 'apt install bluez'

## Script Variables
MAC="00:00:00:00:00:00"     				#Phone BT MAC adr to monitor
RSSIlevel="5"            				#RSSI threshold for away status, depends on dongle - use 'btphone.sh -v' to manually assess return value
LOCK="2"						#Threshold for actual lock, number of phone AWAY detections
NOTIFY="low"            				#Desktop notify level. low, normal, critical. A critical level makes notify sticky.
LOOPS=1							#Number of iteration loops for each cron call
TIMESLOT=60						#Timeslot for exectution need to match crontab time interval
POLL=0                                                  #POLL=1 will poll BT RSSI continously with a 5s loop timeslot until Timeslot runs out. This ignores LOOPS setting

## System utilities
btutil="/usr/bin/hcitool"        			#hcitool used for polling RSSI values
btconnect="/usr/bin/bluetoothctl"      			#bluetoothctl used to force reconnect to phone
scrsave="/usr/bin/xdg-screensaver activate"   		#1:st stage screen saver command
scrlock="/usr/bin/xdg-screensaver lock"   	  	#2:nd stage lock command
scrunlock="/usr/bin/xdg-screensaver reset"    		#scrsave clear command      (Doesn't work on xdg-utils <1.1.3-1 , ubuntu 18.04 uses 1.1.2-1)
#scrunlock="/usr/bin/xset s reset"       		#alt scrsave clear command  (See: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=914613)
enabledisp="/usr/bin/xset dpms force on"     		#monitor on command
disabledisp="/usr/bin/xset dpms force off"    		#monitor off command

## Set up Display session address for crontabs sake
export $(egrep -z DBUS_SESSION_BUS_ADDRESS /proc/$(pgrep -u $LOGNAME gnome-session)/environ |tr -d '\0')
export DISPLAY=":1"

## Loop to check for phone presence $loops times for each cron cycle
WAIT=$(($TIMESLOT/$LOOPS))
if [ $POLL -eq 1 ]; then
   WAIT=5
else
    if [ $LOOPS -eq 1 ]; then
       WAIT=0                                                           #No loop wait if only running one loop
    else
       WAIT=$(($TIMESLOT/$LOOPS))                                       #Timeslot for each loop
    fi
fi
TS=$SECONDS                                                             #Timeslot timestamp
for ((loop=1;loop<=LOOPS || POLL;loop++)); do
		date=$(date "+%Y-%m-%d %H:%M:%S")
		echo "--- $date ---"> /tmp/btphone
        	T1=$SECONDS                                             #Loop Timestamp
        	if [ $(($T1-$TS+$WAIT)) -gt $TIMESLOT ]; then           #If timeslot vs looptime is running out exit loop. (probably due to conection timeout LAG)
            		break
        	fi

		# Try to connect 3 times and find lowest RSSI to filter out failed connections
		RSSI=255
		if [ "x$1" == "x-v" ]; then
			echo -n "Connecting to: $MAC  RSSI: "
		fi
		for ((retry=1;retry<=3;retry++)); do
				init=$(echo connect $MAC |$btconnect)
				## Sleep just enough to establish connection, 1s is too low, 3s is too long.
				sleep 1.9 
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
						echo -n "$retry:[$myRSSI] "
				fi
				## Comment out to disable force disconnect if phone needs a permanent connection for calls and audio
				init=$(echo disconnect $MAC |$btconnect 2>&1)
		done

		echo "Lowest RSSI: [$RSSI]" >> /tmp/btphone
		if [ "x$1" == "x-v" ]; then
				echo; echo "$MAC BT Signal level: -$RSSI dB"
		fi
		if [ $RSSI -le $RSSIlevel ]; then
			if [ -f /tmp/nophone ]; then
			    $enabledisp
			    $scrunlock
			    sleep 1
					notify-send -u $NOTIFY -t 20000 -i info "Phone Presence [$date]" "Phone presence detected  RSSI: -$RSSI dB"
					rm /tmp/nophone
			fi
		fi
		if [ $RSSI -gt $RSSIlevel ]; then
				if [ ! -f /tmp/nophone ]; then
						notify-send -u $NOTIFY -t 20000 -i info "Phone Away [$date]" "Auto started screen saver  RSSI: -$RSSI dB"
						if [ "x$1" == "x-v" ]; then
						    echo "SCREEN SAVER ACTIVE"
						fi
					  	sleep 1
						$scrsave
						echo 0 > /tmp/nophone
				fi
				count=$(($(cat /tmp/nophone) + 1))
				echo $count > /tmp/nophone
				if [ $count -eq $LOCK ]; then
						notify-send -u $NOTIFY -t 20000 -i info "Phone Away [$date]" "Auto locked screen  RSSI: -$RSSI dB"
						if [ "x$1" == "x-v" ]; then
							echo "SCREEN LOCK ACTIVE"
						fi
						sleep 1
						$disabledisp
						$scrlock
				fi
		fi
		T2=$SECONDS                                                  #Loop Timestamp
        	for ((TIME=$(($T2-$T1));TIME<WAIT;TIME++)); do
            		sleep 1
        	done
       		if [ "x$1" == "x-v" ]; then
	            	echo "Looptime: $(($T2-$T1))s Loop: $loop Timeslot: $(($SECONDS-$T1))s|$(($SECONDS-$TS))s|${TIMESLOT}s"
        	fi

done
