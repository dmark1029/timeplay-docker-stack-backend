#!/bin/sh

# NOTE: Currently only tested on macOS. This will not work on Windows.

# Store the current IPv4 address
current_ip=$(ifconfig en0 | grep 'inet ' | awk '{print $2}')

# Store the current HOST_NAME, from overrides.env
current_host=$(cat overrides.env | grep HOST_NAME= | head -n 1 | cut -d'=' -f2)

# Get the old IP
old_ip=$(cat overrides.env | grep HOST_IP= | head -n 1 | cut -d'=' -f2)

echo $current_host
echo $old_ip

# Check if the IPv4 address has changed
if [ "$current_ip" != "$old_ip" ]; then
    # Update the /etc/hosts file with the new IP address
    sed -i.bak -e "s/\(.*\)$current_host/$current_ip $current_host/" '/etc/hosts' && rm -f '/etc/hosts.bak'
    # Update the .env file with the new IP address
    sed -i.bak -e "s/\(.*\)HOST_IP=.*/\1HOST_IP=$current_ip/" 'overrides.env' && rm -f 'overrides.env.bak'
    echo "IP Updated"
fi
