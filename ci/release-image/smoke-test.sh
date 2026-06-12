#!/usr/bin/env bash
set -euo pipefail

image=${1:?usage: smoke-test.sh IMAGE}
container="rune-image-smoke-${RANDOM}"
port=${RUNE_SMOKE_PORT:-18080}
password=${RUNE_SMOKE_PASSWORD:-rune-smoke-password}

cleanup() {
  docker rm -f "$container" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run --detach \
  --name "$container" \
  --publish "127.0.0.1:${port}:8080" \
  --env "PASSWORD=${password}" \
  "$image" >/dev/null

for _ in $(seq 1 60); do
  if health=$(curl --fail --silent "http://127.0.0.1:${port}/healthz" 2>/dev/null) \
    && jq -e '.status == "alive"' <<<"$health" >/dev/null; then
    break
  fi
  sleep 2
done

health=$(curl --fail --silent "http://127.0.0.1:${port}/healthz")
jq -e '.status == "alive"' <<<"$health" >/dev/null

login=$(curl --fail --silent "http://127.0.0.1:${port}/login")
grep -Fq '<title>Sign in - Rune IDE</title>' <<<"$login"
grep -Fq 'Welcome to Rune IDE' <<<"$login"
grep -Fq 'Workspace password' <<<"$login"

test "$(docker inspect --format '{{.Config.User}}' "$container")" = coder
docker exec "$container" test -f /usr/lib/rune/customization/i18n/en.json
docker exec "$container" test -d /usr/lib/rune/customization/extensions
