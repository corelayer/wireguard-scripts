#!/bin/sh

# Input validation
if [ $# -lt 6 ]; then
	echo "insufficient arguments (6): public_ip public_port interface_name server_name server_network enable_nat"
	exit 2
fi

if [ -f /etc/wireguard/scripts/server/config/server.var ]; then
	echo "server.var exists"
	exit 2
fi

if [ -f /etc/wireguard/scripts/server/config/server.conf ]; then
	echo "server.conf exists"
	exit 2
fi


if [ -f /etc/wireguard/scripts/server/config/server.key ]; then
	echo "server.key exists"
	exit 2
fi

if [ -f /etc/wireguard/scripts/server/config/server.pub ]; then
	echo "server.pub exists"
	exit 2
fi

if [ -d /etc/wireguard/server ]; then
	mkdir -p /etc/wireguard/server/config
fi

# Create server.var
cat > /etc/wireguard/scripts/server/config/server.var <<EOL
#!/bin/sh
PUBLIC_IP=${1}
PUBLIC_PORT=${2}
INTERFACE_NAME=${3}
SERVER_NAME=${4}
SERVER_NETWORK=${5}
SERVER_IP=1
ENABLE_NAT=${6}
EOL

# Load server variables
. /etc/wireguard/scripts/server/config/server.var


# Create server keys
echo "creating server keys"
wg genkey | tee /etc/wireguard/scripts/server/config/server.key | wg pubkey > /etc/wireguard/scripts/server/config/server.pub


# Set up server.conf template
echo "create server.conf"

cat > /etc/wireguard/scripts/server/config/server.conf <<EOL
[Interface]
Address = ${SERVER_NETWORK}.${SERVER_IP}/24
ListenPort = ${PUBLIC_PORT}
PrivateKey = $(cat /etc/wireguard/scripts/server/config/server.key)

PostUp = sh /etc/wireguard/scripts/server/iptables/post-up.sh ${INTERFACE_NAME} ${SERVER_NAME} ${ENABLE_NAT}
PostDown = sh /etc/wireguard/scripts/server/iptables/post-down.sh ${INTERFACE_NAME} ${SERVER_NAME} ${ENABLE_NAT}


EOL

echo "create ${SERVER_NAME}.conf"
cp /etc/wireguard/scripts/server/config/server.conf /etc/wireguard/${SERVER_NAME}.conf


echo "start wireguard server on ${SERVER_NAME}"
systemctl start wg-quick@${SERVER_NAME}

exit 0