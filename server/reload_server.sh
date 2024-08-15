#!/bin/sh

if ! [ -f server.var ]; then
	echo "server.var does not exist, create server first"
	exit 1
fi

if ! [ -f server.conf ]; then
	echo "server.conf does not exist, create server first"
	exit 1
fi

# Load server variables
. ./server.var

# Rebuild wg0.conf
echo "update server configuration"
cat server.conf > ${SERVER_NAME}.conf

i=2
imax=254

while [ $i -le $imax ]
do
        current_id=$(printf %03d ${i})
        current_ip=${SERVER_NETWORK}.${i}
        current_config=${current_id}*.conf
        current_name=$(echo $current_config)
        if [ -f ${current_config} ]; then
                echo "adding client ${current_id} $current_name"
                cat >> ${SERVER_NAME}.conf <<EOL
# $current_name
[Peer]
PublicKey = $(cat ${current_id}*.pub)
AllowedIPs = ${current_ip}/32

EOL
        fi
        true $((i=i+1))
done

echo "reload systemd service for ${SERVER_NAME}"
systemctl reload wg-quick@${SERVER_NAME}

exit 0