#!/bin/sh

# Input validation
if [ $# -lt 7 ]; then
	echo "insufficient arguments (7): public_ip public_port interface_name server_name server_network enable_nat"
	exit 2
fi

if [ -f server.var ]; then
	echo "server.var exists"
	exit 2
fi

if [ -f server.conf ]; then
	echo "server.conf exists"
	exit 2
fi


if [ -f server.key ]; then
	echo "server.key exists"
	exit 2
fi

if [ -f server.pub ]; then
	echo "server.pub exists"
	exit 2
fi


# Set variables
echo "initialize server variables"
public_ip=$1
public_port=$2
interface_name=$3
server_name=$4
server_network=$5
enable_nat=$6


# Create server.var
cat > server.var <<EOL
#!/bin/sh
PUBLIC_IP=${public_ip}
PUBLIC_PORT=${public_port}
INTERFACE_NAME=${interface_name}
SERVER_NAME=${server_name}
SERVER_NETWORK=${server_network}
SERVER_IP=1
ENABLE_NAT=${enable_nat}
EOL


# Create server keys
echo "creating server keys"
wg genkey | tee server.key | wg pubkey > server.pub


# Set up server.conf template
echo "create server.conf"

if [ ${enable_nat} -eq 0 ]; then
cat > server.conf <<EOL
[Interface]
Address = ${server_network}.${server_ip}/24
ListenPort = ${public_port}
PrivateKey = $(cat server.key)

PostUp = iptables -A FORWARD -i ${server_name} -j ACCEPT
PostDown = iptables -D FORWARD -i ${server_name} -j ACCEPT


EOL
else
cat > server.conf <<EOL
[Interface]
Address = ${server_network}.${server_ip}/24
ListenPort = ${public_port}
PrivateKey = $(cat server.key)

PostUp = iptables -A FORWARD -i ${server_name} -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o ${interface_name} -j MASQUERADE
PostDown = iptables -D FORWARD -i ${server_name} -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o ${interface_name} -j MASQUERADE


EOL
fi

echo "create ${server_name}.conf"
cp server.conf ${server_name}.conf
exit 0