#!/bin/bash
# This script centralizes the .env and docker-compose generation.  Running this
# script will create an effective .env and docker-compose to run the stack
#
# Usage:
#    sh generate-config.sh
#
###############################################################################

set -o nounset
set -o errexit
set -o pipefail

###############################################################################
## Constants
###############################################################################

base_dir=$(readlink -f "$(dirname "${0}")")
overrides_env_file="${base_dir}/overrides.env"

target_env_file="${base_dir}/effective.env"
target_init_file="${base_dir}/effective.init.sh"
target_compose_file="${base_dir}/effective.docker-compose.yml"

###############################################################################
## Functions
###############################################################################
# Function to recursively interpolate variables
interpolate_vars() {
  local line="$1"
  local interpolated_line="$line"
  local var_regex='\$\{([^\}]+)\}'

  # Iterate until no more variable references are found
  while [[ $interpolated_line =~ $var_regex ]]; do
    local raw_match="${BASH_REMATCH[0]}"
    local var_name="${BASH_REMATCH[1]}"

    # Get the value of the variable
    local var_value="${properties["$var_name"]}"

    # if the variable beting substituted in is quoted, then remove the quotes
    if [[ $var_value =~ ^\"(.*)\"$ ]]; then
      var_value="${BASH_REMATCH[1]}"
    elif [[ $var_value =~ ^\'(.*)\'$ ]]; then
      var_value="${BASH_REMATCH[1]}"
    fi

    if [[ -n "$var_value" ]]; then
      # Replace the variable reference with its value
      interpolated_line="${interpolated_line//${raw_match}/$var_value}"
    else
      break
    fi
  done

  echo "$interpolated_line"
}

# Function to load properties from a file
declare -A properties
load_properties_file() {
  local file="$1"
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    if [[ -z "$key" || "$key" == "#"* ]]; then
        continue
    fi

    # Trim leading/trailing whitespaces from key and value
    key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    properties["$key"]=$value
  done < "$file"
}

###############################################################################
## Checks
###############################################################################
if [ ! -f "${overrides_env_file}" ]; then
  >&2 echo "################################################################################"
  >&2 echo "################################################################################"
  >&2 echo "## ERROR: overrides env file does not exist:"
  >&2 echo "##"
  >&2 echo "##        '${overrides_env_file}'"
  >&2 echo "##"
  >&2 echo "################################################################################"
  >&2 echo "################################################################################"
  exit 1
fi
. "${overrides_env_file}"

# Set STACK_COMPONENTS to empty if it doesn't exist so when we use it later on, we won't
# get an unbound variable due to `set -o nounset`
STACK_COMPONENTS="${STACK_COMPONENTS:-}"
if [ -z "${STACK_SCHEME:-}" ] || [ -z "${STACK_PARTNER:-}" ]; then
  >&2 echo "################################################################################"
  >&2 echo "################################################################################"
  >&2 echo "## ERROR: overrides file missing definition for STACK_SCHEME, and/or"
  >&2 echo "##        STACK_PARTNER:"
  >&2 echo "##"
  >&2 echo "## STACK_COMPONENTS: ${STACK_COMPONENTS}"
  >&2 echo "## STACK_SCHEME: ${STACK_SCHEME}"
  >&2 echo "## STACK_PARTNER: ${STACK_PARTNER}"
  >&2 echo "##"
  >&2 echo "################################################################################"
  >&2 echo "################################################################################"
  exit 1
fi

###############################################################################
## Script start
###############################################################################


## Configuration load order
###############################################################################

# Load base configs
load_properties_file "${base_dir}/base.env"
load_properties_file "${base_dir}/base-versions.env"
docker_compose_files=("-f" "${base_dir}/docker-compose.yml")
init_files=()

# Load components only if components are specified
if [ -n "${STACK_COMPONENTS}" ]; then
  IFS=',' read -ra components <<< "${STACK_COMPONENTS}"
  for component in "${components[@]}"; do
    init_files+=("$(readlink -f "${base_dir}/components/${component}/${component}-init.sh")")
    load_properties_file "${base_dir}/components/${component}/${component}.env"
    docker_compose_files+=("-f" "${base_dir}/components/${component}/docker-compose.${component}.yml")
  done
fi

# Load scheme configs
init_files+=("$(readlink -f "${base_dir}/schemes/${STACK_SCHEME}/${STACK_SCHEME}-init.sh")")
load_properties_file "${base_dir}/schemes/${STACK_SCHEME}/${STACK_SCHEME}.env"
docker_compose_files+=("-f" "${base_dir}/schemes/${STACK_SCHEME}/docker-compose.${STACK_SCHEME}.yml")

# Load partner configs
init_files+=("$(readlink -f "${base_dir}/partner/${STACK_PARTNER}/${STACK_PARTNER}-init.sh")")
load_properties_file "${base_dir}/partner/${STACK_PARTNER}/${STACK_PARTNER}.env"
docker_compose_files+=("-f" "${base_dir}/partner/${STACK_PARTNER}/docker-compose.${STACK_PARTNER}.yml")

# load override configs
load_properties_file "${base_dir}/overrides.env"
if [ -f "${base_dir}/docker-compose.overrides.yml" ]; then
  docker_compose_files+=("-f" "${base_dir}/docker-compose.overrides.yml")
fi
init_files+=("$(readlink -f "${base_dir}/init.sh")")

# Interpolate variables recursively
for key in "${!properties[@]}"; do
  properties["$key"]=$(interpolate_vars "${properties[$key]}")
done
unquote_session_def="${properties["SESSION_DEFINITIONS"]}"
if [[ $unquote_session_def =~ ^\"(.*)\"$ ]]; then
  unquote_session_def="${BASH_REMATCH[1]}"
elif [[ $unquote_session_def =~ ^\'(.*)\'$ ]]; then
  unquote_session_def="${BASH_REMATCH[1]}"
fi
properties["SCREEN_IDS"]=$(echo "${unquote_session_def}" | jq -c '[.[].screenId | tonumber]')

## Generate effective configs
###############################################################################
# create the effective init.sh script to use later
cat << EOF > "${target_init_file}"
# This file is automatically generated by generate-config.sh, do not modify

set -o nounset
set -o errexit
set -o pipefail
set -x

EOF
for init_script in "${init_files[@]}"; do
  echo "sh ${init_script}" >> "${target_init_file}"
done
echo "" >> "${target_init_file}"

# generate effective .env file to use later
: > "${target_env_file}"
for key in "${!properties[@]}"; do
  echo "${key}=${properties[$key]}" >> "${target_env_file}"
done
sort -o "${target_env_file}" "${target_env_file}"
sed -i.bak '1s/^/# This file is automatically generated by generate-config.sh, do not modify\n/' "${target_env_file}" && rm "${target_env_file}.bak"
echo "" >> "${target_env_file}"

# generate effective docker-compose file to use later
docker compose --env-file "${target_env_file}" "${docker_compose_files[@]}" config > "${target_compose_file}"
sed -i.bak '1s/^/# This file is automatically generated by generate-config.sh, do not modify\n/' "${target_compose_file}" && rm "${target_compose_file}.bak"
