#!/bin/bash
#
# This script will load all local packages, and optionally will start the
# download for any specified remote packages.
#
# Local packages need to be placed under the "gs-packages" folder in the root
# installation directory, and must follow the naming convention:
#
# <package_name>-<system>-<version>.zip
#
# example:
# bingoplus-win64-1.0.0-52.zip
#
# Remote packages must follow the naming convention:
#
# <package_name>-<system>-<version>
#
# example:
# bingoplus-win64-1.0.0-52
#
# Usage:
#   ./load-content.sh [package(s) to download]
#
################################################################################

set -o nounset
set -o errexit
set -o pipefail

## Globals
################################################################################
base_dir=$(readlink -f $(dirname "${0}"))
gs_package_dir="${base_dir}/../../../gs-packages"

effective_env_file="${base_dir}/../../../effective.env"
if [ -f "${effective_env_file}" ]; then
    . "${effective_env_file}"
else
    >&2 echo "failed to find the effective_env_file: ${effective_env_file}, exiting with error"
    exit 1
fi

## Script start
################################################################################

# Get an admin token to use
token=$(curl --location --request POST "${AUTH_URL_TOKEN}" \
         --header 'Content-Type: application/x-www-form-urlencoded' \
         --data-urlencode 'grant_type=password' \
         --data-urlencode 'client_id=tp-admin' \
         --data-urlencode "username=${AUTH_DEFAULT_ADMIN_USER}" \
         --data-urlencode "password=${AUTH_DEFAULT_ADMIN_PASS}" | jq -r .access_token)

# Load the game packages from the local packages directory
if [ -d "${gs_package_dir}" ]; then
  echo "local gs-package directory '${gs_package_dir}' found, loading app packages:"
  pushd "${gs_package_dir}"
  for package_file_name in *.zip; do
    [ -f "${package_file_name}" ] || continue

    # Note: we expect all zips in the gs_package_dir to have the filename convention:
    #       <package_name>-<system>-<version>.zip
    # example: bingoplus-osx-1.0.0-52.zip

    # Removes the .zip extension
    package_name="${package_file_name%.*}"

    # Breaks out the individual components of the package name based on the convention
    gp_name=$(echo ${package_name} | cut -d- -f1)
    gp_system=$(echo ${package_name} | cut -d- -f2)
    if [ "${gp_system}" == "win" ]; then
        gp_system="win64"
    fi

    gp_ver=$(echo ${package_name} | cut -d- -f3-)

    result=$(curl -s --location --request POST "${EXTERNAL_URL_GS_PACKAGE_SERVICE}/games/${gp_system}/${gp_name}/${gp_ver}" \
        --header "Authorization: Bearer ${token}" \
        --header 'Content-Type: multipart/form-data' \
        --form "upload=@${package_file_name}" \
        --form "displayName=${gp_name}")
    echo "Game: ${gp_name}, System: ${gp_system}, Version: ${gp_ver}, Result: ${result}"
  done
  popd
  echo "all gs-packages in directory '${gs_package_dir}' loaded"
fi

# Load the game packages from the remote game package service
for gp in "$@"; do
  gp_name=$(echo ${gp} | cut -d- -f1)
  gp_ver=$(echo ${gp} | cut -d- -f2-)
  gp_system=$(echo ${gp} | cut -d- -f2)
  if [ "${gp_system}" == "win" ]; then
      gp_system="win64"
  fi

  gp_ver=$(echo ${gp} | cut -d- -f3-)

  result=$(curl -s --location --request POST "${EXTERNAL_URL_GS_PACKAGE_SERVICE}/games" \
     --header "Authorization: Bearer $token" \
     --header 'Content-Type: application/json' \
     --data-raw "{
        \"uid\": \"${gp_system}/${gp_name}/${gp_ver}\",
        \"gpsUri\": \"https://ships-ss.timeplay.com/gps\"
     }")
  echo "Game: ${gp_name}, System: ${gp_system}, Version: ${gp_ver}, Result: ${result}"
done

echo "content sync for all packages started"
