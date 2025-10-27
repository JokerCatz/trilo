# Trilo (Hugo + Nginx) — Setup and Usage

Trilo serves a Hugo site via Nginx and auto-rebuilds from a public Git repository on a schedule. The Hugo project lives at the repo root; deployment assets live under `deploy/`. All configuration is centralized in `.env` with a `TRILO_` prefix.

- No secrets; public Git only
- No Docker volumes; local directory bindings
- Comment-free config; this document holds the explanations

---

## Choose Your Repo Workflow

You should not push content to the upstream project directly. Pick one of the following:

### Recommended: Use as a Template
1. Click “Use this template” on the upstream project to create your own public repo.
2. Clone your repo.
3. Set `TRILO_GIT_REPO` in `.env` to the HTTPS URL of your repo.
4. Proceed with [Quick Start](#quick-start-deployment).

### Alternative: Fork
1. Fork the upstream project.
2. Clone your fork.
3. Set `TRILO_GIT_REPO` in `.env` to the HTTPS URL of your fork.
4. Optionally add `upstream` to receive updates:
   ```bash
   git remote add upstream <upstream-url>
   git fetch upstream
   git merge upstream/main   # or rebase
   ````
5. Proceed with [Quick Start](#quick-start-deployment).

---

## Project Layout

* `content/` — Markdown content
* `themes/` — Hugo themes (optional)
* `layouts/` — Custom templates (optional)
* `static/` — Static assets (optional)
* `assets/` — Hugo asset pipeline (optional)
* `archetypes/` — Content blueprints (optional)
* `data/` — Data files (optional)
* `config.toml|yaml|json` — Hugo configuration
* `public/` — Built output (served by Nginx)
* `workspace/` — Working copy used by the deploy watcher
* `deploy/` — Docker deployment assets

  * `docker-compose.yml`
  * `Dockerfile.hugo`
  * `scripts/watch.sh`
  * `nginx/conf.d/default.conf`
* `.env` — Environment variables for deployment/tooling
* `Makefile` — Unified command entrypoints

Suggested placeholders to keep an empty skeleton tracked:

```
content/.keep
static/.keep
assets/.keep
layouts/.keep
archetypes/.keep
data/.keep
public/.keep
workspace/.keep
```

---

## Requirements

* Docker and Docker Compose v2+
* A public Git repository URL for your own repo
* An available host port for HTTP

---

## Quick Start (Deployment)

```bash
cp .env.template .env
mkdir -p public workspace
sudo chown -R $(id -u):$(id -g) public workspace

# Edit .env minimally:
# TRILO_GIT_REPO          -> your repo HTTPS URL (template or fork)
# TRILO_BASE_URL          -> your public site URL (recommend HTTPS)
# TRILO_NGINX_HTTP_PORT   -> host port to expose (container is fixed at 80)
# TRILO_PUID / TRILO_PGID -> your numeric UID/GID (id -u / id -g)

make up
```

Visit: `http://<host>:<TRILO_NGINX_HTTP_PORT>`

`web` waits for the first `hugo` build via a health check. The watcher rebuilds on new upstream commits, or on demand.

---

## Environment Variables

All variables live in `.env` with a `TRILO_` prefix.

| Variable                  | Purpose                                                 | Example                         |
| ------------------------- | ------------------------------------------------------- | ------------------------------- |
| `TRILO_PREFIX`            | Compose project/container name prefix                   | `trilo`                         |
| `TRILO_NGINX_HTTP_PORT`   | Host port mapped to container port `80`                 | `80`                            |
| `TRILO_TZ`                | Time zone passed to containers                          | `Asia/Taipei`                   |
| `TRILO_PUID`              | Host UID to own generated files                         | `1000`                          |
| `TRILO_PGID`              | Host GID to own generated files                         | `1000`                          |
| `TRILO_PUBLIC_DIR`        | Local directory for built static site                   | `public`                        |
| `TRILO_WORKSPACE_DIR`     | Local directory where the repo is cloned by the watcher | `workspace`                     |
| `TRILO_GIT_REPO`          | Public Git repo URL for your site                       | `https://github.com/u/repo.git` |
| `TRILO_GIT_BRANCH`        | Branch to build                                         | `main`                          |
| `TRILO_HUGO_SRC`          | Path to Hugo project within the repo                    | `.` or `site`                   |
| `TRILO_BASE_URL`          | Public site URL used by Hugo (sitemap/canonical/assets) | `https://blog.example.com/`     |
| `TRILO_INTERVAL`          | Seconds between remote checks                           | `120`                           |
| `TRILO_LOG_MAX_SIZE`      | Log rotation size for Docker json-file driver           | `10m`                           |
| `TRILO_LOG_MAX_FILE`      | Log rotation file count                                 | `3`                             |
| `TRILO_WEB_LIMIT_CPUS`    | CPU limit for `web`                                     | `0.50`                          |
| `TRILO_WEB_LIMIT_MEMORY`  | Memory limit for `web`                                  | `256M`                          |
| `TRILO_HUGO_LIMIT_CPUS`   | CPU limit for `hugo`                                    | `1.00`                          |
| `TRILO_HUGO_LIMIT_MEMORY` | Memory limit for `hugo`                                 | `512M`                          |
| `TRILO_HUGO_FLAGS`        | Extra Hugo CLI flags for deployment builds              | `--enableGitInfo`               |
| `TRILO_DEV_PORT`          | Local preview port for `make hugo-serve`                | `1313`                          |

---

## Makefile

All `make` targets auto-load and export `.env`. If `.env` is missing, `make` exits with an error. The Makefile wraps Docker Compose and runs Hugo inside a container, so no local Hugo install is required.

Common targets:

```bash
make up
make logs
make logs-hugo
make rebuild
make down
make restart
make ps
```

Hugo targets:

```bash
make hugo-new PATH="content/posts/hello-world.md"
make hugo-serve
make hugo ARGS="version"
make build-local
```

---

## Security Notes

* Read-only root filesystems for `web` and `hugo`
* Dropped capabilities and `no-new-privileges`
* tmpfs for runtime directories (`/var/cache/nginx`, `/var/run`, `/tmp`)
* `HOME=/workspace` for Hugo
* Only `public/` and `workspace/` are writable

Nginx headers and behavior can be customized by adding files under `deploy/nginx/conf.d`.

---

## Logging and Disk Usage

Both services use the `json-file` driver with rotation:

* `TRILO_LOG_MAX_SIZE` (default `10m`)
* `TRILO_LOG_MAX_FILE` (default `3`)

Inspect logs with:

```bash
make logs
make logs-hugo
```

---

## Resource Limits

Set limits in `.env`:

* `TRILO_WEB_LIMIT_CPUS`, `TRILO_WEB_LIMIT_MEMORY`
* `TRILO_HUGO_LIMIT_CPUS`, `TRILO_HUGO_LIMIT_MEMORY`

`make up` uses `--compatibility` so `deploy.resources.limits` apply under non-Swarm Compose.

---

## Reverse Proxy

Trilo serves plain HTTP inside the container. Place a reverse proxy or TLS terminator in front if you need HTTPS. Align `TRILO_BASE_URL` with the final public URL so Hugo generates correct canonical links and sitemaps.

---

## Windows Notes

Use WSL2 for best results. Paths in `.env` are POSIX-style; adjust if you use native Windows path mappings.

---

## Suggested .gitignore

At minimum:

```
.env
public/
workspace/
resources/
```

Keep `.keep` files to preserve empty folders:

```
!public/.keep
!workspace/.keep
!resources/.keep
```

---

## Hugo Usage

### Basics

Write Markdown in `content/`. Hugo resolves templates from `themes/` or `layouts/`, and outputs static files to `public/`.

### Create Content

```bash
make hugo-new PATH="content/posts/hello-world.md"
```

Edit the generated file and its front matter.

### Local Preview

```bash
make hugo-serve
```

Preview at `http://localhost:<TRILO_DEV_PORT>`. Stop with Ctrl+C.

### Arbitrary Hugo Commands

```bash
make hugo ARGS="version"
make hugo ARGS="list drafts"
```

### Local Build Without Deployment

```bash
make build-local
```

### Content Structure

* Posts: `content/posts/<slug>.md`
* Pages: `content/<name>/index.md`
* Assets: `static/` or colocated files with leaf bundles
* Optional: `assets/` for Pipes, `data/` for data-driven content

### Front Matter

```yaml
---
title: "Hello World"
date: 2025-01-01T00:00:00Z
draft: true
tags: ["intro"]
---
```

Set `draft: false` to publish.

### Themes

Add a theme under `themes/` and reference it in `config.toml`:

```toml
theme = "PaperMod"
```

If using submodules:

```bash
git submodule add https://github.com/adityatelange/hugo-PaperMod themes/PaperMod
git submodule update --init --recursive
```

### Giscus (Comments)

Enable Discussions on your repo and configure Giscus at [https://giscus.app/](https://giscus.app/). Insert the script into your single-post template. No changes to deployment are required.

### Troubleshooting

* `.env` missing: `make` exits with an error; copy `.env.template` to `.env`.
* Permissions: ensure `public/` and `workspace/` are owned by your UID/GID.
* Blank site on first boot: wait for the `hugo` health check or run `make rebuild`.
* Port conflicts: adjust `TRILO_NGINX_HTTP_PORT` or `TRILO_DEV_PORT` in `.env`.

---

## Contributions

This upstream repository is intended as a template. Please do not open PRs against upstream. Create your own repo via “Use this template” or fork, and maintain changes there. Security reports can be sent via your chosen channel.

---

## License

WTFPL 2