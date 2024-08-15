#!/bin/sh
cp -R scripts /etc/wireguard/.

chown -R root:root /etc/wireguard/*
chmod -R 600 /etc/wireguard/*