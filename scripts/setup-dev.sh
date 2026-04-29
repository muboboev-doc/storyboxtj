#!/usr/bin/env bash
# ============================================================================
# StoryBox Clone — setup-dev.sh
# Поднимает локальное окружение разработки одной командой.
#
# Использование:
#     ./scripts/setup-dev.sh [--skip-docker] [--skip-flutter] [--seed-only]
#
# Что делает:
#   1) Проверяет зависимости (docker, flutter, git).
#   2) Создаёт .env из .env.example, если нужно.
#   3) Поднимает docker compose (mysql, redis, app, nginx, mailhog).
#   4) Устанавливает PHP-зависимости (composer install).
#   5) Запускает миграции и сидеры (artisan migrate --seed).
#   6) Устанавливает Flutter-зависимости (flutter pub get) + codegen.
#   7) Печатает URL'ы доступа и логины.
#
# Зависимости (на хосте):
#   - Docker Desktop + Docker Compose v2
#   - Flutter SDK 3.22+ (опционально, можно через --skip-flutter)
#   - git
# ============================================================================

set -euo pipefail

# ─── Цвета ──────────────────────────────────────────────────────────────────
readonly BLUE="\033[1;34m"
readonly GREEN="\033[1;32m"
readonly YELLOW="\033[1;33m"
readonly RED="\033[1;31m"
readonly NC="\033[0m"

log()    { echo -e "${BLUE}▸${NC} $*"; }
ok()     { echo -e "${GREEN}✓${NC} $*"; }
warn()   { echo -e "${YELLOW}⚠${NC} $*"; }
fail()   { echo -e "${RED}✗${NC} $*" >&2; exit 1; }

# ─── Парсинг флагов ─────────────────────────────────────────────────────────
SKIP_DOCKER=false
SKIP_FLUTTER=false
SEED_ONLY=false

for arg in "$@"; do
  case $arg in
    --skip-docker)  SKIP_DOCKER=true ;;
    --skip-flutter) SKIP_FLUTTER=true ;;
    --seed-only)    SEED_ONLY=true ;;
    --help|-h)
      grep '^#' "$0" | sed 's/^# \{0,1\}//' | head -25
      exit 0
      ;;
    *) fail "Неизвестный флаг: $arg (используй --help)" ;;
  esac
done

# ─── Корень проекта ─────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

log "Корень проекта: $ROOT_DIR"

# ─── Проверка зависимостей ──────────────────────────────────────────────────
check_dep() {
  local cmd="$1"
  local hint="${2:-}"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "Не найдена команда: $cmd${hint:+. $hint}"
  fi
  ok "$cmd установлен"
}

log "Проверяю зависимости..."
check_dep git "Установи: https://git-scm.com/"

if [ "$SKIP_DOCKER" = false ] && [ "$SEED_ONLY" = false ]; then
  check_dep docker "Установи Docker Desktop: https://docker.com/"
  if ! docker compose version >/dev/null 2>&1; then
    fail "Docker Compose v2 не установлен."
  fi
  ok "docker compose доступен"
fi

if [ "$SKIP_FLUTTER" = false ] && [ "$SEED_ONLY" = false ]; then
  if command -v flutter >/dev/null 2>&1; then
    ok "flutter установлен ($(flutter --version | head -1))"
  else
    warn "Flutter не найден — пропущу шаги mobile/ (используй --skip-flutter чтобы убрать предупреждение)"
    SKIP_FLUTTER=true
  fi
fi

# ─── 1. .env ────────────────────────────────────────────────────────────────
if [ "$SEED_ONLY" = false ]; then
  if [ -d "backend" ] && [ ! -f "backend/.env" ]; then
    if [ -f "backend/.env.example" ]; then
      cp backend/.env.example backend/.env
      ok "Создал backend/.env из примера"
    else
      warn "backend/.env.example отсутствует — пропущу"
    fi
  fi
fi

# ─── 2. Docker compose up ───────────────────────────────────────────────────
if [ "$SKIP_DOCKER" = false ] && [ "$SEED_ONLY" = false ]; then
  if [ -f "docker-compose.yml" ]; then
    log "Поднимаю docker-compose..."
    docker compose up -d
    ok "Контейнеры запущены"

    log "Жду готовности MySQL (до 60 сек)..."
    timeout=60
    while [ $timeout -gt 0 ]; do
      if docker compose exec -T mysql mysqladmin ping -uroot -proot >/dev/null 2>&1; then
        ok "MySQL готов"
        break
      fi
      sleep 2
      timeout=$((timeout - 2))
    done
    [ $timeout -le 0 ] && warn "MySQL не отвечает — продолжаю всё равно"
  else
    warn "docker-compose.yml ещё не создан — этап 0.2 в roadmap"
  fi
fi

# ─── 3. Composer install + миграции ─────────────────────────────────────────
if [ "$SKIP_DOCKER" = false ] && [ -f "backend/composer.json" ]; then
  log "Устанавливаю composer-зависимости..."
  docker compose exec -T app composer install --no-interaction --prefer-dist
  ok "composer install готово"

  if [ "$SEED_ONLY" = false ]; then
    log "Генерирую APP_KEY (если нужно)..."
    docker compose exec -T app php artisan key:generate --ansi || true
  fi

  log "Запускаю миграции и сидеры..."
  docker compose exec -T app php artisan migrate:fresh --seed --force
  ok "БД готова с тестовыми данными"
fi

# ─── 4. Flutter ─────────────────────────────────────────────────────────────
if [ "$SKIP_FLUTTER" = false ] && [ "$SEED_ONLY" = false ] && [ -f "mobile/pubspec.yaml" ]; then
  log "Устанавливаю Flutter-зависимости..."
  (cd mobile && flutter pub get)
  ok "flutter pub get готово"

  log "Запускаю build_runner для codegen..."
  (cd mobile && flutter pub run build_runner build --delete-conflicting-outputs) || warn "codegen упал — это ок, если build_runner ещё не настроен"

  log "Генерирую локализацию..."
  (cd mobile && flutter gen-l10n) || warn "gen-l10n упал — это ок, если ARB ещё не настроены"
fi

# ─── 5. Финальная памятка ───────────────────────────────────────────────────
echo
ok "Готово. Что дальше:"
cat <<EOF

  📚 Документы:
     CLAUDE.md                     — главный контекст проекта
     docs/tz.md                    — полное ТЗ
     docs/decisions/               — ADR

  🔌 Сервисы (если docker compose поднят):
     Backend API:    http://localhost:8080
     API ping:       curl http://localhost:8080/api/v1/ping
     Filament Admin: http://localhost:8080/admin   (логин: admin@storybox.tj / password — после фазы 1+)
     Mailhog UI:     http://localhost:8025
     MySQL:          localhost:3306 (storybox / storybox)
     Redis:          localhost:6380   (внутри docker-сети — redis:6379)

  📱 Mobile:
     cd mobile
     flutter run --flavor dev -t lib/main.dart

  🚦 Запуск тестов:
     docker compose exec app composer test     # backend
     cd mobile && flutter test                 # mobile

  💬 Если что-то не запустилось — см. CLAUDE.md раздел 18 (FAQ).

EOF
