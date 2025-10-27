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
      sed -i -E '/^[[:space:]]*baseURL[[:space:]]*=/d' "$p"
      sed -i -E '/^[[:space:]]*theme[[:space:]]*=/d' "$p"
      printf '\nbaseURL = "%s"\n' "${BASE_URL}" >> "$p"
      [ "${1:-}" ] >/dev/null 2>&1 ;; # no-op to keep case format
    *.yaml|*.yml)
      sed -i -E '/^[[:space:]]*baseURL[[:space:]]*:/d' "$p"
      sed -i -E '/^[[:space:]]*theme[[:space:]]*:/d' "$p"
      printf '\nbaseURL: "%s"\n' "${BASE_URL}" >> "$p"
      ;;
    *.json)
      tmp="$(mktemp)"
      theme_json='"theme": "ananke"'
      printf '{ "baseURL": "%s", %s }\n' "${BASE_URL}" "${theme_json}" > "$tmp"
      mv "$tmp" "$p"
      ;;
  esac
}

set_theme() {
  p="$1"
  case "$p" in
    *.toml) printf 'theme = "ananke"\n' >> "$p" ;;
    *.yaml|*.yml) printf 'theme: "ananke"\n' >> "$p" ;;
    *.json) : ;; # already handled in normalize_cfg for json
  esac
}

if [ -z "$cfg_path" ] || [ "$non_git_any" -eq 0 ]; then
  mkdir -p "$SRC"
  find "$SRC" -mindepth 1 -maxdepth 1 -not -name ".git" -exec rm -rf {} +
  hugo new site "$SRC" --force
  mkdir -p "$SRC/themes"
  theme_ok=0
  if git clone --depth=1 https://github.com/theNewDynamic/gohugo-theme-ananke.git "$SRC/themes/ananke" 2>/dev/null; then
    theme_ok=1
  fi
  cfg_path=""
  for c in "$SRC/hugo.toml" "$SRC/config.toml" "$SRC/hugo.yaml" "$SRC/config.yaml" "$SRC/hugo.json" "$SRC/config.json"; do
    [ -f "$c" ] && cfg_path="$c" && break
  done
  if [ -n "$cfg_path" ]; then
    normalize_cfg "$cfg_path"
    [ "$theme_ok" -eq 1 ] && set_theme "$cfg_path"
  fi
  mkdir -p "$SRC/content/posts"
  dt="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '---\ntitle: "Welcome"\ndate: %s\ndraft: false\n---\n\nThis is a starter post.\n' "$dt" > "$SRC/content/posts/welcome.md"
  if [ "$theme_ok" -eq 0 ]; then
    mkdir -p "$SRC/layouts/_default"
    printf '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{{ block "title" . }}{{ .Title }} | {{ .Site.Title }}{{ end }}</title></head><body><main>{{ block "main" . }}{{ end }}</main></body></html>\n' > "$SRC/layouts/_default/baseof.html"
    printf '{{ define "title" }}{{ .Title }}{{ end }}\n{{ define "main" }}<article><h1>{{ .Title }}</h1><p class="post-meta">{{ .Date.Format "2006-01-02" }}</p>{{ .Content }}</article>{{ end }}\n' > "$SRC/layouts/_default/single.html"
    printf '{{ define "title" }}{{ .Title }}{{ end }}\n{{ define "main" }}<h1>{{ .Title }}</h1><ul class="list">{{ range .Pages.ByDate.Reverse }}<li><a href="{{ .RelPermalink }}">{{ .Title }}</a><div class="post-meta">{{ .Date.Format "2006-01-02" }}</div></li>{{ end }}</ul>{{ end }}\n' > "$SRC/layouts/_default/list.html"
  fi
  echo "[init] site initialized via 'hugo new site' @ $(now)"
fi

hugo --gc --minify ${TRILO_HUGO_FLAGS:-} -s "$SRC" -d /public --baseURL "${BASE_URL}" --cleanDestinationDir
echo "[init] initial build done @ $(now)"