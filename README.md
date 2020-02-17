# BTphone
Bluetooth RSSI phone monitor script to activate screen saver
Script for MACOS and Ubuntu 18.04 to run periodically from crontab


MACOS:
requires /usr/local/opt/blueutil/bin/blueutil via homebrew ->
	brew install blueutil

Ubuntu (Tested on 18.04):
requires hciutil -> 
	apt install bluez

Install:
Requires that a active phone pairing exists from MACOS/Ubuntu to enable RSSI polling.
Locate and write down your phone BT MAC address when you set up the pairing.

MACOS:  Update 'MAC="00-00-00-00-00-00"' field in the script.
Ubuntu: Update 'MAC="00:00:00:00:00:00"' field in the script.
Note: MACOS uses '-' and Ubuntu uses ':' as MAC address separator

Copy script to /usr/local/bin/
Run 'crontab -e' and add:
* * * * *  /usr/local/bin/btphone.sh

Check your RSSI level via 'btphone.sh -v' and update the "RSSIlevel" parameter in the script somewhat higher.

For MACOS the raw RSSI value is available but for Ubuntu the value is almost always 0 when close to the BT radio.

The file /tmp/btphone holds the last query result and the file /tmp/nophone exists if phone has been not been detected or RSSI value is over RSSIlevel

The script sends notifications to the destktop whenever the phone is away or comes close again, just comment those lines out if it gets annoying.

That should be it... 
