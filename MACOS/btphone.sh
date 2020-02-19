#/bin/bash
## Bluetooth phone presence script - called via cron each minute.
## https://github.com/NicNull/BTphone
## requires /usr/local/opt/blueutil/bin/blueutil via homebrew

btutil="/usr/local/opt/blueutil/bin/blueutil"

MAC="00:00:00:00:00:00"							#Phone BT MAC to monitor, update with your MAC Address 
RSSIlevel="78"								#RSSIlevel is the threshold value for activationg screen saver
LOOPS=1 								#Used for script looping to decrease phone away detection  
POLL=0									#POLL=1 will poll BT RSSI continously with a 5s loop timeslot until Timeslot runs out. This ignores LOOPS setting  
TIMESLOT=60								#Timeslot for exectution need to match crontab time interval

if [ $POLL -eq 1 ]; then						
    WAIT=5 
else
    if [ $LOOPS -eq 1 ]; then						
       WAIT=0								#No loop wait if only running one loop
    else
       WAIT=$(($TIMESLOT/$LOOPS))					#Timeslot for each loop
    fi       
fi
TS=$SECONDS								#Timeslot timestamp
for ((loop=1;loop<=LOOPS || POLL;loop++)); do
	echo $(date "+%Y-%m-%d %H:%M:%S") > /tmp/btphone
	T1=$SECONDS							#Loop Timestamp
	if [ $(($T1-$TS+$WAIT)) -gt $TIMESLOT ]; then	    		#If timeslot vs looptime is running out exit loop. (probably due to conection timeout LAG)
	    break 
	fi 
	#Try to connect 	  					#Connection retry set to 2 times, as reconnect loop is 15s, screensaver lock takes 30s when phone is unreachable
	CONNECTED=2
	if [ "x$1" == "x-v" ]; then
	    echo -n "Connecting to: $MAC "
	fi
	for retry in {1..2}; do 
	    init="`$btutil --connect $MAC 2>&1`"
	    if [ "x$1" == "x-v" ]; then
		echo -n "."
	    fi
	    if [ "x$init" == "x" ]; then 
	       CONNECTED=1
	       break 
	    fi 
	    T2=$SECONDS							#Loop Timestamp
	    if [ $(($T2-$TS+$WAIT)) -gt $TIMESLOT ]; then		#If timeslot vs looptime is running out exit loop. (probably due to conection timeout LAG)
	        break 
	    fi 
	    echo "init($retry): [$init]" >> /tmp/btphone
	done

	if [ $CONNECTED ]; then
	     result="`$btutil --info $MAC --format json-pretty --disconnect $MAC 2>&1`"
	     echo "result: [$result]" >> /tmp/btphone
	else
	     result="rawRSSI:-255,"
	fi

	RSSI="`echo "$result" |grep -i 'rawRSSI' |cut -f 2 -d '-' |cut -f 1 -d ','`"
	if [ "x$RSSI" = "x" ]; then
	    RSSI=255
	fi
	if [ "x$1" == "x-v" ]; then
	    echo " RSSI: -$RSSI dB"
	fi
	if [ $RSSI -le $RSSIlevel ]; then
	    if [ -f /tmp/nophone ]; then
		osascript -e "display notification \"Phone presence detected - RSSI: -$RSSI dB\" with title \"Phone Presence\""
		rm /tmp/nophone
	    fi 
	fi
	if [ $RSSI -gt $RSSIlevel ]; then
	    if [ ! -f /tmp/nophone ]; then
		osascript -e "display notification \"Auto locked screen - No phone detected! RSSI: -$RSSI dB\" with title \"Phone Presence\""
		open -a ScreenSaverEngine
	    fi
	    touch /tmp/nophone
	fi
	T2=$SECONDS							#Loop Timestamp
	for ((TIME=$(($T2-$T1));TIME<WAIT;TIME++)); do
	    sleep 1
	done	
	if [ "x$1" == "x-v" ]; then
	    echo "Looptime: $(($T2-$T1))s Loop: $loop Timeslot: $(($SECONDS-$T1))s|$(($SECONDS-$TS))s|${TIMESLOT}s"
	fi
done

