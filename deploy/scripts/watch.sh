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
    git -C /workspace fetch --depth=1 -q origin "${GIT_BRANCH}" && return 0
    n=$((n+1))
    sleep $((2*n))
  done
  return 1
}

build_site() {
  git -C /workspace submodule update --init --recursive || true
  hugo --gc --minify ${TRILO_HUGO_FLAGS:-} -s "$SRC" -d /public --baseURL "${BASE_URL}" --cleanDestinationDir
}

rebuild() {
  echo "[watch] manual rebuild..."
  fetch_safe || true
  git -C /workspace reset -q --hard "origin/${GIT_BRANCH}" || true
  build_site
  echo "[watch] manual rebuild done @ $(now)"
}

trap 'rebuild' HUP USR1

while :; do
  sleep "${INTERVAL}"
  fetch_safe || true
  LOCAL="$(git -C /workspace rev-parse HEAD || echo "")"
  REMOTE="$(git -C /workspace rev-parse "origin/${GIT_BRANCH}" || echo "")"
  if [ "$LOCAL" != "$REMOTE" ]; then
    echo "[watch] changes detected, rebuilding..."
    git -C /workspace reset -q --hard "origin/${GIT_BRANCH}"
    build_site
    echo "[watch] rebuild done @ $(now)"
  fi
done