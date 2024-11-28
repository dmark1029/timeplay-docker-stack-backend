#!/bin/bash
#
# See usage of the script, which will be printed by running this script without
# parameters
#
################################################################################

set -o nounset
set -o errexit
set -o pipefail

# check for web-client-service is running
while [ "$( docker container inspect -f '{{json .State.Health}}' keycloak | jq .Status -r )" != "healthy" ];
do
    echo "waiting..."
    sleep 5
done

# Globals
container_name="keycloak"
keycloak_url="http://127.0.0.1:8080"

group="${1:-}"
username="${2:-}"
password="${3:-}"
password_provided="true"
if [ "${password}" = "" ]; then
  password_provided="false"
  password=$(openssl rand -base64 64 | head -c 32)
fi
update="${4:-false}"

if [ $# -lt 3 ]; then
  >&2 echo "This script creates a new user using the stack environment variables"
  >&2 echo ""
  >&2 echo "Usage:"
  >&2 echo " ${0} <group> <username> [password] [update]"
  >&2 echo ""
  >&2 echo "Parameters:"
  >&2 echo "group - one of 'hosts', 'managers', 'admins'"
  >&2 echo "username - the username for the user you want to create"
  >&2 echo "password - optional, if not specified, a random string will be generated and"
  >&2 echo "           used instead"
  >&2 echo "update - true/false - optional, defaults to 'false', if 'true' then existing"
  >&2 echo "         users will be updated with the specified group/password, if false,"
  >&2 echo "         then if the user already exists, then they will not be updated"
  exit 1
fi

echo "starting create-user for user: ${username}"

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

echo "checking if user exists..."
user_id=$(docker exec -i "${container_name}" /bin/bash -s <<EOF | jq -r ".[] | select(.username==\"${username}\") | .id"
  curl -s --location --request GET "${keycloak_url}/auth/admin/realms/\${KEYCLOAK_USER_REALM}/users?username=${username}&exact=true" \
    --header 'Authorization: Bearer ${token}'
EOF
)

if [ -n "${user_id}" ]; then
  if [ "${update}" = "true" ]; then
    echo "existing user '${username}' found, updating password and group"

    echo "getting group id for group '${group}'"
    target_group_id=$(docker exec -i "${container_name}" /bin/bash -s <<EOF | jq -r ".[] | select(.name==\"${group}\") | .id"
      curl -s --location --request GET "${keycloak_url}/auth/admin/realms/\${KEYCLOAK_USER_REALM}/groups?search=${group}&exact=true" \
        --header 'Authorization: Bearer ${token}'
EOF
)

    echo "retrieving list of current user groups"
    attached_group_ids=$(docker exec -i "${container_name}" /bin/bash -s <<EOF | jq -r '.[] | .id'
      curl -s --location --request GET "${keycloak_url}/auth/admin/realms/\${KEYCLOAK_USER_REALM}/users/${user_id}/groups" \
        --header 'Authorization: Bearer ${token}'
EOF
)

    echo "removing user from all groups that don't match the expected group"
    while read -r group_id; do
      [ -z "${group_id}" ] && continue
      [ "${group_id}" = "${target_group_id}" ] && continue

      docker exec -i "${container_name}" /bin/bash -s <<EOF | jq -r '.[] | .id'
        curl -s --location --request DELETE "${keycloak_url}/auth/admin/realms/\${KEYCLOAK_USER_REALM}/users/${user_id}/groups/${group_id}" \
          --header 'Authorization: Bearer ${token}'
EOF
    done <<< "${attached_group_ids}"

    echo "adding user to target group: '${group}'"
    docker exec -i "${container_name}" /bin/bash -s <<EOF | jq -r '.[] | .id'
      curl -s --location --request PUT "${keycloak_url}/auth/admin/realms/\${KEYCLOAK_USER_REALM}/users/${user_id}/groups/${target_group_id}" \
        --header 'Authorization: Bearer ${token}'
EOF
  else
    echo "existing user found, but update flag is '${update}' != true, skipping update"
  fi
else
  echo "user does not exist, creating User '${username}'..."

  # Note: we use groups to assign roles since it doesn't look like we can
  #       directly assign roles on account creation, see:
  #
  #           https://stackoverflow.com/a/68549726
  #
  docker exec -i "${container_name}" /bin/bash -s <<EOF
  user_data='{
              "username": "${username}",
              "enabled": "true",
              "credentials": [{
                "type":"password", "temporary": false, "value":"${password}"
              }],
              "groups": [
                "${group}"
              ]
            }'

  curl -s --location --request POST "${keycloak_url}/auth/admin/realms/\${KEYCLOAK_USER_REALM}/users" \
    --header 'Authorization: Bearer ${token}' \
    --header 'Content-Type: application/json' \
    --data-raw "\${user_data}"
EOF

fi

echo "complete, user created/updated:"
echo "  username: ${username}"

# We only want to print out the password if it wasn't provided, as thats the
# only way to get it otherwise
if [ "${password_provided}" = "false" ]; then
  echo "  password: ${password}"
fi
