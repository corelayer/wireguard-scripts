#!/bin/sh

if ! [ -f /etc/wireguard/watchdog.var ]; then
    echo "could not find /etc/wireguard/watchdog.var"
    exit 1
fi

# Load monitor variables
. /etc/wireguard/watchdog.var

if ! [ $WATCHDOG_ENABLED -eq 1 ]; then
    echo "watchdog is disabled"
    exit 0
fi

ping_command="ping -q -c 1 -W 1 $WIREGUARD_ADDRESS"

i=0
while [ $i -le $WATCHDOG_RETRIES ]
do
    if ! [ $i -eq 0 ]; then
        sleep 5s
        echo "retrying to connect to wireguard network, rety attempt $i"
    fi

    if $ping_command > /dev/null
	then
        exit 0
    fi
    
    echo "wireguard network is unavailable"
	true $((i=i+1))
done

restart_command="systemctl restart wg-quick@${WIREGUARD_INTERFACE}"
if $restart_command
then
    echo "restarted wireguard connection"
    exit 0
else
    echo "failed to restart wireguard connection"
    exit 1
fi