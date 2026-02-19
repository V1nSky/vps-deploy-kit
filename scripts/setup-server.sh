#!/bin/bash
# setup-server.sh — Настройка VPS для автодеплоя
# Запускать от root: bash setup-server.sh
# Автор: V1nSky | vps-deploy-kit

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info()  { echo -e "${BLUE}[→]${NC} $1"; }

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🚀 vps-deploy-kit — Настройка сервера"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check root
[ "$EUID" -ne 0 ] && error "Запустите скрипт от root: sudo bash setup-server.sh"

# Check Ubuntu
source /etc/os-release
[[ "$ID" != "ubuntu" ]] && warn "Скрипт тестировался на Ubuntu. Продолжаем на свой страх и риск..."

# Config
DEPLOY_USER="deployer"
APP_DIR="/opt/app"
DOCKER_COMPOSE_VERSION="2.24.0"

info "Обновление системы..."
apt-get update -qq
apt-get upgrade -y -qq
log "Система обновлена"

info "Установка базовых утилит..."
apt-get install -y -qq \
  curl wget git ufw fail2ban \
  htop nano vim \
  ca-certificates gnupg lsb-release
log "Утилиты установлены"

# Docker
if ! command -v docker &>/dev/null; then
  info "Установка Docker..."
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable docker
  systemctl start docker
  log "Docker установлен: $(docker --version)"
else
  log "Docker уже установлен: $(docker --version)"
fi

# Nginx
if ! command -v nginx &>/dev/null; then
  info "Установка Nginx..."
  apt-get install -y -qq nginx
  systemctl enable nginx
  log "Nginx установлен"
else
  log "Nginx уже установлен"
fi

# Certbot (Let's Encrypt)
if ! command -v certbot &>/dev/null; then
  info "Установка Certbot..."
  apt-get install -y -qq certbot python3-certbot-nginx
  log "Certbot установлен"
else
  log "Certbot уже установлен"
fi

# Deployer user
if ! id "$DEPLOY_USER" &>/dev/null; then
  info "Создание пользователя $DEPLOY_USER..."
  useradd -m -s /bin/bash "$DEPLOY_USER"
  usermod -aG docker "$DEPLOY_USER"
  mkdir -p /home/$DEPLOY_USER/.ssh
  chmod 700 /home/$DEPLOY_USER/.ssh
  touch /home/$DEPLOY_USER/.ssh/authorized_keys
  chmod 600 /home/$DEPLOY_USER/.ssh/authorized_keys
  chown -R $DEPLOY_USER:$DEPLOY_USER /home/$DEPLOY_USER/.ssh
  log "Пользователь $DEPLOY_USER создан"
  warn "Добавьте публичный SSH-ключ в /home/$DEPLOY_USER/.ssh/authorized_keys"
else
  log "Пользователь $DEPLOY_USER уже существует"
  usermod -aG docker "$DEPLOY_USER"
fi

# App directory
info "Создание рабочих директорий..."
mkdir -p "$APP_DIR"
mkdir -p "$APP_DIR/data"
mkdir -p "$APP_DIR/logs"
chown -R $DEPLOY_USER:$DEPLOY_USER "$APP_DIR"
log "Директория $APP_DIR создана"

# Firewall
info "Настройка UFW (firewall)..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
# Close direct app ports from outside (only through nginx)
ufw --force enable
log "Firewall настроен"

# Fail2ban
info "Настройка Fail2ban..."
cat > /etc/fail2ban/jail.local << 'F2B'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
F2B
systemctl enable fail2ban
systemctl restart fail2ban
log "Fail2ban настроен"

# SSH hardening
info "Усиление SSH..."
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
systemctl reload sshd
log "SSH: вход по паролю отключён"

# Docker log limits
info "Настройка лимитов Docker логов..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'DOCKERD'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  }
}
DOCKERD
systemctl reload docker
log "Лимиты логов Docker настроены"

# Cleanup cron
info "Настройка автоочистки Docker..."
cat > /etc/cron.weekly/docker-cleanup << 'CRON'
#!/bin/bash
docker system prune -f --filter "until=168h"
docker image prune -f --filter "until=168h"
CRON
chmod +x /etc/cron.weekly/docker-cleanup
log "Еженедельная очистка Docker настроена"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${GREEN}✅ Сервер успешно настроен!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Следующие шаги:"
echo ""
echo "  1. Добавьте SSH-ключ деплоера:"
echo "     echo 'ВАШ_ПУБЛИЧНЫЙ_КЛЮЧ' >> /home/$DEPLOY_USER/.ssh/authorized_keys"
echo ""
echo "  2. Добавьте GitHub Secrets:"
echo "     VPS_HOST      = $(curl -s ifconfig.me)"
echo "     VPS_USER      = $DEPLOY_USER"
echo "     VPS_SSH_KEY   = <ваш приватный ключ>"
echo ""
echo "  3. Настройте Nginx конфиг из configs/"
echo ""
echo "  4. Пушьте в main — деплой автоматический! 🎉"
echo ""
