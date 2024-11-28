#!/bin/bash
#
# Downloads/Saves all images listed the ../stack/base-versions.env, note that
# this can be overwritten by running with the environment variable
# BASE_VERSIONS_FILE like so:
#
# BASE_VERSIONS_FILE=../../base-versions.env ./save.sh
#
###############################################################################

set -o nounset
set -o errexit
set -o pipefail

nexus="registry.timeplay.com/docker-virtual"
artifactory="registry.timeplay.com/docker-virtual"

base_dir=$(readlink -f $(dirname "${0}"))
base_versions_file="${BASE_VERSIONS_FILE:-"${base_dir}/../stack/base-versions.env"}"

while read -r line ; do
  image="${line#*=}"
  if [[ "${image}" =~ ^\"(.*)\"$ ]]; then
    image="${BASH_REMATCH[1]}"
  elif [[ "${image}" =~ ^\'(.*)\'$ ]]; then
    image="${BASH_REMATCH[1]}"
  fi
  image="${image##\$\{REPO_IMAGE_BASE\}/}"

  image_name=$(echo "${image}" | cut -d: -f1)
  image_tag=$(echo "${image}" | cut -d: -f2-)

  nexusTag="${nexus}/${image}"
  artTag="${artifactory}/${image}"

  filename="$(echo "${image##*/}" | tr "/" "-" | tr ":" "-").img"
  echo "Saving ${filename}..."
  docker pull "${nexusTag}"
  docker pull "${artTag}"
  docker save --output="${filename}" "${nexusTag}" "${artTag}"
done < <(grep "^IMAGE_" "${base_versions_file}")
