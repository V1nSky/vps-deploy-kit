# Dockerfile для Python — Multi-stage build
# Поддерживает Python 3.9, 3.10, 3.11, 3.12

# ── Stage 1: Build dependencies ───────────────────
FROM python:3.12-slim AS builder

WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN pip install --upgrade pip
COPY requirements.txt .
RUN pip install --prefix=/install -r requirements.txt

# ── Stage 2: Production ───────────────────────────
FROM python:3.12-slim AS runner

WORKDIR /app

# Безопасность: не запускать от root
RUN addgroup --system --gid 1001 pygroup && \
    adduser --system --uid 1001 --gid 1001 pyuser

# Копируем установленные зависимости
COPY --from=builder /install /usr/local

# Копируем код
COPY --chown=pyuser:pygroup . .

USER pyuser

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
