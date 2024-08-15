#!/bin/sh

create_crontab_directory()
{
    if ! [ -d /etc/wireguard/watchdog/crontab ]; then
        mkdir -p /etc/wireguard/watchdog/crontab
    fi
}

add_crontab_entry()
{
    create_crontab_directory
    crontab -l > /etc/wireguard/watchdog/crontab/enable_watchdog.bak
    cp /etc/wireguard/watchdog/crontab/enable_watchdog.bak /etc/wireguard/watchdog/crontab/enable_watchdog.new
    sed -i -e '$a\* * * * * sh /etc/wireguard/watchdog/watchdog.sh run | logger -t wireguard-watchdog 2>&1' /etc/wireguard/watchdog/crontab/enable_watchdog.new
    crontab /etc/wireguard/watchdog/crontab/enable_watchdog.new
}

remove_crontab_entry()
{
    create_crontab_directory
    crontab -l > /etc/wireguard/watchdog/crontab/disable_watchdog.bak
    cp /etc/wireguard/watchdog/crontab/disable_watchdog.bak /etc/wireguard/watchdog/crontab/disable_watchdog.new
    sed -i -e '/wireguard-watchdog/d' /etc/wireguard/watchdog/crontab/disable_watchdog.new
    crontab /etc/wireguard/watchdog/crontab/disable_watchdog.new
}

is_connection_up()
{
    ping_command="ping -q -c 1 -W 1 $1"
    if $ping_command > /dev/null
    then
        # connection is up
        return 0
    fi
    # connection is down
    return 1
}

is_crontab_enabled()
{
    if crontab -l | grep -q wireguard-watchdog
    then
        # crontab entry found
        return 0
    fi
    # crontab entry not found
    return 1
}

is_watchdog_configured()
{
    if ! [ -f /etc/wireguard/watchdog/watchdog.var ]; then
        echo "could not find /etc/wireguard/watchdog/watchdog.var"
        return 1
    fi
    return 0
}

is_watchdog_enabled()
{
    # watchdog is enabled
    if [ $1 -eq 1 ]; then
        return 0
    fi
    # watchdog is disabled
    return 1
}

check_connection()
{
    WATCHDOG_ENTRIES=$1
    WIREGUARD_ADDRESS=$2
    SLEEP_TIMER=$3

    i=0
    while [ $i -le $WATCHDOG_RETRIES ]
    do
        if ! [ $i -eq 0 ]; then
            sleep $SLEEP_TIMER
            echo "retrying to connect to wireguard network, rety attempt $i"
        fi

        if is_connection_up $WIREGUARD_ADDRESS
    	then
            return 0
        fi

        echo "wireguard network is unavailable"
    	true $((i=i+1))
    done
    return 1
}


restart_connection()
{
    WIREGUARD_INTERFACE=$1
    WIREGUARD_ADDRESS=$2

    restart_command="systemctl restart wg-quick@$WIREGUARD_INTERFACE"
    if $restart_command;
    then
        echo "restarted wireguard connection"
        if is_connection_up $WIREGUARD_ADDRESS;
        then
            return 0
        fi
        return 1
    else
        echo "failed to restart wireguard connection"
        return 1
    fi
}

disable_watchdog()
{
    if ! is_crontab_enabled; then
        echo "watchdog is already disabled in crontab"
        exit 0
    fi
    remove_crontab_entry
}

enable_watchdog()
{
    if is_crontab_enabled; then
        echo "watchdog is already enabled in crontab"
        exit 0
    fi
    add_crontab_entry
}

run_watchdog()
{
    if ! is_watchdog_configured; then
        exit 1;
    fi

    # Load monitor variables
    . /etc/wireguard/watchdog/watchdog.var

    if ! is_watchdog_enabled $WATCHDOG_ENABLED; then
        echo "watchdog is disabled"
        exit 0
    fi

    if check_connection $WATCHDOG_RETRIES $WIREGUARD_ADDRESS $SLEEP_TIMER;
    then
        echo "connection is up"
        exit 0
    fi

    if restart_connection $WIREGUARD_INTERFACE $WIREGUARD_ADDRESS;
    then
        echo "connection restored"
        exit 0
    fi

    echo "failed to restore connection"
    exit 1
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