# Deployment Guide

> **Что покрывает:** ручное провижининг VPS + автоматический deploy через GitHub Actions для **staging**. Production deployment — расширение этого процесса с дополнительными гарантиями (см. секцию 6).
>
> **Связанные доки:** [`CLAUDE.md`](../CLAUDE.md), [`docs/architecture.md`](./architecture.md), [`docs/setup-monitoring.md`](./setup-monitoring.md).

---

## 1. Архитектура deploy

```
GitHub (main branch)
       │
       ├── push → backend/** ───► deploy-backend-staging.yml
       │                          ├── rsync code → VPS:/srv/storybox/
       │                          ├── docker compose build
       │                          ├── docker compose up -d
       │                          ├── artisan migrate --force
       │                          └── smoke check curl /api/v1/ping
       │
       └── push → mobile/**  ───► deploy-web-staging.yml
                                  ├── flutter build web --release
                                  ├── --base-href /storyboxtj/
                                  └── upload to GitHub Pages
                                       └── https://muboboev-doc.github.io/storyboxtj/
```

---

## 2. Flutter Web → GitHub Pages (немедленно)

GitHub Pages — **бесплатно, no setup**. Достаточно один раз включить в настройках репо.

### 2.1. Включить GitHub Pages

1. Открыть репозиторий → **Settings → Pages**.
2. **Source**: "GitHub Actions" (не "Deploy from branch").
3. Сохранить.

После этого workflow `deploy-web-staging.yml` будет триггериться на каждый push в `main` с изменениями в `mobile/**`.

### 2.2. (Опционально) задать `vars.STAGING_API_URL`

По умолчанию Flutter Web будет звонить на `https://api.example.com/api/v1/ping` — это placeholder. Чтобы указать реальный staging backend URL:

1. **Settings → Secrets and variables → Actions → Variables → New repository variable**:
   - Name: `STAGING_API_URL`
   - Value: `https://api.staging.storybox.tj` (твой реальный URL)

После этого Web-build будет hardcoded на этот URL через `--dart-define=API_BASE_URL=...`.

### 2.3. (Опционально) Sentry Web DSN

Если есть Sentry Web проект:

- **Settings → Secrets and variables → Actions → Secrets → New**:
  - Name: `SENTRY_DSN_WEB`
  - Value: твой DSN из Sentry storybox-web

### 2.4. Verify

После merge PR в `main`:

```
$ open https://muboboev-doc.github.io/storyboxtj/
```

Должна открыться `PingScreen`. Если backend ещё не задеплоен — будет красная карточка "Ping failed", но приложение само загрузится.

---

## 3. Backend → VPS (требует провижининг)

Backend (Laravel + MySQL + Redis + Filament) хостится на любом VPS с поддержкой Docker.

### 3.1. Минимальные требования к VPS

| Параметр | Минимум | Рекомендую |
|---|---|---|
| RAM | 1 GB | 2 GB (для FFmpeg-job'ов с Phase 4+) |
| CPU | 1 vCPU | 2 vCPU |
| Disk | 20 GB SSD | 40 GB SSD |
| OS | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS |
| Public IP | static IPv4 | static IPv4 + IPv6 |

**Провайдеры (от дешевого к дорогому):**
- Hetzner CX22 (~€4/мес, 4GB RAM) ← CLAUDE.md §3.3 рекомендует
- DigitalOcean Basic ($6/мес, 1GB RAM)
- Vultr High Frequency ($6/мес, 1GB RAM)
- Yandex Cloud — для российской аудитории
- Cloudflare for Saas + worker (если хочется без VPS) — фаза 2

### 3.2. Первоначальный провижининг VPS

```bash
# (1) SSH к новому VPS как root
ssh root@<vps-ip>

# (2) Создать deploy-юзера
useradd -m -s /bin/bash deploy
usermod -aG sudo deploy
mkdir -p /home/deploy/.ssh
# Залить туда public key (тот, чей private ключ положим в GitHub Secret)
nano /home/deploy/.ssh/authorized_keys
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/authorized_keys
chown -R deploy:deploy /home/deploy/.ssh

# (3) Установить Docker
curl -fsSL https://get.docker.com | sh
usermod -aG docker deploy

# (4) Создать deploy-папку
mkdir -p /srv/storybox
chown deploy:deploy /srv/storybox

# (5) Firewall (UFW)
apt install -y ufw
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# (6) Fail2ban (рекомендуется)
apt install -y fail2ban
systemctl enable --now fail2ban
```

### 3.3. SSL: Cloudflare Origin Cert (рекомендуется)

Самый простой способ — **Cloudflare** перед нашим VPS:

1. Зарегистрировать домен (например, `storybox.tj`) в любом регистраторе.
2. В Cloudflare добавить домен, перенаправить NS-записи через регистратора.
3. В Cloudflare DNS:
   - `A api.staging` → `<vps-ip>` (proxied: orange cloud)
4. **SSL/TLS → Origin Server → Create Certificate**:
   - Hostname: `*.storybox.tj`, `storybox.tj`
   - Validity: 15 years
   - Скопировать оба файла (PEM-formatted certificate + private key)
5. На VPS:
   ```bash
   cd /srv/storybox
   mkdir -p ops/ssl
   nano ops/ssl/storybox.crt    # вставить certificate
   nano ops/ssl/storybox.key    # вставить private key
   chmod 600 ops/ssl/storybox.key
   ```
6. **SSL/TLS → Overview**: режим `Full (strict)` (Cloudflare → VPS HTTPS, валидируется).

После деплоя:
- Клиент → `https://api.staging.storybox.tj` → Cloudflare TLS → VPS:443 (Origin Cert) → nginx → app:9000.

Альтернативы: Let's Encrypt (через certbot на VPS), self-signed (только staging без домена).

### 3.4. `.env` на VPS

Файл `backend/.env` НЕ rsync'ится из репо (gitignore). Создать на VPS вручную:

```bash
ssh deploy@<vps-ip>
cd /srv/storybox/backend
cp .env.example .env
nano .env
```

Минимум для запуска:

```env
APP_NAME="StoryBox Staging"
APP_ENV=staging
APP_KEY=                     # сгенерируется на первом deploy через `key:generate`
APP_DEBUG=false
APP_URL=https://api.staging.storybox.tj

LOG_CHANNEL=stack
LOG_LEVEL=info

DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=storybox
DB_USERNAME=storybox
DB_PASSWORD=<СГЕНЕРИРОВАННЫЙ_ПАРОЛЬ>

REDIS_HOST=redis
REDIS_PORT=6379

CACHE_STORE=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

# Sentry (если настроен)
SENTRY_LARAVEL_DSN=https://...@sentry.io/...
SENTRY_ENVIRONMENT=staging
SENTRY_TRACES_SAMPLE_RATE=0.5
```

Также `MYSQL_ROOT_PASSWORD` / `MYSQL_PASSWORD` берутся из top-level `.env` (рядом с `docker-compose.prod.yml`):

```bash
ssh deploy@<vps-ip>
cd /srv/storybox
cat > .env <<EOF
MYSQL_ROOT_PASSWORD=<сильный пароль>
MYSQL_DATABASE=storybox
MYSQL_USER=storybox
MYSQL_PASSWORD=<тот же пароль что в backend/.env>
DOCKER_IMAGE=storybox-app:latest
EOF
chmod 600 .env
```

### 3.5. Первый запуск (вручную)

```bash
ssh deploy@<vps-ip>
cd /srv/storybox
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml exec -T app composer install --no-dev --optimize-autoloader
docker compose -f docker-compose.prod.yml exec -T app php artisan key:generate
docker compose -f docker-compose.prod.yml exec -T app php artisan migrate --force
docker compose -f docker-compose.prod.yml exec -T app php artisan db:seed --force
docker compose -f docker-compose.prod.yml exec -T app php artisan config:cache
docker compose -f docker-compose.prod.yml exec -T app php artisan route:cache
docker compose -f docker-compose.prod.yml exec -T app php artisan view:cache
```

Проверка:

```bash
curl https://api.staging.storybox.tj/api/v1/ping
# → {"status":"ok",...}

curl -I https://api.staging.storybox.tj/admin/login
# → HTTP/2 200
```

### 3.6. Настройка GitHub Secrets для авто-деплоя

После того как ручной запуск работает — настроим автоматический deploy.

В **GitHub → Settings → Secrets and variables → Actions → Secrets**:

| Secret | Value |
|---|---|
| `STAGING_SSH_HOST` | `<vps-ip>` или `vps.storybox.tj` |
| `STAGING_SSH_USER` | `deploy` |
| `STAGING_SSH_KEY` | приватный SSH-ключ (тот, чей public в `~deploy/.ssh/authorized_keys`) |
| `STAGING_SSH_PORT` | `22` (или другой если изменён) |
| `STAGING_DEPLOY_PATH` | `/srv/storybox` |

В **Variables**:

| Variable | Value |
|---|---|
| `STAGING_API_URL` | `https://api.staging.storybox.tj` |

После этого каждый push в `main` с изменениями `backend/**` будет автоматически деплоиться. Workflow `deploy-backend-staging.yml` пропускает deploy если хотя бы один из `STAGING_SSH_*` секретов отсутствует (graceful — для свежего форка / contributor'а).

---

## 4. Demo Friday: чек-лист

После настройки:

- [ ] `https://muboboev-doc.github.io/storyboxtj/` открывается, видна `PingScreen`
- [ ] Тапаем "Ping API" → зелёная карточка с реальными данными от backend
- [ ] `https://api.staging.storybox.tj/admin/login` показывает Filament login
- [ ] Логин `admin@storybox.tj` / `password` (после `db:seed`) → Dashboard
- [ ] Sentry получает test-event через `php artisan sentry:test`
- [ ] Скриншот рабочего приложения добавлен в `README.md` или Slack/Discord канал команды

---

## 5. Откат (rollback)

Если новый deploy сломал staging:

```bash
ssh deploy@<vps-ip>
cd /srv/storybox

# Вариант 1: вернуть предыдущий коммит на VPS
git log --oneline -5      # найти SHA предыдущего рабочего deploy
git checkout <previous-sha>
docker compose -f docker-compose.prod.yml up -d --build

# Вариант 2: revert PR в main → автоматический deploy откатит код
```

Backups:
- MySQL: ежедневный snapshot через `ops/mysql/backups/` (cron на хосте)
- App images: Docker tag`storybox-app:<commit-sha>` сохраняется на VPS (3 последних)

---

## 6. Production deploy (отличия от staging)

После того как staging стабилен и команда довольна:

1. **Отдельный VPS** для prod (не тот же что staging)
2. **Отдельный домен** (`storybox.tj` без префикса `staging`)
3. **Отдельный workflow** `.github/workflows/deploy-backend-prod.yml`:
   - Триггер: только tag `v*.*.*`
   - Manual approval через GitHub Environments → `production`
   - Healthchecks с rollback при failure
4. **Backups**: snapshot перед каждым deploy + долгосрочное хранение в S3
5. **Sentry release tracking** через `getsentry/action-release`
6. **Slack/Telegram** уведомления о deploy

Шаблон будет добавлен в Phase 12 (Release Prep).

---

## 7. Troubleshooting

| Проблема | Решение |
|---|---|
| `502 Bad Gateway` после deploy | `docker compose logs app` — обычно migrate упал. Проверить `.env`. |
| Filament login → 500 | `php artisan view:clear && view:cache` — кэш Blade битый |
| `connection refused` от curl | UFW заблокировал 80/443. `ufw status verbose` |
| Cloudflare показывает 521 | Origin не отвечает. SSL termination проблема. Переключить на `Flexible` для отладки. |
| MySQL не стартует | Проверить пароль в обоих `.env` (root + storybox). `docker compose logs mysql`. |
| GitHub Pages 404 | Settings → Pages → Source = "GitHub Actions" (не "Deploy from branch") |

---

## 8. Что не покрывает этот doc

- CI/CD для production (deploy-backend-prod.yml) — Phase 12
- Auto-scaling / Kubernetes — out of scope для MVP
- CDN для видео-контента (BunnyCDN / Cloudflare Stream) — Phase 8 (DRM)
- Database replication / read replicas — после ~10K MAU
- Multi-region — фаза 2+
