#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

# Define variables for configuration files and state
base_dir=$(dirname "${0}")

bash "${base_dir}/generate-configs.sh"
env_file="${base_dir}/effective.env"
init_script="${base_dir}/effective.init.sh"
target_compose_file="${base_dir}/effective.docker-compose.yml"

fetch_certs_script="${base_dir}/fetch-certs.sh"

# Main script logic
. "${env_file}"

echo "STACK_VERSION: ${STACK_VERSION}"
echo "STACK_PARTNER: ${STACK_PARTNER}"
echo "STACK_SCHEME: ${STACK_SCHEME}"
echo "STACK_COMPONENTS: ${STACK_COMPONENTS}"

deploy_folder="${base_dir}/deploy"
manifest_tpl_file="${base_dir}/manifest.tpl.json"
manifest_target_file="${base_dir}/manifest.json"

compose_params=("--env-file" "${env_file}" "-f" "${target_compose_file}")
while test $# -gt 0; do
  case "${1}" in
    start)
      # Always run the fetch_certs_script, as it will do nothing if certs are
      # already installed and up to date
      bash "${fetch_certs_script}"

      update_service_flags=()
      if [[ "${STACK_COMPONENTS}" == *'update-service'* ]]; then
        update_service_flags+=("--scale" "busybox=0")
      fi
      docker compose "${compose_params[@]}" up --scale room-message-bus=0 "${update_service_flags[@]}" --detach --remove-orphans
      ;;
    stop)
      docker compose "${compose_params[@]}" stop
      ;;
    down)
      docker compose "${compose_params[@]}" down
      ;;
    pull)
      docker compose "${compose_params[@]}" pull
      ;;
    fetch-certs)
      FORCE="true" bash "${fetch_certs_script}"
      ;;
    init)
      bash "${init_script}"
      ;;
    build)
      proxyServerDir="${base_dir}/proxy-server"
      # only triggers if you have the proxy-server locally, for development purposes only
      if [ -d "${proxyServerDir}" ]; then
        export artifactoryUser="${REPO_USERNAME}"
        export artifactoryPass="${REPO_PASSWORD}"

        pushd "${proxyServerDir}"
        npx --package @timeplay/pacman -- pacman ./build.json
        popd
      else
        echo "proxy-server folder missing, this is a dev only feature"
        exit 1
      fi
      ;;
    manifest)
      repository="ships-${STACK_PARTNER}"
      if [ -d "${deploy_folder}" ]; then
        repository="ships-internal"
      fi

      sed "s|@{REPO_NAME}|${repository}|g" "${manifest_tpl_file}" > "${manifest_target_file}"
      sed -i.bak "s|@{VERSION}|${STACK_VERSION}|g" "${manifest_target_file}" && rm -f "${manifest_target_file}.bak"
      sed -i.bak "s|@{REPO_BASE_URL}|${PUBLIC_REPO_BASE_URL}|g" "${manifest_target_file}" && rm -f "${manifest_target_file}.bak"

      # Find all variables that start with "PACKAGES_", and process each as a comma
      # separated list, creating a new item under the games section of the new manifest
      while read -r line ; do
        package_list="${line#*=}"
        if [[ "${package_list}" =~ ^\"(.*)\"$ ]]; then
          package_list="${BASH_REMATCH[1]}"
        elif [[ "${package_list}" =~ ^\'(.*)\'$ ]]; then
          package_list="${BASH_REMATCH[1]}"
        fi

        IFS=',' read -r -a package_array <<< "${package_list}"
        for package in "${package_array[@]}"; do
          gp_name=$(echo "${package}" | cut -d- -f1)
          gp_ver=$(echo "${package}" | cut -d- -f3-)
          gp_system=$(echo "${package}" | cut -d- -f2)

          jq ".games[.games|length] |= . + {
            \"uid\": \"${gp_system}/${gp_name}/${gp_ver}\",
            \"gpsUri\": \"https://ships-ss.timeplay.com/gps\"
          }" "${manifest_target_file}" > "${manifest_target_file}.tmp" && mv "${manifest_target_file}.tmp" "${manifest_target_file}"
        done
      done <<<"$(grep '^PACKAGES_' "${env_file}")"

      # Find all variables that start with "IMAGE_", process each item,
      # creating a new item under the "container-images" section of the new
      # manifest
      while read -r line ; do
        image="${line#*=}"
        if [[ "${image}" =~ ^\"(.*)\"$ ]]; then
          image="${BASH_REMATCH[1]}"
        elif [[ "${image}" =~ ^\'(.*)\'$ ]]; then
          image="${BASH_REMATCH[1]}"
        fi
        image="${image##*/}"

        image_name=$(echo "${image}" | cut -d: -f1)
        image_tag=$(echo "${image}" | cut -d: -f2-)

        jq ".\"container-images\"[.\"container-images\"|length] |= . + {
          \"uid\": \"docker/${image_name}/${image_tag}\",
          \"gpsUri\": \"https://ships-ss.timeplay.com/gps\"
        }" "${manifest_target_file}" > "${manifest_target_file}.tmp" && mv "${manifest_target_file}.tmp" "${manifest_target_file}"
      done <<<"$(grep '^IMAGE_' "${env_file}")"
      ;;
    *)
      echo "Usage: run.sh [start|stop|down|pull|fetch-certs|init|build|manifest]"
      exit 1
      ;;
  esac

  shift
done