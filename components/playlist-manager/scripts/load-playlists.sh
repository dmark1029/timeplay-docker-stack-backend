#!/bin/bash
#
# This script will load packaged games and playlists
#
# Usage:
#   ./load-content.sh
#
################################################################################

set -o nounset
set -o errexit
set -o pipefail

## Globals
################################################################################
base_dir=$(readlink -f $(dirname "${0}"))

effective_env_file="${base_dir}/../../../effective.env"
if [ -f "${effective_env_file}" ]; then
    . "${effective_env_file}"
else
    >&2 echo "failed to find the effective_env_file: ${effective_env_file}, exiting with error"
    exit 1
fi
screen_ids=$(echo $SESSION_DEFINITIONS | jq --raw-output '[.[].screenId] | join(" ")')

## Script start
################################################################################

# Get an admin token to use
token=$(curl --location --request POST "${AUTH_URL_TOKEN}" \
         --header 'Content-Type: application/x-www-form-urlencoded' \
         --data-urlencode 'grant_type=password' \
         --data-urlencode 'client_id=tp-admin' \
         --data-urlencode "username=${AUTH_DEFAULT_ADMIN_USER}" \
         --data-urlencode "password=${AUTH_DEFAULT_ADMIN_PASS}" | jq -r .access_token)

# Sync by screen_ids
for screen_id in $screen_ids; do
    echo "starting sync for playlists from screen: ${screen_id}"
    result=$(curl -s --location --request POST "${EXTERNAL_URL_PLAYLIST_MANAGER}/playlist/sync" \
        --header "Authorization: Bearer ${token}" \
        --header "Content-Type: application/json" \
        --data-raw "{\"screenId\":${screen_id},\"portalIp\":\"https://tools.timeplay.com\"}" | jq '.data[].id')
    echo "started sync for playlists:"
    echo "${result}"
    echo ""
done

echo "content sync for all playlists started"
