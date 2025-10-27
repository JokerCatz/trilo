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

non_git_any=0
if find "$SRC" -mindepth 1 -not -path "$SRC/.git" -not -path "$SRC/.git/*" -print -quit | grep -q .; then
  non_git_any=1
fi

normalize_cfg() {
  p="$1"
  case "$p" in
    *.toml)
      sed -i '/^[[:space:]]*baseURL[[:space:]]*=/d' "$p"
      sed -i '/^[[:space:]]*theme[[:space:]]*=/d' "$p"
      printf '\nbaseURL = "%s"\n' "${BASE_URL}" >> "$p"
      ;;
    *.yaml|*.yml)
      sed -i '/^[[:space:]]*baseURL[[:space:]]*:/d' "$p"
      sed -i '/^[[:space:]]*theme[[:space:]]*:/d' "$p"
      printf '\nbaseURL: "%s"\n' "${BASE_URL}" >> "$p"
      ;;
    *.json)
      tmp="$(mktemp)"
      printf '{ "baseURL": "%s" }\n' "${BASE_URL}" > "$tmp"
      mv "$tmp" "$p"
      ;;
  esac
}

ensure_minimal_templates() {
  mkdir -p "$SRC/layouts/_default" "$SRC/content/posts"
  [ -f "$SRC/layouts/_default/baseof.html" ] || printf '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{{ block "title" . }}{{ .Title }} | {{ .Site.Title }}{{ end }}</title></head><body><main>{{ block "main" . }}{{ end }}</main></body></html>\n' > "$SRC/layouts/_default/baseof.html"
  [ -f "$SRC/layouts/_default/single.html" ] || printf '{{ define "title" }}{{ .Title }}{{ end }}\n{{ define "main" }}<article><h1>{{ .Title }}</h1><p class="post-meta">{{ .Date.Format "2006-01-02" }}</p>{{ .Content }}</article>{{ end }}\n' > "$SRC/layouts/_default/single.html"
  [ -f "$SRC/layouts/_default/list.html" ] || printf '{{ define "title" }}{{ .Title }}{{ end }}\n{{ define "main" }}<h1>{{ .Title }}</h1><ul class="list">{{ range .Pages.ByDate.Reverse }}<li><a href="{{ .RelPermalink }}">{{ .Title }}</a><div class="post-meta">{{ .Date.Format "2006-01-02" }}</div></li>{{ end }}</ul>{{ end }}\n' > "$SRC/layouts/_default/list.html"
}

ensure_welcome_post() {
  mkdir -p "$SRC/content/posts"
  if [ ! -f "$SRC/content/posts/welcome.md" ]; then
    dt="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '---\ntitle: "Welcome"\ndate: %s\ndraft: false\n---\n\nThis is a starter post.\n' "$dt" > "$SRC/content/posts/welcome.md"
  fi
}

if [ -z "$cfg_path" ] || [ "$non_git_any" -eq 0 ]; then
  mkdir -p "$SRC"
  find "$SRC" -mindepth 1 -maxdepth 1 -not -name ".git" -exec rm -rf {} +
  hugo new site "$SRC" --force
  for c in "$SRC/hugo.toml" "$SRC/config.toml" "$SRC/hugo.yaml" "$SRC/config.yaml" "$SRC/hugo.json" "$SRC/config.json"; do
    [ -f "$c" ] && cfg_path="$c" && break
  done
  if [ -n "$cfg_path" ]; then
    normalize_cfg "$cfg_path"
  fi
  ensure_minimal_templates
  ensure_welcome_post
  echo "[init] site initialized with minimal templates @ $(now)"
fi

hugo --gc --minify ${TRILO_HUGO_FLAGS:-} -s "$SRC" -d /public --baseURL "${BASE_URL}" --cleanDestinationDir
echo "[init] initial build done @ $(now)"