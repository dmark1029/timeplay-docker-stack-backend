#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

base_dir=$(readlink -f $(dirname "${0}"))
effective_env_file="${base_dir}/../../effective.env"
LICENSE_FILE="${base_dir}/license.json"

if [ -f "${effective_env_file}" ]; then
    . "${effective_env_file}"
else
    >&2 echo "failed to find the effective_env_file: ${effective_env_file}, exiting with error"
    exit 1
fi

## Write License File
echo "====> Generating license.json file at: ${LICENSE_FILE}"
cat << EOF > "${LICENSE_FILE}"
[{
    "key": "${STACK_LICENSE:-}",
    "expiresAt": "3000-12-28T00:00:00.000Z",
    "configs": {
        "screenIds": "${SCREEN_IDS:-}",
        "roomName": "${STACK_ID:-}",
        "roomServer": "${EXTERNAL_URL_GAME_ROOM}",
        "assetManagerHost": "${EXTERNAL_URL_ASSET_MANAGER}",
        "playlistServer": "${EXTERNAL_URL_PLAYLIST_MANAGER}",
        "packageServerHost": "${EXTERNAL_URL_GS_PACKAGE_SERVICE}",
        "auth_token_uri": "${AUTH_URL_TOKEN}",
        "client_id": "${AUTH_SERVICE_ID:-}",
        "client_secret": "${AUTH_SERVICE_SECRET:-}"
    }
}]
EOF

# check for gs-license-service is running
while [ "$( docker container inspect -f '{{.State.Running}}' gs-license-service )" == "false" ];
do
    echo waiting
    sleep 5
done

docker cp "${LICENSE_FILE}" "gs-license-service:/license.json"
docker exec -i gs-license-service sh -c "npm run setup /license.json"