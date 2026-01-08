#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bin/install-ngs-redis-cache.sh [prestashop_service]

Environment overrides:
  DB_NAME                   (default: prestashop)
  DB_USER                   (default: prestashop)
  DB_PASS                   (default: prestashop)
  DB_PREFIX                 (default: ps_)
  NGS_REDIS_AUTH or REDIS_PASSWORD (required)
  NGS_REDIS_HOST            (default: redis)
  NGS_REDIS_PORT            (default: 6379)
  NGS_REDIS_DB              (default: 0)
  NGS_REDIS_PREFIX          (default: ngs_)
  NGS_REDIS_CONNECTION_TYPE (default: single)
  NGS_REDIS_CRON_TOKEN      (default: random)
EOF
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
service="${1:-prestashop}"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
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

"${script_dir}/install-prestashop-module.sh" "DaveZ07/NGS-Redis-Cache-Prestashop" "$service"

db_name="${DB_NAME:-prestashop}"
db_user="${DB_USER:-prestashop}"
db_pass="${DB_PASS:-prestashop}"
db_prefix="${DB_PREFIX:-ps_}"

redis_auth="${NGS_REDIS_AUTH:-${REDIS_PASSWORD:-}}"
if [[ -z "$redis_auth" ]]; then
  echo "Missing Redis password. Set NGS_REDIS_AUTH or REDIS_PASSWORD." >&2
  exit 1
fi

ngs_host="${NGS_REDIS_HOST:-redis}"
ngs_port="${NGS_REDIS_PORT:-6379}"
ngs_db="${NGS_REDIS_DB:-0}"
ngs_prefix="${NGS_REDIS_PREFIX:-ngs_}"
ngs_connection_type="${NGS_REDIS_CONNECTION_TYPE:-single}"
ngs_cron_token="${NGS_REDIS_CRON_TOKEN:-}"
if [[ -z "$ngs_cron_token" ]]; then
  ngs_cron_token="$(python3 - <<'PY'
import secrets
print(secrets.token_hex(16))
PY
  )"
fi

sql_quote() {
  local value="${1//\'/\'\'}"
  printf "'%s'" "$value"
}

php_escape() {
  local value="${1//\\/\\\\}"
  value="${value//\'/\\\'}"
  printf "%s" "$value"
}

redis_unix_socket="${NGS_REDIS_UNIX_SOCKET:-}"
redis_sentinel_hosts="${NGS_REDIS_SENTINEL_HOSTS:-[]}"
redis_sentinel_service="${NGS_REDIS_SENTINEL_SERVICE:-mymaster}"
redis_cluster_nodes="${NGS_REDIS_CLUSTER_NODES:-[]}"
redis_blacklist="${NGS_REDIS_BLACKLIST:-[]}"
redis_blacklist_controllers="${NGS_REDIS_BLACKLIST_CONTROLLERS:-[]}"
redis_disable_order_page="${NGS_REDIS_DISABLE_ORDER_PAGE:-0}"
redis_disable_checkout="${NGS_REDIS_DISABLE_CHECKOUT:-0}"
redis_disable_webservice="${NGS_REDIS_DISABLE_WEBSERVICE:-0}"
redis_disable_product_listing="${NGS_REDIS_DISABLE_PRODUCT_LISTING:-0}"

conflicts="$("${compose_cmd[@]}" exec -T "$service" sh -lc '
  if [ -d modules/ngs_redis/override ]; then
    find modules/ngs_redis/override -type f | while IFS= read -r file; do
      rel=${file#modules/ngs_redis/override/}
      if [ -f "override/$rel" ]; then
        printf "%s\n" "$rel"
      fi
    done
  fi
')"

if [[ -n "$conflicts" ]]; then
  echo "Override conflict detected. Resolve these before enabling the module:" >&2
  echo "$conflicts" >&2
  echo "Tip: compare modules/ngs_redis/override/<file> with override/<file> and merge if needed." >&2
  exit 1
fi

module_enabled=0
if "${compose_cmd[@]}" exec -T "$service" sh -lc '
  if [ -f bin/console ]; then
    php bin/console prestashop:module install ngs_redis || true
    php bin/console prestashop:module enable ngs_redis
  else
    echo "bin/console not found in container." >&2
    exit 1
  fi
'; then
  module_enabled=1
else
  echo "Failed to enable ngs_redis; skipping cache activation." >&2
fi

php_host="$(php_escape "$ngs_host")"
php_unix_socket="$(php_escape "$redis_unix_socket")"
php_auth="$(php_escape "$redis_auth")"
php_prefix="$(php_escape "$ngs_prefix")"
php_connection_type="$(php_escape "$ngs_connection_type")"
php_sentinel_service="$(php_escape "$redis_sentinel_service")"

config_php=$(cat <<PHP
<?php
return [
    'host' => '${php_host}',
    'port' => ${ngs_port},
    'unix_socket' => '${php_unix_socket}',
    'auth' => '${php_auth}',
    'db' => ${ngs_db},
    'prefix' => '${php_prefix}',
    'connection_type' => '${php_connection_type}',
    'sentinel_hosts' => ${redis_sentinel_hosts},
    'sentinel_service' => '${php_sentinel_service}',
    'cluster_nodes' => ${redis_cluster_nodes},
    'blacklist' => ${redis_blacklist},
    'blacklist_controllers' => ${redis_blacklist_controllers},
    'disable_order_page' => $( [[ "$redis_disable_order_page" =~ ^(1|true|yes)$ ]] && echo "true" || echo "false" ),
    'disable_checkout' => $( [[ "$redis_disable_checkout" =~ ^(1|true|yes)$ ]] && echo "true" || echo "false" ),
    'disable_webservice' => $( [[ "$redis_disable_webservice" =~ ^(1|true|yes)$ ]] && echo "true" || echo "false" ),
    'disable_product_listing' => $( [[ "$redis_disable_product_listing" =~ ^(1|true|yes)$ ]] && echo "true" || echo "false" ),
];
PHP
)

printf '%s\n' "$config_php" | "${compose_cmd[@]}" exec -T "$service" sh -lc \
  'cat > /var/www/html/modules/ngs_redis/config/redis.php'

sql=$(cat <<SQL
INSERT INTO ${db_name}.${db_prefix}configuration
(id_shop_group, id_shop, name, value, date_add, date_upd)
VALUES
  (NULL, NULL, 'NGS_REDIS_CRON_TOKEN', $(sql_quote "$ngs_cron_token"), NOW(), NOW()),
  (NULL, NULL, 'NGS_REDIS_HOST', $(sql_quote "$ngs_host"), NOW(), NOW()),
  (NULL, NULL, 'NGS_REDIS_PORT', $(sql_quote "$ngs_port"), NOW(), NOW()),
  (NULL, NULL, 'NGS_REDIS_UNIX_SOCKET', $(sql_quote "$redis_unix_socket"), NOW(), NOW()),
  (NULL, NULL, 'NGS_REDIS_AUTH', $(sql_quote "$redis_auth"), NOW(), NOW()),
  (NULL, NULL, 'NGS_REDIS_DB', $(sql_quote "$ngs_db"), NOW(), NOW()),
  (NULL, NULL, 'NGS_REDIS_PREFIX', $(sql_quote "$ngs_prefix"), NOW(), NOW()),
  (NULL, NULL, 'NGS_REDIS_CONNECTION_TYPE', $(sql_quote "$ngs_connection_type"), NOW(), NOW()),
  (NULL, NULL, 'NGS_REDIS_SENTINEL_HOSTS', $(sql_quote "$redis_sentinel_hosts"), NOW(), NOW()),
  (NULL, NULL, 'NGS_REDIS_SENTINEL_SERVICE', $(sql_quote "$redis_sentinel_service"), NOW(), NOW()),
  (NULL, NULL, 'NGS_REDIS_CLUSTER_NODES', $(sql_quote "$redis_cluster_nodes"), NOW(), NOW()),
  (NULL, NULL, 'NGS_REDIS_BLACKLIST', $(sql_quote "$redis_blacklist"), NOW(), NOW()),
  (NULL, NULL, 'NGS_REDIS_BLACKLIST_CONTROLLERS', $(sql_quote "$redis_blacklist_controllers"), NOW(), NOW()),
  (NULL, NULL, 'NGS_REDIS_DISABLE_ORDER_PAGE', $(sql_quote "$redis_disable_order_page"), NOW(), NOW()),
  (NULL, NULL, 'NGS_REDIS_DISABLE_CHECKOUT', $(sql_quote "$redis_disable_checkout"), NOW(), NOW()),
  (NULL, NULL, 'NGS_REDIS_DISABLE_WEBSERVICE', $(sql_quote "$redis_disable_webservice"), NOW(), NOW()),
  (NULL, NULL, 'NGS_REDIS_DISABLE_PRODUCT_LISTING', $(sql_quote "$redis_disable_product_listing"), NOW(), NOW())
ON DUPLICATE KEY UPDATE value = VALUES(value), date_upd = VALUES(date_upd);
SQL
)

printf '%s\n' "$sql" | "${compose_cmd[@]}" exec -T mysql sh -lc \
  "mysql -u\"${db_user}\" -p\"${db_pass}\" \"${db_name}\""

if [[ "$module_enabled" -eq 1 ]]; then
  "${compose_cmd[@]}" exec -T "$service" php -r '
$paths = ["app/config/parameters.php", "config/parameters.php"];
$file = null;
foreach ($paths as $path) {
  if (file_exists($path)) {
    $file = $path;
    break;
  }
}
if (!$file) {
  fwrite(STDERR, "parameters.php not found\n");
  exit(1);
}
$config = require $file;
if (!isset($config["parameters"])) {
  $config = ["parameters" => $config];
}
$config["parameters"]["ps_cache_enable"] = true;
$config["parameters"]["ps_caching"] = "Redis";
$export = "<?php\nreturn " . var_export($config, true) . ";\n";
file_put_contents($file, $export);
'
fi

"${compose_cmd[@]}" exec -T "$service" sh -lc \
  'rm -f var/cache/prod/class_index.php var/cache/dev/class_index.php'

if [[ "$module_enabled" -eq 1 ]]; then
  echo "NGS Redis module installed and configured. Clear Symfony cache if needed."
else
  echo "NGS Redis config written but module not enabled due to errors." >&2
fi
