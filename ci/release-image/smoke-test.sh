#!/usr/bin/env bash
set -euo pipefail

image=${1:?usage: smoke-test.sh IMAGE}
container="rune-image-smoke-${RANDOM}"
password=${RUNE_SMOKE_PASSWORD:-rune-smoke-password}

cleanup() {
  docker rm -f "$container" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run --detach \
  --name "$container" \
  --publish 127.0.0.1::8080 \
  --env "PASSWORD=${password}" \
  "$image" >/dev/null

port=$(docker port "$container" 8080/tcp | sed -n 's/.*://p')
test -n "$port"
base_url="http://127.0.0.1:${port}"
ready=false

for _ in $(seq 1 60); do
  if health=$(curl --fail --silent --connect-timeout 5 --max-time 10 "${base_url}/healthz" 2>/dev/null) \
    && jq -e '.status == "alive"' <<<"$health" >/dev/null; then
    ready=true
    break
  fi
  sleep 2
done

if [[ $ready != true ]]; then
  docker logs "$container" >&2
  exit 1
fi

health=$(curl --fail --silent --connect-timeout 5 --max-time 10 "${base_url}/healthz")
jq -e '.status == "alive"' <<<"$health" >/dev/null

login=$(curl --fail --silent --connect-timeout 5 --max-time 10 "${base_url}/login")
grep -Fq '<title>Sign in - Rune IDE</title>' <<<"$login"
grep -Fq 'Welcome to Rune IDE' <<<"$login"
grep -Fq 'Workspace password' <<<"$login"

test "$(docker inspect --format '{{.Config.User}}' "$container")" = coder
docker exec "$container" test -f /usr/lib/rune/customization/i18n/en.json
docker exec "$container" test -d /usr/lib/rune/customization/extensions
