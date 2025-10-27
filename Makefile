SHELL := /bin/sh
ENV_FILE := .env
COMPOSE := docker compose --env-file .env -f deploy/docker-compose.yml

ifeq ($(wildcard $(ENV_FILE)),)
$(error Missing .env. Copy .env.template to .env and edit it before running make)
endif

include $(ENV_FILE)
export $(shell sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$$/d' -e 's/^\([^=[:space:]]\+\)=.*/\1/' $(ENV_FILE))

.PHONY: preflight up down logs logs-hugo rebuild build restart ps fix-perms hugo hugo-new hugo-serve build-local help

preflight:
	mkdir -p $(TRILO_PUBLIC_DIR) $(TRILO_WORKSPACE_DIR)
	docker run --rm -v $$PWD:/mnt busybox sh -c 'chown -R $(TRILO_PUID):$(TRILO_PGID) /mnt/$(TRILO_PUBLIC_DIR) /mnt/$(TRILO_WORKSPACE_DIR)'

up: preflight
	$(COMPOSE) --compatibility up -d --build

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f

logs-hugo:
	$(COMPOSE) logs -f hugo

rebuild:
	$(COMPOSE) kill -s HUP hugo

build:
	$(COMPOSE) build hugo

restart:
	$(COMPOSE) restart

ps:
	$(COMPOSE) ps

fix-perms:
	docker run --rm -v $$PWD:/mnt busybox sh -c 'chown -R $(TRILO_PUID):$(TRILO_PGID) /mnt/$(TRILO_PUBLIC_DIR) /mnt/$(TRILO_WORKSPACE_DIR)'

hugo:
	docker run --rm -it -u $(TRILO_PUID):$(TRILO_PGID) -e TZ=$(TRILO_TZ) -v $$PWD:/workspace -w /workspace hugomods/hugo:exts hugo $(ARGS)

hugo-new:
	docker run --rm -it -u $(TRILO_PUID):$(TRILO_PGID) -e TZ=$(TRILO_TZ) -v $$PWD:/workspace -w /workspace hugomods/hugo:exts hugo new $(PATH)

hugo-serve:
	docker run --rm -it -u $(TRILO_PUID):$(TRILO_PGID) -e TZ=$(TRILO_TZ) -p $(TRILO_DEV_PORT):1313 -v $$PWD:/workspace -w /workspace hugomods/hugo:exts hugo server -D --bind 0.0.0.0 -p 1313

build-local:
	docker run --rm -it -u $(TRILO_PUID):$(TRILO_PGID) -e TZ=$(TRILO_TZ) -v $$PWD:/workspace -w /workspace hugomods/hugo:exts hugo --gc --minify $(TRILO_HUGO_FLAGS) -s $(TRILO_HUGO_SRC) -d $(TRILO_PUBLIC_DIR) --baseURL $(TRILO_BASE_URL) --cleanDestinationDir

help:
	@echo "Available targets:"
	@echo "  up            Build and start services"
	@echo "  down          Stop and remove services"
	@echo "  logs          Follow all service logs"
	@echo "  logs-hugo     Follow Hugo logs"
	@echo "  rebuild       Trigger immediate rebuild (SIGHUP)"
	@echo "  build         Rebuild only the Hugo image"
	@echo "  restart       Restart all services"
	@echo "  ps            List services"
	@echo "  fix-perms     Re-apply PUID/PGID ownership on public/ and workspace/"
	@echo "  hugo          Run arbitrary Hugo command via container (ARGS='...')"
	@echo "  hugo-new      Create a new content file (PATH='content/posts/slug.md')"
	@echo "  hugo-serve    Local preview server on TRILO_DEV_PORT"
	@echo "  build-local   Build to ./public without deployment"