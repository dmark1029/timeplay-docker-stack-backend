#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

###############################################################################
# Setup
###############################################################################

# run with FORCE=true to force cert updates
force=${FORCE:-false}

base_dir=$(readlink -f $(dirname "${0}"))
response_header_dump="${base_dir}/response-headers.log"

effective_env_file="${base_dir}/effective.env"
if [ -f "${effective_env_file}" ]; then
  . "${effective_env_file}"
else
  >&2 echo "failed to find the effective_env_file: ${effective_env_file}, exiting with error"
  exit 1
fi

common_certs_repo_path="ships-universal/certs"
logging_certs_repo_path="ships-${STACK_PARTNER}/certs/log-agent.timeplay.me"

cert_agent_config="${CERT_CONFIG}/log-agent.timeplay.me"
auth_token="$(echo -ne "${PUBLIC_REPO_USERNAME}:${PUBLIC_REPO_PASSWORD}" | base64 --wrap 0)"

# Determines, if the certs expires in "cert_check_end" seconds, this is used to
# specify how early we should be updating certificates.  The default is
# 1209600 (14 days in seconds), so certs will only be updated if they are going
# to expire within 24h of this scripts run
cert_check_end="${1:-1209600}"

mkdir -p "${cert_agent_config}"

###############################################################################
# Function(s)
###############################################################################

function log_cert_info {
  cert_type=$1
  cert_file=$2

  if [ -f "${cert_file}" ] && openssl x509 -enddate -noout -in "${cert_file}" &> /dev/null; then
    certEnd=$(openssl x509 -enddate -noout -in "${cert_file}")
    certEnd=${certEnd#*=}

    echo "current ${cert_type} certs expires at: ${certEnd}"
  else
    echo "no ${cert_type} certs currently exists"
  fi

}

function download_certs {
  path=$1
  cert=$2
  target=$3

  url="${PUBLIC_REPO_BASE_URL}/${path}/${cert}"
  echo "downloading: ${url} -> ${target}"
  curl --silent "${url}" \
    --header "Authorization: Basic ${auth_token}" \
    --dump-header "${response_header_dump}" \
    --output "${target}"

  resp_code=$(cat "${response_header_dump}" | head -n 1 | awk '/^HTTP/{print $2}')
  if [ "${resp_code}" != "200" ]; then
    >&2 echo "download failed:"
    >&2 cat "${response_header_dump}"

    rm -f "${response_header_dump}"
    exit 1
  fi

  rm -f "${response_header_dump}"
}

function validate_certs {
  crt="${1}"
  key="${2}"
  ca="${3:-}"

  echo "validating key/cert pair..."
  crthash="$(openssl x509 -noout -modulus -in "$crt" | openssl md5)"
  keyhash="$(openssl rsa -noout -modulus -in "$key" | openssl md5)"
  if [ "$keyhash" != "$crthash" ]; then
    >&2 echo "failed to validate cert+key ${crt} and ${key}"
    exit 1
  fi

  if [ -n "${ca}" ]; then
    echo "validating ca certificate for your cert..."
    if ! openssl verify -verbose -CAfile "${ca}" "${crt}"; then
      >&2 echo "failed to validate certificate authority+cert for file ${ca} and ${crt}"
      exit 1
    fi
  fi

  echo "certificates validated"
}

###############################################################################
# Script start
###############################################################################

# Download and stage common certs
timeplay_pem="timeplay.pem"
timeplay_crt="timeplay.crt"
timeplay_key="timeplay.key"

timeplay_file_pem="${CERT_CONFIG}/${timeplay_pem}"
timeplay_file_crt="${CERT_CONFIG}/${timeplay_crt}"
timeplay_file_key="${CERT_CONFIG}/${timeplay_key}"

log_cert_info "proxy" "${timeplay_file_crt}"

# TODO: Verify certificate is for the correct domain in the HOST_NAME environment var
# Only update certs if they either don't exist, or are going to expire within the day
if [ "${force}" == "true" ] || ! openssl x509 -checkend "${cert_check_end}" -noout -in "${timeplay_file_crt}" &> /dev/null; then
  tmp_timeplay_crt="${timeplay_file_crt}.tmp"
  tmp_timeplay_key="${timeplay_file_key}.tmp"

  echo "retriving domain certs..."
  download_certs "${common_certs_repo_path}" "${timeplay_crt}" "${tmp_timeplay_crt}"
  download_certs "${common_certs_repo_path}" "${timeplay_key}" "${tmp_timeplay_key}"

  validate_certs "${tmp_timeplay_crt}" "${tmp_timeplay_key}"

  mv -f "${tmp_timeplay_crt}" "${timeplay_file_crt}"
  mv -f "${tmp_timeplay_key}" "${timeplay_file_key}"
  cat "${timeplay_file_crt}" "${timeplay_file_key}" > "${timeplay_file_pem}"

  # Note: proxy server/postgres may not be active here if this is running from "run.sh"
  echo "restarting proxy-server..."
  docker restart proxy-server || true
  echo "proxy-server restarted"

  echo "restarting postgres..."
  docker restart postgres || true
  echo "postgres restarted"

  echo "restarting mongodb..."
  docker restart mongodb || true
  echo "mongodb restarted"
else
  echo "current proxy certs at ${timeplay_file_crt} is not expiring within ${cert_check_end}s, skipping..."
fi

crt="agent.crt"
key="agent.key"
ca="root_ca.crt"

file_crt="${cert_agent_config}/${crt}"
file_key="${cert_agent_config}/${key}"
file_ca="${cert_agent_config}/${ca}"


# Download and stage logging certs if haproxy exists
if command -v haproxy &> /dev/null; then
  echo "haproxy detected..."
  log_cert_info "logging" "${file_crt}"

  if [ "${force}" == "true" ] || ! openssl x509 -checkend "${cert_check_end}" -noout -in "${file_crt}" &> /dev/null; then
    tmp_crt="${file_crt}.tmp"
    tmp_key="${file_key}.tmp"
    tmp_ca="${file_ca}.tmp"

    echo "retriving logging certs..."
    download_certs "${logging_certs_repo_path}" "${crt}" "${tmp_crt}"
    download_certs "${logging_certs_repo_path}" "${key}" "${tmp_key}"
    download_certs "${logging_certs_repo_path}" "${ca}" "${tmp_ca}"
    echo "logging certs downloaded successfully"

    validate_certs "${tmp_crt}" "${tmp_key}" "${tmp_ca}"

    mv -f "${tmp_crt}" "${file_crt}"
    mv -f "${tmp_key}" "${file_key}"
    mv -f "${tmp_ca}" "${file_ca}"

    echo "setting up haproxy certs..."
    cat "${timeplay_file_crt}" "${timeplay_file_key}" > "/etc/haproxy/domain.pem"
    cat "${file_crt}" "${file_key}" > "/etc/haproxy/logger-timeplay.pem"
    cp -f "${file_ca}" "/etc/haproxy/logger-timeplay-root-ca.crt"

    chown root:root "/etc/haproxy/domain.pem" "/etc/haproxy/logger-timeplay.pem" "/etc/haproxy/logger-timeplay-root-ca.crt"
    echo "haproxy certs ready"
  else
    echo "current logging cert at ${file_crt} is not expiring within ${cert_check_end}s, skipping..."
  fi
fi
