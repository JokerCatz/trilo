#!/bin/sh
set -eu

now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

: "${GIT_REPO:?}"
: "${GIT_BRANCH:=main}"
: "${HUGO_SRC:=.}"
: "${BASE_URL:=/}"

mkdir -p /workspace /public
touch /workspace/.writecheck || { echo "[init] ERROR: cannot write to /workspace"; exit 1; }
rm -f /workspace/.writecheck

if [ ! -d /workspace/.git ]; then
  git clone --depth=1 -b "${GIT_BRANCH}" "${GIT_REPO}" /workspace
fi

SRC="/workspace/${HUGO_SRC}"

cfg_path=""
for c in "$SRC/hugo.toml" "$SRC/config.toml" "$SRC/hugo.yaml" "$SRC/config.yaml" "$SRC/hugo.json" "$SRC/config.json"; do
  [ -f "$c" ] && cfg_path="$c" && break
done

if [ -z "$cfg_path" ]; then
  mkdir -p "$SRC"
  hugo new site "$SRC" --force
  mkdir -p "$SRC/themes"
  if [ ! -d "$SRC/themes/ananke" ]; then
    git clone --depth=1 https://github.com/theNewDynamic/gohugo-theme-ananke.git "$SRC/themes/ananke"
  fi
  if [ -f "$SRC/hugo.toml" ]; then
    cfg_path="$SRC/hugo.toml"
    printf '\nbaseURL = "%s"\n' "${BASE_URL}" >> "$cfg_path"
    printf 'theme = "ananke"\n' >> "$cfg_path"
    printf 'title = "Trilo Site"\n' >> "$cfg_path"
    printf 'languageCode = "en-us"\n' >> "$cfg_path"
  elif [ -f "$SRC/config.toml" ]; then
    cfg_path="$SRC/config.toml"
    printf '\nbaseURL = "%s"\n' "${BASE_URL}" >> "$cfg_path"
    printf 'theme = "ananke"\n' >> "$cfg_path"
    printf 'title = "Trilo Site"\n' >> "$cfg_path"
    printf 'languageCode = "en-us"\n' >> "$cfg_path"
  elif [ -f "$SRC/hugo.yaml" ]; then
    cfg_path="$SRC/hugo.yaml"
    printf '\nbaseURL: "%s"\n' "${BASE_URL}" >> "$cfg_path"
    printf 'theme: "ananke"\n' >> "$cfg_path"
    printf 'title: "Trilo Site"\n' >> "$cfg_path"
    printf 'languageCode: "en-us"\n' >> "$cfg_path"
  elif [ -f "$SRC/config.yaml" ]; then
    cfg_path="$SRC/config.yaml"
    printf '\nbaseURL: "%s"\n' "${BASE_URL}" >> "$cfg_path"
    printf 'theme: "ananke"\n' >> "$cfg_path"
    printf 'title: "Trilo Site"\n' >> "$cfg_path"
    printf 'languageCode: "en-us"\n' >> "$cfg_path"
  elif [ -f "$SRC/hugo.json" ]; then
    cfg_path="$SRC/hugo.json"
    printf '{ "baseURL": "%s", "theme": "ananke", "title": "Trilo Site", "languageCode": "en-us" }\n' "${BASE_URL}" > "$cfg_path"
  else
    cfg_path="$SRC/config.toml"
    printf 'baseURL = "%s"\n' "${BASE_URL}" > "$cfg_path"
    printf 'theme = "ananke"\n' >> "$cfg_path"
    printf 'title = "Trilo Site"\n' >> "$cfg_path"
    printf 'languageCode = "en-us"\n' >> "$cfg_path"
  fi
  mkdir -p "$SRC/content/posts"
  dt="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '---\ntitle: "Welcome"\ndate: %s\ndraft: false\n---\n\nThis is a starter post.\n' "$dt" > "$SRC/content/posts/welcome.md"
  echo "[init] site initialized @ $(now)"
fi

hugo --gc --minify ${TRILO_HUGO_FLAGS:-} -s "$SRC" -d /public --baseURL "${BASE_URL}" --cleanDestinationDir
echo "[init] initial build done @ $(now)"