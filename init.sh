#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

base_dir=$(readlink -f $(dirname "${0}"))

effective_env_file="${base_dir}/effective.env"
if [ -f "${effective_env_file}" ]; then
    . "${effective_env_file}"
else
    >&2 echo "failed to find the effective_env_file: ${effective_env_file}, exiting with error"
    exit 1
fi

while :
do
    http_status_code=$(curl -IL "${EXTERNAL_URL_WEB_CLIENT_SERVICE}/hello" 2>&1 | awk '/^HTTP/{print $2}' | tail -n 1)
    if [ "${http_status_code}" == "200" ]; then
        echo "====> web-client-service ready!"
        break
    fi

    echo "====> Waiting for web-client-service..."
    sleep 5
done

echo "executing init commands..."
docker exec -i web-client-service sh -c "npm run setup ./scripts/registration-sample.json"
