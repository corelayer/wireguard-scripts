#!/bin/sh
mkdir -p /etc/wireguard
cp -R scripts /etc/wireguard/.

chown -R root:root /etc/wireguard/*
chmod -R 600 /etc/wireguard/*