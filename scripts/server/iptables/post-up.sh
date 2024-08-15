#!/bin/sh

INTERFACE_NAME=$1
SERVER_NAME=$2
ENABLE_NAT=$3

iptables-save > /etc/wireguard/scripts/server/iptables/conf.d/iptables-export

iptables -A FORWARD -i ${SERVER_NAME} -j ACCEPT

if [ ${ENABLE_NAT} -eq 1 ]; then
    iptables -t nat -A POSTROUTING -o ${INTERFACE_NAME} -j MASQUERADE
fi

find /etc/wireguard/scripts/server/iptables/conf.d/up/ -maxdepth 1 -name "*.sh" | sort | xargs -n1 sh