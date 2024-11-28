#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

base_dir=$(readlink -f $(dirname "${0}"))
effective_env_file="${base_dir}/../../effective.env"

if [ -f "${effective_env_file}" ]; then
    . "${effective_env_file}"
else
    >&2 echo "failed to find the effective_env_file: ${effective_env_file}, exiting with error"
    exit 1
fi

while [ "$( docker container inspect -f '{{json .State.Health}}' keycloak | jq .Status -r )" != "healthy" ];
do
    echo "waiting..."
    sleep 5
done

docker exec -i keycloak /bin/sh -c "kc_import.sh"

sh "${base_dir}/scripts/create-user.sh" "hosts" "${AUTH_DEFAULT_HOST_USER}" "${AUTH_DEFAULT_HOST_PASS}" "false"
sh "${base_dir}/scripts/create-user.sh" "managers" "${AUTH_DEFAULT_MANAGER_USER}" "${AUTH_DEFAULT_MANAGER_PASS}" "false"
sh "${base_dir}/scripts/create-user.sh" "casino-managers" "${AUTH_DEFAULT_CASINO_MANAGER_USER}" "${AUTH_DEFAULT_CASINO_MANAGER_PASS}" "false"
sh "${base_dir}/scripts/create-user.sh" "cage-managers" "${AUTH_DEFAULT_CAGE_MANAGER_USER}" "${AUTH_DEFAULT_CAGE_MANAGER_PASS}" "false"
sh "${base_dir}/scripts/create-user.sh" "casino-hosts" "${AUTH_DEFAULT_CASINO_HOST_USER}" "${AUTH_DEFAULT_CASINO_HOST_PASS}" "false"

# Note: as a bunch of scripts use the admin user, we want to ensure that its credentials are always up to date
sh "${base_dir}/scripts/create-user.sh" "admins" "${AUTH_DEFAULT_ADMIN_USER}" "${AUTH_DEFAULT_ADMIN_PASS}" "true"
