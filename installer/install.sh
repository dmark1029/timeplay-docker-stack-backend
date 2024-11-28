#!/bin/bash
#
# To use this script you need a file named "defaults.env" in the same
# directory.  This file should have the same keys as "defaults.example.env" the
# file.  For more information see the aformentioned file.
#
# Usage:
#    [RUN_INIT=true|false] sh install.sh <path-to-overrides-file>
#
# Note:
#  This script can be run by inlining the RUN_INIT variable as shown above.
#  Alternatively, you can define a defaults.env file in the same directory to
#  define the RUN_INIT value.
#
#  The separate file method is still needed as certain partners set a sudoers
#  files to allow us specific commands we can run.  The only way to pass in
#  environment variables in these environments is to side-load them from a
#  pre-defined file like we're doing here.
#
###############################################################################

set -o nounset
set -o errexit
set -o pipefail

###############################################################################
# Setup variables
###############################################################################
base_dir=$(readlink -f $(dirname "${0}"))
overrides_env_file="${1:-}"
defaults_env_file="${base_dir}/defaults.env"
configs_dir="${base_dir}/configs"
stack_dir="${base_dir}/stack"
images_dir="${base_dir}/images"
gs_package_dir="${base_dir}/gs-packages"

###############################################################################
# Checks
###############################################################################
if [ ! "$(whoami)" = "root" ]; then
    >&2 echo "################################################################################"
    >&2 echo "################################################################################"
    >&2 echo "## ERROR: Please run this script with the root user, or through sudo"
    >&2 echo "################################################################################"
    >&2 echo "################################################################################"
    exit 1
fi

if [ -z "${overrides_env_file}" ]; then
    >&2 echo "################################################################################"
    >&2 echo "################################################################################"
    >&2 echo "## ERROR: you must specify an overrides file to run this script:"
    >&2 echo "##"
    >&2 echo "##        sh ${0} <path-to-overrides-file>"
    >&2 echo "##"
    >&2 echo "################################################################################"
    >&2 echo "################################################################################"
    exit 1
fi

if [ ! -f "${overrides_env_file}" ]; then
  >&2 echo "################################################################################"
  >&2 echo "################################################################################"
  >&2 echo "## ERROR: specified overrides file does not exist:"
  >&2 echo "##"
  >&2 echo "##        '${overrides_env_file}'"
  >&2 echo "##"
  >&2 echo "################################################################################"
  >&2 echo "################################################################################"
  exit 1
fi

. "${overrides_env_file}"

# Note: we need to support both methods, see the notes at the top of this
#       installer for the specific use case this covers
if [ -z "${RUN_INIT:-}" ] && [ -f "${defaults_env_file}" ]; then
  cat "${defaults_env_file}"
  . "${defaults_env_file}"
fi

if [ -z "${RUN_INIT:-}" ]; then
  >&2 echo "################################################################################"
  >&2 echo "################################################################################"
  >&2 echo "## ERROR: RUN_INIT must be defined in either ${defaults_env_file} or exported"
  >&2 echo "################################################################################"
  >&2 echo "################################################################################"
  exit 1
fi

version_str=$(grep -R "^STACK_VERSION=" "${base_dir}/stack/base.env")
STACK_VERSION=${version_str#*=}

###############################################################################
# Setup
###############################################################################
tp3_docker_home="/apps/timeplay/tp3-docker-stack"
tp3_docker_current="${tp3_docker_home}/current"
tp3_docker_version="${tp3_docker_home}/${STACK_VERSION}"

tp3_certs_dir="${tp3_docker_home}/certs"

tp3_overrides_file="${tp3_docker_version}/overrides.env"
tp3_effective_env_file="${tp3_docker_version}/effective.env"
tp3_run_script="${tp3_docker_version}/run.sh"
tp3_generate_configs_script="${tp3_docker_version}/generate-configs.sh"


# Setup a traps to get more info on errors
function finish_with_error {
  local exit_code=$1
  local line=$2

  >&2 echo "====> failed installation:"
  >&2 echo "====>     line_number: ${line}"
  >&2 echo "====>     exit_code: ${exit_code}"
  >&2 echo "====>     last_command: ${BASH_COMMAND}"

  exit $exit_code
}

function finish {
  local exit_code=$1
  if [ "${exit_code}" != 0 ]; then
    exit $exit_code
  fi

  echo "====> installation completed without errors"
  exit $exit_code
}

# Note: we need a separate ERR trap, otherwise the $LINENO will always be
# incorrect, see: https://unix.stackexchange.com/a/270623
trap 'finish_with_error $? $LINENO' ERR
trap 'finish $?' EXIT

###############################################################################
# Installation Start
###############################################################################
mkdir -p "${tp3_docker_home}/container-data" "${tp3_certs_dir}"

# Setup the tp3-docker-stack files
###############################################################################
# Always clear the target version directory to make sure this is fresh
rm -rf "${tp3_docker_version}"

echo "====> installing targeted stack version packaged with installer"
cp -vrf "${stack_dir}" "${tp3_docker_version}"
cp -vf "${overrides_env_file}" "${tp3_overrides_file}"

if [ -d "${gs_package_dir}" ]; then
  echo "====> copying over local gs-packages"
  cp -vrf "${gs_package_dir}" "${tp3_docker_version}/"
fi

echo "====> updating base STACK_VERSION"
sed -i.bak "s/^STACK_VERSION=.*$/STACK_VERSION=${STACK_VERSION}/" "${tp3_docker_version}/base.env" && rm -f "${tp3_docker_version}/base.env.bak"

# Load all .env files
###############################################################################
echo "====> generating/loading .env"
bash "${tp3_generate_configs_script}"
. "${tp3_effective_env_file}"

# Setup docker
###############################################################################
# NOTE: do NOT run a restart or stop.  This script is also used in the update
#       process, which runs in a container, so running a restart or stop will
#       prematurely kill the update
echo "====> configuring docker..."
mkdir -p /etc/docker /apps/docker
cp -vf "${configs_dir}/docker-daemon.json" "/etc/docker/daemon.json"
systemctl enable docker
systemctl start docker

# Setup logging pipeline (filebeat + haproxy)
###############################################################################
# Setup logging pipeline via haproxy
echo "====> configuring filebeat..."
cp -vf "${configs_dir}/filebeat.yml" "/etc/filebeat/filebeat.yml"
cp -vf "${configs_dir}/haproxy.cfg" "/etc/haproxy/haproxy.cfg"
openssl dhparam -out /etc/haproxy/dhparams.pem 2048

echo "====> setup all certs"
bash "${tp3_run_script}" fetch-certs

# setup filebeat/haproxy environment variables
if command -v systemctl &> /dev/null; then
    echo "====> systemctl found, installing additional components"

    echo "====> Setting up filebeat overrides"
    mkdir -p "/etc/systemd/system/filebeat.service.d"
    cat << EOF > "/etc/systemd/system/filebeat.service.d/env.conf"
[Service]
Environment="STACK_VERSION=${STACK_VERSION}"
Environment="STACK_PARTNER=${STACK_PARTNER}"
Environment="STACK_NAME=${STACK_NAME}"
Environment="GAMESERVER_LICENSE=${STACK_LICENSE}"
EOF

    echo "====> Setting up haproxy overrides"
    mkdir -p "/etc/systemd/system/haproxy.service.d"
    cat << EOF > "/etc/systemd/system/haproxy.service.d/env.conf"
[Service]
Environment="LOG_AGENT_HOST=${LOG_AGENT_HOST}"
Environment="LOG_AGENT_PORT=${LOG_AGENT_PORT}"
EOF

    systemctl daemon-reload
fi

# setup crontab to start pushing logs at 2am, note that there is a 5 minute
# difference of startup/shutdown time as filebeat is reliant on haproxy
cat << EOF | crontab -u root -
00 2 * * * systemctl start haproxy
05 5 * * * systemctl stop haproxy

05 2 * * * systemctl start filebeat
00 5 * * * systemctl stop filebeat
EOF

# setup /etc/hosts file as most ships environments won't give us an internal dns
if [ -e "/etc/hosts" ]; then
    echo "====> /etc/hosts file detected, updating hosts file"
    cat << EOF > "/etc/hosts"
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
${HOST_IP} ${HOST_NAME}
EOF
fi

# create the tp3-docker-compose service
cp -vf "${configs_dir}/tp3-docker-compose.service" "/etc/systemd/system/tp3-docker-compose.service"

echo "====> linking new tp3 'current' directory..."
ln -sfn "${tp3_docker_version}" "${tp3_docker_current}"

# update all folder permissions so in locked down environments, we have access to things
chown timeplay:docker "${tp3_docker_current}"
chown -R timeplay:docker "${tp3_docker_version}"

###############################################################################
# pre-configure/pull all images
###############################################################################
echo "====> configuring docker with remote registry credentials..."
# hack to get around /tmp directory access for docker-compose
mkdir -p "/apps/docker/compose-tmp"
export TMPDIR="/apps/docker/compose-tmp"

echo "Logging into registry: ${REPO_IMAGE_BASE}"
docker login --username "${REPO_USERNAME}" --password "${REPO_PASSWORD}" "${REPO_IMAGE_BASE}"

if [ -d "${images_dir}" ]; then
  echo "====> loading packaged images from images directory"
  pushd "${images_dir}"
  for img in *.img; do
    [ -f "${img}" ] || continue
    echo "====> loading image: ${img}..."
    docker load -i "${img}"
  done
  popd
fi

# Note: we always run this in case the packaged images are missing things
echo "====> pulling stack images..."
bash "${tp3_run_script}" pull

###############################################################################
# start everything up
###############################################################################

# enable and start the processes
echo "====> starting stack version: ${STACK_VERSION}..."
systemctl enable tp3-docker-compose
systemctl restart tp3-docker-compose

## only run init scripts if "RUN_INIT" is "true"
if [ "${RUN_INIT}" = "true" ]; then
    echo "====> Starting init scripts..."
    bash "${tp3_run_script}" init
fi

if [[ "${STACK_COMPONENTS}" =~ .*"gs-package-service".* ]]; then
  while :
  do
      http_status_code=$(curl -IL "${EXTERNAL_URL_GS_PACKAGE_SERVICE}/hello" 2>&1 | awk '/^HTTP/{print $2}' | tail -n 1)
      if [ "${http_status_code}" == "200" ]; then
          echo "====> GPS ready!"
          break
      fi

      echo "====> Waiting for GPS..."
      sleep 5
  done

  bash "${tp3_docker_current}/components/gs-package-service/scripts/load-packages.sh" || true
fi

if [[ "${STACK_COMPONENTS}" =~ .*"asset-manager".* ]] && [[ "${STACK_COMPONENTS}" =~ .*"playlist-manager".* ]]; then
  while :
  do
      http_status_code=$(curl -IL "${EXTERNAL_URL_ASSET_MANAGER}/hello" 2>&1 | awk '/^HTTP/{print $2}' | tail -n 1)
      if [ "${http_status_code}" == "200" ]; then
          echo "====> asset manager ready!"
          break
      fi

      echo "====> Waiting for playlist manager..."
      sleep 5
  done

  while :
  do
      http_status_code=$(curl -IL "${EXTERNAL_URL_PLAYLIST_MANAGER}/hello" 2>&1 | awk '/^HTTP/{print $2}' | tail -n 1)
      if [ "${http_status_code}" == "200" ]; then
          echo "====> playlist manager ready!"
          break
      fi

      echo "====> Waiting for playlist manager..."
      sleep 5
  done

  bash "${tp3_docker_current}/components/playlist-manager/scripts/load-playlists.sh" || true
fi
