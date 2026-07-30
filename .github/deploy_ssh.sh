#!/usr/bin/env bash
# Выполняется на сервере после git reset --hard (см. CI/CD workflow).
set -euo pipefail

echo "==> Working directory: $(pwd)"

if [ ! -f docker-compose.yaml ] && [ ! -f docker-compose.yml ]; then
  echo "ERROR: docker-compose.yaml not found in $(pwd)"
  exit 1
fi

if ! docker network inspect diary20_default >/dev/null 2>&1; then
  echo "ERROR: Docker network diary20_default not found."
  echo "Start Diary first (its compose creates this network), or fix networks.diary_net.name in compose."
  exit 1
fi

if ! docker network inspect extra_services >/dev/null 2>&1; then
  echo "ERROR: Docker network extra_services not found."
  echo "Create once: docker network create extra_services"
  exit 1
fi

echo "==> docker compose up --build -d"
docker compose up --build -d

echo "==> docker compose ps"
docker compose ps

echo "==> Deploy finished"
