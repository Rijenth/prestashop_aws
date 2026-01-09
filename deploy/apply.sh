#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${DEPLOY_ENV:-dev}"
if [ "${1:-}" != "" ] && [[ "$1" != -* ]]; then
  ENV_NAME="$1"
  shift
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/env/.env.${ENV_NAME}"

if [ ! -f "${ENV_FILE}" ]; then
  echo "Missing env file: ${ENV_FILE}" >&2
  echo "Create it from env/.env.${ENV_NAME}.example and try again." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "${ENV_FILE}"
set +a

cd "${ROOT_DIR}/deploy"
terraform init
terraform apply "$@"
