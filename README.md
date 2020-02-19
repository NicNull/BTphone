# BTphone
Bluetooth RSSI phone monitor script to activate screen saver.\
Script for MACOS and Ubuntu 18.04 to run periodically from crontab.

## MACOS (Tested on Catalina)
Requires /usr/local/opt/blueutil/bin/blueutil via homebrew:
```bash
brew install blueutil
```

## Ubuntu (Tested on 18.04)
Requires hcitool and bluetoothctl:
```bash
apt install bluez
```

## Install:
Requires that a active phone pairing exists from MACOS/Ubuntu to enable RSSI polling.\
Locate and write down your phone BT MAC address when you set up the pairing.

Update the ```MAC="00:00:00:00:00:00"``` field in the script.\
Set the number of loops per crontab call to scan for phone more than once a minute.\
Default is ```LOOPS=1```.\
Alternativly set ``POLL=1`` to continuosly scan for phone presence, this will ignore ``LOOPS`` setting.\
To use longer cron call intervals update the ``TIMESLOT=60`` setting corresponding to your set crontab interval, converted to seconds.

Copy script to /usr/local/bin/ and make sure that it is executable\
Run ```crontab -e``` and add:
```bash
* * * * *  /usr/local/bin/btphone.sh
```

Check your RSSI level manually via ``btphone.sh -v`` and update the ``RSSIlevel=""`` parameter in the script somewhat higher.\
``
For MACOS the raw RSSI value is available but for Ubuntu the value is almost always 0 when close to the BT radio.
``

The file ``/tmp/btphone`` holds the last query result and the file ``/tmp/nophone`` exists if phone has been not been detected or RSSI value is over RSSIlevel.

The script sends notifications to the desktop whenever the phone is away or comes close again, just comment those lines out if it gets annoying.


That should be it... 
