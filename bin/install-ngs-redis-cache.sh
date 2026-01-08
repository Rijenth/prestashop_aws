#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${script_dir}/install-prestashop-module.sh" "DaveZ07/NGS-Redis-Cache-Prestashop" "$@"
