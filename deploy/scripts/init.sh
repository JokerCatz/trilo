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

fetch_sync() {
  git -C /workspace fetch -p --force --depth=1 origin "${GIT_BRANCH}" || true
  git -C /workspace reset -q --hard "origin/${GIT_BRANCH}" || true
  git -C /workspace clean -xdf -q || true
  git -C /workspace submodule sync --recursive || true
  git -C /workspace submodule update --init --recursive || true
}

config_exists() {
  [ -f "$SRC/hugo.toml" ] || [ -f "$SRC/config.toml" ] || \
  [ -f "$SRC/hugo.yaml" ] || [ -f "$SRC/config.yaml" ] || \
  [ -f "$SRC/hugo.json" ] || [ -f "$SRC/config.json" ] || \
  [ -f "$SRC/config/_default/config.toml" ] || [ -f "$SRC/config/_default/hugo.toml" ] || \
  [ -f "$SRC/config/_default/config.yaml" ] || [ -f "$SRC/config/_default/hugo.yaml" ] || \
  [ -f "$SRC/config/_default/config.json" ] || [ -f "$SRC/config/_default/hugo.json" ]
}

content_exists() {
  find "$SRC/content" -type f -name '*.md' -print -quit 2>/dev/null | grep -q .
}

write_minimal_config_and_templates() {
  mkdir -p "$SRC/layouts/_default" "$SRC/content/posts" "$SRC/config/_default"
  if [ ! -f "$SRC/config/_default/config.toml" ] && [ ! -f "$SRC/config.toml" ] && [ ! -f "$SRC/hugo.toml" ]; then
    printf 'baseURL = "%s"\n' "${BASE_URL}" > "$SRC/config/_default/config.toml"
    printf 'title = "Trilo Site"\n' >> "$SRC/config/_default/config.toml"
    printf 'languageCode = "en-us"\n' >> "$SRC/config/_default/config.toml"
    printf 'paginate = 10\n' >> "$SRC/config/_default/config.toml"
  fi
  [ -f "$SRC/layouts/_default/baseof.html" ] || printf '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{{ block "title" . }}{{ .Title }} | {{ .Site.Title }}{{ end }}</title></head><body><main>{{ block "main" . }}{{ end }}</main></body></html>\n' > "$SRC/layouts/_default/baseof.html"
  [ -f "$SRC/layouts/_default/single.html" ] || printf '{{ define "title" }}{{ .Title }}{{ end }}\n{{ define "main" }}<article><h1>{{ .Title }}</h1><p class="post-meta">{{ .Date.Format "2006-01-02" }}</p>{{ .Content }}</article>{{ end }}\n' > "$SRC/layouts/_default/single.html"
  [ -f "$SRC/layouts/_default/list.html" ] || printf '{{ define "title" }}{{ .Title }}{{ end }}\n{{ define "main" }}<h1>{{ .Title }}</h1><ul class="list">{{ range .Pages.ByDate.Reverse }}<li><a href="{{ .RelPermalink }}">{{ .Title }}</a><div class="post-meta">{{ .Date.Format "2006-01-02" }}</div></li>{{ end }}</ul>{{ end }}\n' > "$SRC/layouts/_default/list.html"
  if [ ! -f "$SRC/content/posts/welcome.md" ]; then
    dt="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '---\ntitle: "Welcome"\ndate: %s\ndraft: false\n---\n\nThis is a starter post.\n' "$dt" > "$SRC/content/posts/welcome.md"
  fi
}

build_site() {
  hugo --gc --minify ${TRILO_HUGO_FLAGS:-} -s "$SRC" -d /public --baseURL "${BASE_URL}" --cleanDestinationDir
}

fetch_sync

if ! config_exists && ! content_exists; then
  write_minimal_config_and_templates
  echo "[init] minimal config and templates created @ $(now)"
fi

build_site
echo "[init] initial build done @ $(now)"