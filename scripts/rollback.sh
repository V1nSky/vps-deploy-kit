#!/bin/bash
# rollback.sh — Откат к предыдущей версии
# Использование: ./rollback.sh <container_name> <host_port> <container_port>

set -e

CONTAINER="${1:?Укажи имя контейнера}"
HOST_PORT="${2:?Укажи порт}"
CONTAINER_PORT="${3:-3000}"
ROLLBACK_FILE="/tmp/${CONTAINER}_rollback"

echo "🔙 Откат контейнера: $CONTAINER"

if [ ! -f "$ROLLBACK_FILE" ]; then
  echo "❌ Точка отката не найдена: $ROLLBACK_FILE"
  echo "   Доступные образы:"
  docker images --format "  {{.Repository}}:{{.Tag}} ({{.CreatedSince}})"
  exit 1
fi

ROLLBACK_IMAGE=$(cat "$ROLLBACK_FILE")
echo "   Откат к образу: $ROLLBACK_IMAGE"

docker stop "$CONTAINER" 2>/dev/null || true
docker rm "$CONTAINER" 2>/dev/null || true

docker run -d \
  --name "$CONTAINER" \
  --restart unless-stopped \
  -p "$HOST_PORT:$CONTAINER_PORT" \
  "$ROLLBACK_IMAGE"

echo "✅ Откат выполнен! Запущен: $ROLLBACK_IMAGE"
