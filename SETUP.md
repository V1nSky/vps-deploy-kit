# 📖 SETUP.md — Полная инструкция по настройке

Пошаговый гайд от нуля до рабочего автодеплоя. Если вы впервые настраиваете CI/CD — этот документ для вас.

---

## Содержание

1. [Что нам понадобится](#1-что-нам-понадобится)
2. [Настройка VPS](#2-настройка-vps)
3. [SSH-ключи для деплоя](#3-ssh-ключи-для-деплоя)
4. [Подключение к Node.js проекту](#4-подключение-к-nodejs-проекту)
5. [Подключение к Python проекту](#5-подключение-к-python-проекту)
6. [Настройка Nginx + SSL](#6-настройка-nginx--ssl)
7. [GitHub Secrets](#7-github-secrets)
8. [Настройка Telegram-уведомлений](#8-настройка-telegram-уведомлений)
9. [Staging и Production окружения](#9-staging-и-production-окружения)
10. [Первый деплой](#10-первый-деплой)
11. [Частые ошибки](#11-частые-ошибки)

---

## 1. Что нам понадобится

- **VPS**: Ubuntu 20.04 или 22.04, минимум 1 GB RAM
- **Домен**: любой домен, указывающий A-записью на IP вашего VPS
- **GitHub репозиторий** с вашим проектом
- **Telegram** (опционально) для уведомлений

---

## 2. Настройка VPS

### 2.1 Подключитесь к серверу

```bash
ssh root@ВАШ_IP
```

### 2.2 Запустите скрипт автонастройки

```bash
curl -o setup.sh \
  https://raw.githubusercontent.com/V1nSky/vps-deploy-kit/main/scripts/setup-server.sh
bash setup.sh
```

Скрипт автоматически:
- Обновит систему
- Установит Docker, Nginx, Certbot, Fail2ban
- Создаст пользователя `deployer` без sudo-прав
- Настроит UFW (firewall): открыты порты 22, 80, 443
- Отключит вход по паролю через SSH
- Настроит ротацию Docker-логов

> ⏱ Время выполнения: 3–5 минут

---

## 3. SSH-ключи для деплоя

GitHub Actions подключается к VPS по SSH-ключу. Никаких паролей.

### 3.1 Сгенерируйте ключ (на локальной машине)

```bash
ssh-keygen -t ed25519 -C "github-deploy" -f ~/.ssh/deploy_key
# Passphrase — оставьте пустым (просто нажмите Enter)
```

Получите два файла:
- `~/.ssh/deploy_key` — приватный ключ (в GitHub Secrets)
- `~/.ssh/deploy_key.pub` — публичный ключ (на сервер)

### 3.2 Добавьте публичный ключ на VPS

```bash
# Скопируйте публичный ключ
cat ~/.ssh/deploy_key.pub
```

Вставьте его на VPS:
```bash
# На сервере, от root:
echo "ВСТАВЬТЕ_СЮДА_ПУБЛИЧНЫЙ_КЛЮЧ" >> /home/deployer/.ssh/authorized_keys
```

### 3.3 Проверьте подключение

```bash
ssh -i ~/.ssh/deploy_key deployer@ВАШ_IP
# Должны увидеть приветствие сервера без запроса пароля
```

---

## 4. Подключение к Node.js проекту

### 4.1 Добавьте Dockerfile в корень проекта

Скопируйте `examples/nodejs-project/Dockerfile` или создайте свой.

**Минимальный Dockerfile:**
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
```

### 4.2 Добавьте /health эндпоинт

```javascript
// Express
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

// NestJS
@Get('/health')
health() { return { status: 'ok' }; }
```

> ⚠️ Без `/health` деплой не завершится успешно и произойдёт откат.

### 4.3 Добавьте workflow

```bash
mkdir -p .github/workflows
curl -o .github/workflows/deploy.yml \
  https://raw.githubusercontent.com/V1nSky/vps-deploy-kit/main/.github/workflows/nodejs-deploy.yml
```

---

## 5. Подключение к Python проекту

### 5.1 Добавьте Dockerfile

Скопируйте `examples/python-project/Dockerfile`.

### 5.2 Добавьте /health эндпоинт

```python
# FastAPI
@app.get("/health")
async def health():
    return {"status": "ok"}

# Flask
@app.route("/health")
def health():
    return {"status": "ok"}, 200
```

### 5.3 Добавьте workflow

```bash
mkdir -p .github/workflows
curl -o .github/workflows/deploy.yml \
  https://raw.githubusercontent.com/V1nSky/vps-deploy-kit/main/.github/workflows/python-deploy.yml
```

---

## 6. Настройка Nginx + SSL

### 6.1 Скопируйте шаблон конфига

```bash
# На VPS:
# Для Node.js
curl -o /etc/nginx/sites-available/myapp \
  https://raw.githubusercontent.com/V1nSky/vps-deploy-kit/main/configs/nginx-node.conf

# Для Python
curl -o /etc/nginx/sites-available/myapp \
  https://raw.githubusercontent.com/V1nSky/vps-deploy-kit/main/configs/nginx-python.conf
```

### 6.2 Замените домен

```bash
sed -i 's/YOUR_DOMAIN/ваш-домен.ru/g' /etc/nginx/sites-available/myapp
```

### 6.3 Активируйте конфиг

```bash
ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/
nginx -t  # Проверка синтаксиса
systemctl reload nginx
```

### 6.4 Получите SSL-сертификат

```bash
certbot --nginx -d ваш-домен.ru -d www.ваш-домен.ru
# Следуйте инструкциям, укажите email
```

Certbot автоматически обновляет сертификат каждые 90 дней.

---

## 7. GitHub Secrets

Перейдите в репозиторий: `Settings → Secrets and variables → Actions`

Нажмите `New repository secret` и добавьте:

| Secret | Где взять |
|--------|-----------|
| `VPS_HOST` | IP адрес вашего VPS |
| `VPS_USER` | `deployer` |
| `VPS_SSH_KEY` | Содержимое файла `~/.ssh/deploy_key` |
| `APP_PORT` | Порт приложения (например `3000`) |
| `STAGING_PORT` | Порт для staging (например `3001`) |
| `PROD_URL` | `https://ваш-домен.ru` |
| `STAGING_URL` | `https://staging.ваш-домен.ru` |
| `TELEGRAM_BOT_TOKEN` | Токен от @BotFather |
| `TELEGRAM_CHAT_ID` | Ваш Telegram chat ID |

### Как скопировать приватный ключ:

```bash
cat ~/.ssh/deploy_key
# Скопируйте всё, включая строки:
# -----BEGIN OPENSSH PRIVATE KEY-----
# ...
# -----END OPENSSH PRIVATE KEY-----
```

---

## 8. Настройка Telegram-уведомлений

### 8.1 Создайте бота

1. Откройте Telegram, найдите [@BotFather](https://t.me/BotFather)
2. Отправьте `/newbot`
3. Придумайте имя и username
4. Получите токен вида: `1234567890:ABCdefGHIjklMNOpqrSTUvwxYZ`

### 8.2 Узнайте ваш Chat ID

1. Найдите бота [@userinfobot](https://t.me/userinfobot)
2. Отправьте `/start`
3. Получите ваш ID — это и есть `TELEGRAM_CHAT_ID`

### 8.3 Напишите боту первым

Зайдите в вашего бота и нажмите **Start** — иначе он не сможет отправлять вам сообщения.

### 8.4 Добавьте секреты

- `TELEGRAM_BOT_TOKEN` = токен из шага 8.1
- `TELEGRAM_CHAT_ID` = ID из шага 8.2

---

## 9. Staging и Production окружения

### 9.1 Создайте окружение Production в GitHub

`Settings → Environments → New environment` → назовите `production`

Добавьте **Required reviewers** — это включает ручной аппрув перед деплоем в прод.

### 9.2 Схема работы

```
git push origin develop  →  деплой на staging (автоматически)
git push origin main     →  ожидание аппрува → деплой на прод
git tag v1.2.0           →  деплой на прод (по тегу)
```

### 9.3 Переменные окружения для приложения

Создайте файл `/opt/app/.env` на VPS:

```bash
# На VPS
cat > /opt/app/.env << 'EOF'
NODE_ENV=production
DATABASE_URL=postgres://user:pass@localhost:5432/mydb
API_KEY=секретный-ключ
EOF

chown deployer:deployer /opt/app/.env
chmod 600 /opt/app/.env
```

Workflow автоматически подхватит этот файл при деплое.

---

## 10. Первый деплой

### 10.1 Закоммитьте все файлы

```bash
git add .github/workflows/deploy.yml Dockerfile
git commit -m "feat: add CI/CD pipeline"
git push origin main
```

### 10.2 Наблюдайте за деплоем

Перейдите в `Actions` в вашем GitHub репозитории.

Вы увидите:
```
✅ Checkout code
✅ Detect environment
✅ Setup SSH
✅ Build Docker image
✅ Transfer image
✅ Deploy on VPS
✅ Health check
✅ Notify success
```

### 10.3 Проверьте результат

```bash
curl https://ваш-домен.ru/health
# {"status":"ok","timestamp":"..."}
```

🎉 **Готово! Автодеплой работает.**

---

## 11. Частые ошибки

### ❌ Permission denied (publickey)

**Причина:** SSH-ключ не добавлен или добавлен неправильно.

```bash
# Проверьте на VPS:
cat /home/deployer/.ssh/authorized_keys
# Убедитесь что файл не пустой

# Проверьте права:
chmod 700 /home/deployer/.ssh
chmod 600 /home/deployer/.ssh/authorized_keys
chown -R deployer:deployer /home/deployer/.ssh
```

### ❌ Health check failed

**Причина:** Приложение не запустилось или `/health` не возвращает 200.

```bash
# Посмотрите логи контейнера
docker logs app-nodejs --tail=50

# Проверьте что контейнер запущен
docker ps

# Проверьте health вручную
curl http://localhost:3000/health
```

### ❌ Docker: permission denied

**Причина:** Пользователь `deployer` не в группе `docker`.

```bash
# На VPS от root:
usermod -aG docker deployer
# Переподключитесь или запустите:
newgrp docker
```

### ❌ Telegram уведомления не приходят

```bash
# Проверьте токен и chat_id через API
curl "https://api.telegram.org/bot<TOKEN>/sendMessage?chat_id=<CHAT_ID>&text=test"
```

### ❌ Nginx 502 Bad Gateway

**Причина:** Приложение не запущено или слушает другой порт.

```bash
docker ps          # Запущен ли контейнер?
netstat -tlnp      # На каком порту слушает?
systemctl status nginx
tail -f /var/log/nginx/error.log
```

### ❌ SSL: Certificate not yet due for renewal

Это не ошибка — Certbot проверяет раз в 12 часов и обновляет за 30 дней до истечения.

```bash
# Проверить текущее состояние:
certbot certificates

# Форсировать обновление (для теста):
certbot renew --dry-run
```

---

*Остались вопросы? Открывайте Issue в репозитории.*

*V1nSky / vps-deploy-kit · MIT License · 2026*
