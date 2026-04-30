#!/usr/bin/env bash
# ============================================================================
# StoryBox Clone — seed-test-data.sh
# Заливает тестовые данные в локальную БД (для разработки и smoke-тестов).
#
# Использование:
#     ./scripts/seed-test-data.sh                    # просто запустить сидеры
#     ./scripts/seed-test-data.sh --reset            # сбросить БД и пересеять
#     ./scripts/seed-test-data.sh --only=Roles       # только конкретный сидер
#     ./scripts/seed-test-data.sh --help             # показать help
#
# Что делает:
#   --reset      → migrate:fresh --seed (DROPS все таблицы!)
#   (default)    → db:seed (только новые данные, существующие через firstOrCreate)
#   --only=<X>   → db:seed --class=<X>Seeder
#
# Phase 0.9 контент:
#   • RolesAndAdminSeeder — 5 ролей + super_admin (admin@storybox.tj/password)
#   • TestUsersSeeder — content_manager / finance_manager / support / viewer
#                       + один user без роли. Все с паролем "password".
#
# Будущие сидеры (добавятся в Phase 2/4/5/6):
#   TestContentSeeder, BankProviderSeeder, IapProductSeeder
#
# Требования:
#   - Docker Desktop запущен
#   - storybox_app контейнер существует (создаётся через ./scripts/setup-dev.sh)
# ============================================================================

set -euo pipefail

# ─── Цвета ──────────────────────────────────────────────────────────────────
readonly BLUE="\033[1;34m"
readonly GREEN="\033[1;32m"
readonly YELLOW="\033[1;33m"
readonly RED="\033[1;31m"
readonly NC="\033[0m"

log()  { echo -e "${BLUE}▸${NC} $*"; }
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*" >&2; exit 1; }

# ─── Парсинг флагов ─────────────────────────────────────────────────────────
RESET=false
ONLY=""

for arg in "$@"; do
  case "$arg" in
    --reset)
      RESET=true
      ;;
    --only=*)
      ONLY="${arg#--only=}"
      ;;
    --help|-h)
      grep '^#' "$0" | sed 's/^# \{0,1\}//' | head -30
      exit 0
      ;;
    *)
      fail "Неизвестный флаг: $arg (используй --help)"
      ;;
  esac
done

# ─── Корень проекта ─────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

log "Корень проекта: $ROOT_DIR"

# ─── Проверки ───────────────────────────────────────────────────────────────
if ! command -v docker >/dev/null 2>&1; then
  fail "Docker не установлен. См. README.md."
fi

if ! docker ps --filter "name=storybox_app" --format "{{.Names}}" | grep -q storybox_app; then
  fail "Контейнер storybox_app не запущен. Запусти: docker compose up -d"
fi

# ─── Запуск ─────────────────────────────────────────────────────────────────
if [ "$RESET" = true ]; then
  warn "RESET MODE: сбрасываю БД (migrate:fresh --seed). Все данные пропадут."
  log "Прогоняю migrate:fresh + db:seed..."
  docker compose exec -T app php artisan migrate:fresh --seed --force
  ok "БД пересоздана и засеяна"

elif [ -n "$ONLY" ]; then
  CLASS="${ONLY}"
  if [[ ! "$CLASS" == *Seeder ]]; then
    CLASS="${CLASS}Seeder"
  fi
  log "Запускаю только $CLASS..."
  docker compose exec -T app php artisan db:seed --class="Database\\Seeders\\${CLASS}" --force
  ok "$CLASS выполнен"

else
  log "Запускаю db:seed (default seeders, idempotent через firstOrCreate)..."
  docker compose exec -T app php artisan db:seed --force
  ok "Сидеры выполнены"
fi

# ─── Памятка ────────────────────────────────────────────────────────────────
echo
ok "Тестовые аккаунты для входа в /admin (пароль: password):"
cat <<EOF

  ┌─────────────────────────┬─────────────────────────────────────────┐
  │ Email                   │ Роль                                    │
  ├─────────────────────────┼─────────────────────────────────────────┤
  │ admin@storybox.tj       │ super_admin (полный доступ)             │
  │ content@storybox.tj     │ content_manager (контент + переводы)    │
  │ finance@storybox.tj     │ finance_manager (биллинг + банки)       │
  │ support@storybox.tj     │ support (юзеры + ручные начисления)     │
  │ viewer@storybox.tj      │ viewer (только чтение)                  │
  │ noroles@storybox.tj     │ — (без ролей — для проверки 403)         │
  └─────────────────────────┴─────────────────────────────────────────┘

  🔑 http://localhost:8080/admin/login

EOF
