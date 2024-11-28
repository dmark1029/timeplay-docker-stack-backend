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

# Find all variables that start with "PACKAGES_", and process each as a comma
# separated list, accumulating all of the entries into the 'packages' var
packages=()
while read -r line ; do
  package_list="${line#*=}"
  # if the variable being substituted is quoted, then remove the quotes
  if [[ $package_list =~ ^\"(.*)\"$ ]]; then
    package_list="${BASH_REMATCH[1]}"
  elif [[ $package_list =~ ^\'(.*)\'$ ]]; then
    package_list="${BASH_REMATCH[1]}"
  fi

  IFS=',' read -r -a package_array <<< "${package_list}"
  packages+=("${package_array[@]}")
done <<<"$(grep '^PACKAGES_' "${effective_env_file}")"

bash "${base_dir}/scripts/load-packages.sh" "${packages[@]}"
