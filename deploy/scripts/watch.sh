#!/bin/sh
set -eu

now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

: "${GIT_REPO:?}"
echo "[hugo] tz=${TZ:-UTC} branch=${GIT_BRANCH:-main} interval=${INTERVAL:-300}"
echo "[hugo] repo=${GIT_REPO}"

mkdir -p /workspace /public
touch /workspace/.writecheck || { echo "[hugo] ERROR: cannot write to /workspace (fix ownership of host path)"; exit 1; }
rm -f /workspace/.writecheck

fetch_safe() {
  n=0
  until [ $n -ge 3 ]; do
    git -C /workspace fetch --depth=1 -q origin "${GIT_BRANCH:-main}" && return 0
    n=$((n+1))
    sleep $((2*n))
  done
  return 1
}

build_site() {
  git -C /workspace submodule update --init --recursive || true
  hugo --gc --minify ${TRILO_HUGO_FLAGS:-} \
       -s "/workspace/${HUGO_SRC:-.}" \
       -d /public \
       --baseURL "${BASE_URL:-http://localhost/}" \
       --cleanDestinationDir
}

rebuild() {
  echo "[hugo] manual rebuild..."
  fetch_safe || true
  git -C /workspace reset -q --hard "origin/${GIT_BRANCH:-main}" || true
  build_site
  echo "[hugo] manual rebuild done @ $(now)"
}

trap 'rebuild' HUP USR1

if [ ! -d /workspace/.git ]; then
  git clone --depth=1 -b "${GIT_BRANCH:-main}" "${GIT_REPO}" /workspace
fi

build_site
echo "[hugo] initial build done @ $(now)"

while :; do
  sleep "${INTERVAL:-300}"
  fetch_safe || true
  LOCAL="$(git -C /workspace rev-parse HEAD || echo "")"
  REMOTE="$(git -C /workspace rev-parse "origin/${GIT_BRANCH:-main}" || echo "")"
  if [ "$LOCAL" != "$REMOTE" ]; then
    echo "[hugo] changes detected, rebuilding..."
    git -C /workspace reset -q --hard "origin/${GIT_BRANCH:-main}"
    build_site
    echo "[hugo] rebuild done @ $(now)"
  fi
done