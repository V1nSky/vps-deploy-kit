#!/bin/bash
# deploy.sh — Скрипт деплоя контейнера
# Использование: ./deploy.sh <image> <container> <port> <container_port> [env_file]

set -e

IMAGE="${1:?Укажи Docker image}"
CONTAINER="${2:?Укажи имя контейнера}"
HOST_PORT="${3:?Укажи порт на хосте}"
CONTAINER_PORT="${4:-3000}"
ENV_FILE="${5:-}"

echo "🚀 Деплой: $CONTAINER"
echo "   Image:  $IMAGE"
echo "   Port:   $HOST_PORT → $CONTAINER_PORT"

# Сохранить точку отката
if docker ps -q -f name="$CONTAINER" | grep -q .; then
  PREV=$(docker inspect "$CONTAINER" --format='{{.Image}}')
  echo "$PREV" > "/tmp/${CONTAINER}_rollback"
  echo "💾 Точка отката: $PREV"
fi

# Остановить старый контейнер
docker stop "$CONTAINER" 2>/dev/null || true
docker rm "$CONTAINER" 2>/dev/null || true

# Собрать аргументы
ENV_ARG=""
[ -n "$ENV_FILE" ] && [ -f "$ENV_FILE" ] && ENV_ARG="--env-file $ENV_FILE"

# Запустить новый
docker run -d \
  --name "$CONTAINER" \
  --restart unless-stopped \
  -p "$HOST_PORT:$CONTAINER_PORT" \
  $ENV_ARG \
  "$IMAGE"

echo "✅ Контейнер запущен: $CONTAINER"
