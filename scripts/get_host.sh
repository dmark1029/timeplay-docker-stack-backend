#!/bin/bash

# Store the current HOST_NAME, from overrides.env
current_host=$(cat overrides.env | grep HOST_NAME= | head -n 1 | cut -d'=' -f2)

# echo "$current_host"

HOSTS_FILE="/etc/hosts"

if uname -r | grep -q "Microsoft"; then
    HOSTS_FILE="/mnt/c/Windows/System32/drivers/etc/hosts"
fi

cat "$HOSTS_FILE" | grep "$current_host" | grep -v "^#" | cut -d' ' -f1 | tr -d '\n'
