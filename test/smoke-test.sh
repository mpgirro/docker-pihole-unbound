#!/usr/bin/env bash
# Smoke-test a pihole-unbound image: boot it, verify Pi-hole + Unbound
# answer DNS recursively with DNSSEC validation, then tear down.
#
# Usage: ./test/smoke-test.sh <image-ref>
set -euo pipefail
IFS=$'\n\t'

IMAGE="${1:?usage: $0 <image-ref>}"
NAME="pihole-smoke-$$"
DNS_PORT="${SMOKE_DNS_PORT:-15353}"
WEB_PORT="${SMOKE_WEB_PORT:-18080}"
READY_TIMEOUT="${SMOKE_READY_TIMEOUT:-120}"

pass=0
fail=0

log()  { printf '[smoke] %s\n' "$*"; }
ok()   { printf 'OK:   %s\n' "$*"; pass=$((pass + 1)); }
bad()  { printf 'FAIL: %s\n' "$*" >&2; fail=$((fail + 1)); }

cleanup() {
  local rc=$?
  if docker inspect "$NAME" >/dev/null 2>&1; then
    log "container logs (tail 200):"
    docker logs --tail 200 "$NAME" 2>&1 | sed 's/^/  | /' || true
    docker rm -f "$NAME" >/dev/null 2>&1 || true
  fi
  exit "$rc"
}
trap cleanup EXIT

log "starting $IMAGE as $NAME (dns :$DNS_PORT, web :$WEB_PORT)"
docker run -d --rm \
  --name "$NAME" \
  --cap-add=NET_ADMIN \
  -p "127.0.0.1:${DNS_PORT}:53/udp" \
  -p "127.0.0.1:${DNS_PORT}:53/tcp" \
  -p "127.0.0.1:${WEB_PORT}:80/tcp" \
  -e FTLCONF_webserver_api_password=smoke \
  -e FTLCONF_dns_upstreams='127.0.0.1#5335' \
  -e FTLCONF_dns_dnssec='true' \
  -e FTLCONF_dns_listeningMode=single \
  -e TZ=UTC \
  "$IMAGE" >/dev/null

log "waiting for readiness (up to ${READY_TIMEOUT}s)"
ready=0
deadline=$(( $(date +%s) + READY_TIMEOUT ))
while [ "$(date +%s)" -lt "$deadline" ]; do
  if docker exec "$NAME" pgrep -f 'unbound -d' >/dev/null 2>&1 \
     && docker exec "$NAME" pgrep pihole-FTL >/dev/null 2>&1 \
     && dig @127.0.0.1 -p "$DNS_PORT" +time=2 +tries=1 +short cloudflare.com A >/dev/null 2>&1 \
     && curl -fsS -o /dev/null "http://127.0.0.1:${WEB_PORT}/admin/"; then
    ready=1
    break
  fi
  sleep 2
done

if [ "$ready" -ne 1 ]; then
  bad "container did not become ready within ${READY_TIMEOUT}s"
  exit 1
fi
log "ready"

# 1. Container still running
status=$(docker inspect -f '{{.State.Status}}' "$NAME" 2>/dev/null || echo missing)
if [ "$status" = "running" ]; then ok "container status=running"
else bad "container status=$status"; fi

# 2. No fatal markers in logs
logs=$(docker logs "$NAME" 2>&1 || true)
if printf '%s' "$logs" | grep -qiE 'ERROR: Unbound failed to start|FTL crashed|fatal:'; then
  bad "fatal marker in container logs"
else
  ok "no fatal markers in logs"
fi

# 3. Unbound listens on 127.0.0.1:5335 inside the container
if docker exec "$NAME" sh -c "ss -lnup 2>/dev/null | grep -q '127.0.0.1:5335' \
     || netstat -lnup 2>/dev/null | grep -q '127.0.0.1:5335'"; then
  ok "unbound listening on 127.0.0.1:5335"
else
  bad "unbound not listening on 127.0.0.1:5335"
fi

# 4. Recursive resolution via Pi-hole -> Unbound (two names to reduce flake)
recursion_ok=1
for host in example.com cloudflare.com; do
  out=$(dig @127.0.0.1 -p "$DNS_PORT" +time=5 +tries=2 "$host" A 2>&1 || true)
  if printf '%s' "$out" | grep -q 'status: NOERROR' \
     && printf '%s' "$out" | grep -qE '^[^;].*\bIN\b.*\bA\b'; then
    continue
  fi
  bad "recursion check failed for $host"
  printf '%s\n' "$out" | sed 's/^/      /'
  recursion_ok=0
done
[ "$recursion_ok" -eq 1 ] && ok "recursion resolves example.com + cloudflare.com"

# 5. DNSSEC AD flag set on a signed zone
ad_out=$(dig @127.0.0.1 -p "$DNS_PORT" +dnssec +time=5 +tries=2 cloudflare.com A 2>&1 || true)
if printf '%s' "$ad_out" | grep -E '^;; flags:' | grep -q ' ad'; then
  ok "DNSSEC AD flag set on cloudflare.com"
else
  bad "DNSSEC AD flag missing on cloudflare.com (Unbound not validating?)"
  printf '%s\n' "$ad_out" | grep -E '^;; flags:' | sed 's/^/      /' || true
fi

# 6. DNSSEC failure rejected (SERVFAIL)
fail_out=$(dig @127.0.0.1 -p "$DNS_PORT" +time=5 +tries=2 dnssec-failed.org A 2>&1 || true)
if printf '%s' "$fail_out" | grep -q 'status: SERVFAIL'; then
  ok "DNSSEC validation rejects dnssec-failed.org (SERVFAIL)"
else
  bad "dnssec-failed.org did not SERVFAIL — validation chain broken"
  printf '%s\n' "$fail_out" | grep -E '^;; ->>HEADER|^;; flags' | sed 's/^/      /' || true
fi

# 7. Admin UI reachable
code=$(curl -fsS -o /dev/null -w '%{http_code}' "http://127.0.0.1:${WEB_PORT}/admin/" || echo 000)
case "$code" in
  2??|3??) ok "admin UI HTTP $code" ;;
  *)       bad "admin UI HTTP $code" ;;
esac

printf '\n[smoke] passed=%d failed=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
