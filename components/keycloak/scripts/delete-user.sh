#!/bin/bash
#
# This script will delete the user with the specified username from the local
# keycloak container
#
# The container should be named "keycloak"
#
# Usage:
#   sh ./delete-user.sh <username>
#
################################################################################

set -o nounset
set -o errexit
set -o pipefail

username="${1}"

if [ -z "${username}" ]; then
    >&2 echo "################################################################################"
    >&2 echo "################################################################################"
    >&2 echo "## ERROR: you must specify a username to delete with this script:"
    >&2 echo "##"
    >&2 echo "##        sh ${0} <username to delete>"
    >&2 echo "##"
    >&2 echo "################################################################################"
    >&2 echo "################################################################################"
    exit 1
fi

# check for web-client-service is running
while [ "$( docker container inspect -f '{{json .State.Health}}' keycloak | jq .Status -r )" != "healthy" ];
do
    echo "waiting..."
    sleep 5
done

# Globals
container_name="keycloak"
keycloak_url="http://127.0.0.1:8080"

# Script
echo "fetching token..."
token=$(docker exec -i "${container_name}" /bin/bash -s <<EOF | jq -r .access_token
  curl -s --location --request POST '${keycloak_url}/auth/realms/master/protocol/openid-connect/token' \
    --header 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode 'grant_type=password' \
    --data-urlencode 'client_id=admin-cli' \
    --data-urlencode "username=\${KEYCLOAK_ADMIN}" \
    --data-urlencode "password=\${KEYCLOAK_ADMIN_PASSWORD}"
EOF
)

echo "fetching user info..."
user_id=$(docker exec -i "${container_name}" /bin/bash -s <<EOF | jq -r ".[] | select(.username==\"${username}\") | .id"
  curl -s --location --request GET "${keycloak_url}/auth/admin/realms/\${KEYCLOAK_USER_REALM}/users?username=${username}&exact=true" \
    --header 'Authorization: Bearer ${token}'
EOF
)
if [ -n "${user_id}" ]; then
  echo "found user: ${user_id}, deleting..."

  docker exec -i "${container_name}" /bin/bash -s <<EOF
    curl -s --location --request DELETE "${keycloak_url}/auth/admin/realms/\${KEYCLOAK_USER_REALM}/users/${user_id}" \
      --header 'Authorization: Bearer ${token}'
EOF

  echo "complete"
else
  echo "no admin user present, skipping"
fi
