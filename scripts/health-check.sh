#!/bin/bash
# health-check.sh — Проверка здоровья приложения
# Использование: ./health-check.sh <url> [retries] [delay]

URL="${1:?Укажи URL для проверки}"
RETRIES="${2:-6}"
DELAY="${3:-5}"

echo "❤️  Health check: $URL"
echo "   Попыток: $RETRIES, задержка: ${DELAY}s"

for i in $(seq 1 "$RETRIES"); do
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$URL" || echo "000")
  echo "   Попытка $i/$RETRIES: HTTP $HTTP_STATUS"

  if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ Приложение отвечает!"
    exit 0
  fi

  [ "$i" -lt "$RETRIES" ] && sleep "$DELAY"
done

echo "❌ Health check не прошёл после $RETRIES попыток"
exit 1
