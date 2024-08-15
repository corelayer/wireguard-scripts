#!/bin/sh

create_crontab_directory()
{
    if ! [ -d /etc/wireguard/crontab ]; then
        mkdir -p /etc/wireguard/crontab
    fi
}

is_watchdog_enabled()
{
    # validate_command="crontab -l | grep wireguard-watchdog"
    if crontab -l | grep -q wireguard-watchdog
    then
        return 0
    else
        return 1
    fi
}

disable_watchdog()
{
    if ! is_watchdog_enabled; then
        echo "watchdog is already disabled"
        exit 0
    fi

    create_crontab_directory
    crontab -l > /etc/wireguard/crontab/disable_watchdog.bak
    cp /etc/wireguard/crontab/disable_watchdog.bak /etc/wireguard/crontab/disable_watchdog.new
    sed -i -e '/wireguard-watchdog/d' /etc/wireguard/crontab/disable_watchdog.new
    crontab /etc/wireguard/crontab/disable_watchdog.new
}

enable_watchdog()
{
    if is_watchdog_enabled; then 
        echo "watchdog is already enabled"
        exit 0
    fi

    create_crontab_directory
    crontab -l > /etc/wireguard/crontab/enable_watchdog.bak
    cp /etc/wireguard/crontab/enable_watchdog.bak /etc/wireguard/crontab/enable_watchdog.new
    sed -i -e '$a\* * * * * sh /etc/wireguard/watchdog.sh run | logger -t wireguard-watchdog 2>&1' /etc/wireguard/crontab/enable_watchdog.new
    crontab /etc/wireguard/crontab/enable_watchdog.new
}

run_watchdog()
{
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
}

case $1 in
    "disable")
        disable_watchdog
        ;;
    "enable")
        enable_watchdog
        ;;
    "run")
        run_watchdog
        ;;
    *)
        echo "unknown command: $1 [disable,enable,run]"
        ;;
esac