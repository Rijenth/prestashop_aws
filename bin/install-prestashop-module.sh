#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bin/install-prestashop-module.sh <github_repo_or_url> [service]

Examples:
  bin/install-prestashop-module.sh DaveZ07/NGS-Redis-Cache-Prestashop
  bin/install-prestashop-module.sh https://github.com/DaveZ07/NGS-Redis-Cache-Prestashop prestashop

Environment:
  PRESTASHOP_MODULES_DIR  Modules path inside the container (default: /var/www/html/modules)
EOF
}

repo="${1:-}"
service="${2:-prestashop}"
modules_dir="${PRESTASHOP_MODULES_DIR:-/var/www/html/modules}"

if [[ -z "$repo" ]]; then
  usage
  exit 1
fi

if [[ "$repo" == *"github.com"* ]]; then
  repo="$(printf '%s' "$repo" | sed -E 's#https?://github.com/##; s#\\.git$##')"
fi

repo="$(printf '%s' "$repo" | awk -F/ '{print $1"/"$2}')"
if [[ "$repo" != */* ]]; then
  echo "Invalid repo. Use owner/repo or a GitHub URL." >&2
  exit 1
fi

compose_cmd=(docker-compose)
if command -v docker-compose >/dev/null 2>&1; then
  compose_cmd=(docker-compose)
elif command -v docker >/dev/null 2>&1; then
  compose_cmd=(docker compose)
else
  echo "docker-compose or docker not found." >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

api_url="https://api.github.com/repos/${repo}/releases/latest"
api_headers=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  api_headers=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

api_json="${tmp_dir}/release.json"
zip_url=""
if curl -fsSL "${api_headers[@]}" "$api_url" -o "$api_json"; then
  if [[ -s "$api_json" ]]; then
    if ! zip_url="$(
      python3 - "$api_json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)

assets = data.get("assets") or []
zip_url = ""
for asset in assets:
    name = (asset.get("name") or "").lower()
    url = asset.get("browser_download_url") or ""
    if name.endswith(".zip") and url:
        zip_url = url
        break
if not zip_url:
    zip_url = data.get("zipball_url") or ""
if not zip_url:
    raise SystemExit("No zip URL found in release")
print(zip_url)
PY
    )"; then
      zip_url=""
    fi
  fi
fi

if [[ -z "$zip_url" ]]; then
  for branch in main master; do
    candidate="https://github.com/${repo}/archive/refs/heads/${branch}.zip"
    if curl -fsI "$candidate" >/dev/null 2>&1; then
      zip_url="$candidate"
      break
    fi
  done
fi

if [[ -z "$zip_url" ]]; then
  echo "Failed to resolve module zip for ${repo}." >&2
  echo "Tip: set GITHUB_TOKEN to avoid GitHub API rate limits." >&2
  exit 1
fi

archive="${tmp_dir}/module.zip"
curl -fsSL "$zip_url" -o "$archive"

python3 - <<'PY' "$archive" "$tmp_dir"
import sys
import zipfile

archive = sys.argv[1]
dest = sys.argv[2]
with zipfile.ZipFile(archive, "r") as zf:
    zf.extractall(dest)
PY

module_dir="$(
  python3 - <<'PY' "$tmp_dir"
import os
import sys

root = sys.argv[1]
target = None
for base, _, files in os.walk(root):
    if "config.xml" in files:
        target = base
        break
if not target:
    for name in os.listdir(root):
        path = os.path.join(root, name)
        if os.path.isdir(path):
            target = path
            break
if not target:
    raise SystemExit("Module directory not found")
print(target)
PY
)"

module_name="$(basename "$module_dir")"

"${compose_cmd[@]}" cp "$module_dir" "${service}:${modules_dir}/${module_name}"
"${compose_cmd[@]}" exec -T "$service" chown -R www-data:www-data "${modules_dir}/${module_name}"

echo "Module copied to ${modules_dir}/${module_name}."
echo "Activate it in the PrestaShop back-office."
