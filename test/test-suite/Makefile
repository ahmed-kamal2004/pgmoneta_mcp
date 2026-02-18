## Copyright (C) 2026 The pgmoneta community
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program. If not, see <https://www.gnu.org/licenses/>.
IMAGE_NAME = pgmoneta_mcp-test-suite
CONTAINER_NAME = pgmoneta-container
CONTAINER_ENGINE := $(shell \
	if command -v podman >/dev/null 2>&1; then echo podman; \
	elif command -v docker >/dev/null 2>&1; then echo "sudo docker"; \
	else echo "Neither Docker nor Podman is installed" >&2; exit 1; \
	fi)

.PHONY: all build clean


all:
	make clean
	make build
	make run-default
build:
	$(CONTAINER_ENGINE) build --no-cache -t $(IMAGE_NAME) .

clean:
	$(CONTAINER_ENGINE) stop $(CONTAINER_NAME) 2>/dev/null || true
	$(CONTAINER_ENGINE) rm -f $(CONTAINER_NAME) 2>/dev/null || true
	$(CONTAINER_ENGINE) rmi -f $(IMAGE_NAME) 2>/dev/null || true
run-default:
	$(CONTAINER_ENGINE) run -p 5002:5002 -p 5001:5001 -p 9100:9100 -p 5432:5432 --name $(CONTAINER_NAME) -d -e PG_DATABASE=mydb -e PG_USER_NAME=myuser -e PG_USER_PASSWORD=mypass -e PG_NETWORK_MASK=all -e PG_PRIMARY_NAME=localhost -e PG_PRIMARY_PORT=5432 -e PG_REPL_USER_NAME=backup_user -e PG_REPL_USER_PASSWORD=backup_pass --replace localhost/$(IMAGE_NAME)

