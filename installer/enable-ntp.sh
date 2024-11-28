#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "${0} <ntp server>"
    exit 1
fi

ntpServerIP="${1}"

sed -i.bak "s|^pool .*$|pool ${ntpServerIP} iburst|" "/etc/chrony.conf" && rm -f "/etc/chrony.conf.bak"

systemctl enable chronyd.service
systemctl restart chronyd.service

echo ""
echo "== chrony Sources =="
chronyc sources
chronyc sources | grep -q "${ntpServerIP}"
if [ $? -ne 0 ]; then
    echo "ntp configuration failed, 'chronyc sources' does not contain the set ip"
    exit 1
fi

echo ""
echo "== timedate status =="
timedatectl status
timedatectl status | grep -q "NTP service: active"
if [ $? -ne 0 ]; then
    echo "ntp configuration failed, 'timedateclt status' does not have service set to 'active'"
    exit 1
fi

echo ""
echo "NTP configuration completed without issues"
