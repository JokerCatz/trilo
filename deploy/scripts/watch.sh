#!/bin/sh
set -eu

now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

: "${GIT_REPO:?}"
: "${GIT_BRANCH:=main}"
: "${HUGO_SRC:=.}"
: "${BASE_URL:=/}"
: "${INTERVAL:=300}"

SRC="/workspace/${HUGO_SRC}"

fetch_safe() {
  n=0
  until [ $n -ge 3 ]; do
    git -C /workspace fetch -p --force --depth=1 origin "${GIT_BRANCH}" && return 0
    n=$((n+1))
    sleep $((2*n))
  done
  return 1
}

sync_to_remote() {
  git -C /workspace reset -q --hard "origin/${GIT_BRANCH}" || true
  git -C /workspace clean -xdf -q || true
  git -C /workspace submodule sync --recursive || true
  git -C /workspace submodule update --init --recursive || true
}

build_site() {
  hugo --gc --minify ${TRILO_HUGO_FLAGS:-} -s "$SRC" -d /public --baseURL "${BASE_URL}" --cleanDestinationDir
}

rebuild() {
  echo "[watch] manual rebuild start @ $(now)"
  fetch_safe || true
  sync_to_remote
  build_site
  echo "[watch] manual rebuild done @ $(now)"
}

trap 'rebuild' HUP USR1

while :; do
  if [ -f /tmp/.force_rebuild ]; then
    rm -f /tmp/.force_rebuild
    echo "[watch] forced rebuild start @ $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    rebuild
    echo "[watch] forced rebuild done @ $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  fi
  sleep "${INTERVAL}"
  fetch_safe || true
  LOCAL="$(git -C /workspace rev-parse HEAD || echo "")"
  REMOTE="$(git -C /workspace rev-parse "origin/${GIT_BRANCH}" || echo "")"
  if [ "$LOCAL" != "$REMOTE" ]; then
    echo "[watch] changes detected, rebuilding..."
    sync_to_remote
    build_site
    echo "[watch] rebuild done @ $(now)"
  fi
done