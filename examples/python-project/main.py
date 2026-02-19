# examples/python-project/main.py
# Минимальный FastAPI сервер с health-check endpoint
# Готов к деплою через vps-deploy-kit

from fastapi import FastAPI
from datetime import datetime
import time

app = FastAPI(title="vps-deploy-kit Python Example")

START_TIME = time.time()


# ✅ Health-check endpoint — ОБЯЗАТЕЛЕН для автодеплоя
@app.get("/health")
async def health():
    return {
        "status": "ok",
        "timestamp": datetime.utcnow().isoformat(),
        "uptime": round(time.time() - START_TIME, 2),
    }


@app.get("/")
async def root():
    return {"message": "Hello from vps-deploy-kit! 🚀"}
