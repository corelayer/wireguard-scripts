#!/bin/sh

if [ $# -lt 4 ]; then
	echo "insufficient arguments (4): client_id client_name client_location reload_server"
	exit 2
fi

if ! [ -f server.var ]; then
	echo "server.var does not exist, create server first"
	exit 1
fi

# Load server variables
. ./server.var

echo "initialize client variables"
# Set variables
client_id=$(printf %03d $1)
client_ip=${SERVER_NETWORK}.$1
client_name=$2
client_location=$3
reload_server=$4

echo "validating input"
# Input validation
if [ $1 -lt 2 ]; then
	echo "client id must be greater than 1"
	exit 2
fi

if [ $1 -gt 254 ]; then
	echo "client id must be less than 254"
	exit 2
fi

search=${client_id}"_*.conf"
if [ -f $search ]; then
	echo "client id already exists"
	exit 2
fi

# Set up client
client=${client_id}_${client_name}_${client_location}
echo "setting up ${client}"

# Generate keys and config for new client
echo "creating client keys"
wg genkey | tee ${client}.key | wg pubkey > ${client}.pub

echo "creating client configuration"
cat > ${client}.conf <<EOL
[Interface]
PrivateKey = $(cat ${client}.key)
Address = ${client_ip}/24

PostUp = echo $'WATCHDOG_ENABLED=1\nWATCHDOG_RETRIES=3\nWIREGUARD_ADDRESS=${SERVER_NETWORK}.${SERVER_IP}\nWIREGUARD_INTERFACE=wg0\nSLEEP_TIMER=5\n' > /etc/wireguard/watchdog/watchdog.var
PostDown = echo $'WATCHDOG_ENABLED=0\nWATCHDOG_RETRIES=3\nWIREGUARD_ADDRESS=${SERVER_NETWORK}.${SERVER_IP}\nWIREGUARD_INTERFACE=wg0\nSLEEP_TIMER=5' > /etc/wireguard/watchdog/watchdog.var

[Peer]
PublicKey = $(cat server.pub)
Endpoint = ${PUBLIC_IP}:${PUBLIC_PORT}
AllowedIPs = ${SERVER_NETWORK}.${SERVER_IP}/32
PersistentKeepAlive = 25
EOL

# Reload server configuration
if [ $reload_server -eq 1 ]; then
	sh reload_server.sh
fi
exit 0