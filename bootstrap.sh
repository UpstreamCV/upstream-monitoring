#!/usr/bin/env bash
# One-shot setup for a fresh Lightsail Ubuntu 22.04 instance.
# Idempotent: re-running is a no-op once Docker is installed.

set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
	echo "Installing Docker..."
	curl -fsSL https://get.docker.com | sudo sh
	sudo usermod -aG docker "$USER"
	echo "Docker installed. Log out and back in (or run \`newgrp docker\`) before running compose."
else
	echo "Docker already installed: $(docker --version)"
fi

# `docker compose` plugin ships with get.docker.com; confirm.
docker compose version >/dev/null 2>&1 || {
	echo "docker compose plugin missing — install manually." >&2
	exit 1
}

echo "Bootstrap done. Next: docker compose up -d"
