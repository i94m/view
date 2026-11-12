#!/bin/sh
# Playwright MCP container entrypoint.
#
# Why this exists:
#   Chromium keeps a SingletonLock (plus SingletonCookie / SingletonSocket) in
#   the user-data-dir while a browser instance is running. If the container is
#   SIGKILLed, or the host reboots, those files stay behind on the mounted
#   profile. The lock records "<hostname>-<pid>"; in a fresh container that pid
#   may exist again (pid 1), so Chromium refuses to start with:
#       Browser is already in use for /data/profile
#
#   1. clear stale singleton files before starting (self-heal after restart)
#   2. forward SIGTERM/SIGINT so the browser exits and releases the lock on
#      `docker compose stop` / `down`
set -eu

PROFILE="${PLAYWRIGHT_PROFILE:-/data/profile}"
mkdir -p "$PROFILE"

cleanup_locks() {
    rm -f \
        "$PROFILE/SingletonLock" \
        "$PROFILE/SingletonCookie" \
        "$PROFILE/SingletonSocket"
}

# Stale lock from a previous container instance.
cleanup_locks

node /app/cli.js "$@" &
child=$!

term() {
    kill -TERM "$child" 2>/dev/null || true
    waited=0
    while kill -0 "$child" 2>/dev/null && [ "$waited" -lt 20 ]; do
        waited=$((waited + 1))
        sleep 0.5
    done
    kill -KILL "$child" 2>/dev/null || true
    wait "$child" 2>/dev/null || true
    cleanup_locks
    exit 0
}
trap term TERM INT

status=0
wait "$child" || status=$?
cleanup_locks
exit "$status"
