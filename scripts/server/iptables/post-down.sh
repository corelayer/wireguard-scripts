#!/bin/sh

INTERFACE_NAME=$1
SERVER_NAME=$2
ENABLE_NAT=$3


iptables -D FORWARD -i ${SERVER_NAME} -j ACCEPT

if [ ${ENABLE_NAT} -eq 1 ]; then
    iptables -t nat -D POSTROUTING -o ${INTERFACE_NAME} -j MASQUERADE
fi

find /etc/wireguard/scripts/server/iptables/conf.d/down/ -maxdepth 1 -name "*.sh" | sort | xargs -n1 sh

iptables-restore  < /etc/wireguard/scripts/server/iptables/conf.d/iptables-export