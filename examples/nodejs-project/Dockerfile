# Dockerfile для Node.js — Multi-stage build
# Поддерживает Node.js 18, 20, 22

# ── Stage 1: Dependencies ──────────────────────────
FROM node:20-alpine AS deps
WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

# ── Stage 2: Build (если нужна сборка) ────────────
FROM node:20-alpine AS builder
WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
# Раскомментировать если есть шаг сборки (React, TypeScript и т.д.)
# RUN npm run build

# ── Stage 3: Production ───────────────────────────
FROM node:20-alpine AS runner
WORKDIR /app

# Безопасность: не запускать от root
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nodeuser

# Копируем только нужное
COPY --from=deps /app/node_modules ./node_modules
COPY --chown=nodeuser:nodejs . .

USER nodeuser

ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "server.js"]
