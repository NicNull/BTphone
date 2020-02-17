#/bin/bash
## Bluetooth phone presence script - called via cron each minute.
## https://github.com/NicNull/BTphone
## requires /usr/local/opt/blueutil/bin/blueutil via homebrew
MAC="00-00-00-00-00-00"  
RSSIlevel="78"
btutil="/usr/local/opt/blueutil/bin/blueutil"

echo "`date`" > /tmp/btphone
#Try to connect 3 times
for retry in {1..3}; do 
    if [ "x$1" == "x-v" ]; then
        echo "Connecting to: $MAC ($retry)"
    fi
    init="`$btutil --connect $MAC 2>&1`"
    echo "init($retry): [$init]" >> /tmp/btphone
    if [ "x$init" == "x" ]; then 
       break 
    fi 
    sleep 1
done

result="`$btutil --info $MAC --format json-pretty --disconnect $MAC 2>&1`"
echo "result: [$result]" >> /tmp/btphone

RSSI="`echo "$result" |grep -i 'rawRSSI' |cut -f 2 -d '-' |cut -f 1 -d ','`"
if [ "x$RSSI" = "x" ]; then
    RSSI=255
fi
if [ "x$1" == "x-v" ]; then
    echo "$MAC BT Signal level: -$RSSI dB"
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

