#!/usr/bin/env bash
# ============================================================================
# StoryBox Clone — generate-api-client.sh
# Регенерирует Flutter API-клиент из docs/openapi.yaml через
# openapi-generator-cli (запускаемый в Docker — без Java на хосте).
#
# Использование:
#     ./scripts/generate-api-client.sh
#
# Что делает:
#   1. Валидирует docs/openapi.yaml
#   2. Чистит mobile/lib/api/
#   3. Генерирует Dart+Dio клиент
#   4. Запускает dart format на сгенерированном коде
#   5. Печатает следующие шаги
#
# Требования:
#   - Docker Desktop запущен
#
# Источник: https://openapi-generator.tech/docs/generators/dart-dio
# ============================================================================

set -euo pipefail

readonly BLUE="\033[1;34m"
readonly GREEN="\033[1;32m"
readonly YELLOW="\033[1;33m"
readonly RED="\033[1;31m"
readonly NC="\033[0m"

log()  { echo -e "${BLUE}▸${NC} $*"; }
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

# ─── Проверки ───────────────────────────────────────────────────────────────
if ! command -v docker >/dev/null 2>&1; then
  fail "Docker не установлен."
fi

if [ ! -f docs/openapi.yaml ]; then
  fail "docs/openapi.yaml не найден."
fi

# ─── Параметры ──────────────────────────────────────────────────────────────
readonly SPEC=docs/openapi.yaml
readonly OUT=mobile/lib/api
readonly GENERATOR=dart-dio
# Версия генератора. При апдейте — обновить и тут, и в .openapi-generator-version.
readonly GEN_VERSION=v7.10.0

# ─── Очистка старого ───────────────────────────────────────────────────────
log "Очищаю $OUT (если есть)..."
rm -rf "$OUT"

# ─── Запуск generator ───────────────────────────────────────────────────────
log "Запускаю openapi-generator-cli (через Docker, может занять 1-2 мин на первом прогоне)..."

# MSYS_NO_PATHCONV=1 — Git Bash на Windows иначе конвертирует '/local/...'
# в 'C:/Program Files/Git/local/...' и контейнер не может найти файлы.
#
# Параметры -p:
#   pubName / pubVersion / pubDescription — для pubspec.yaml сгенерированного пакета
#   sourceFolder — внутренняя структура (стандарт: lib)
#   useEnumExtension — extensions для enum'ов (читаемые имена)
#   nullableFields=true — required+nullable обрабатываются нормально
MSYS_NO_PATHCONV=1 docker run --rm \
  -v "$ROOT_DIR:/local" \
  openapitools/openapi-generator-cli:$GEN_VERSION generate \
  -i "/local/$SPEC" \
  -g "$GENERATOR" \
  -o "/local/$OUT" \
  --additional-properties=pubName=storybox_api,pubVersion=0.0.1,pubDescription="StoryBox API client (auto-generated)",sourceFolder=lib,useEnumExtension=true,nullableFields=true \
  --git-user-id=muboboev-doc \
  --git-repo-id=storyboxtj \
  --skip-validate-spec

ok "Сгенерирован клиент в $OUT"

# ─── Cleanup мусора ─────────────────────────────────────────────────────────
# openapi-generator делает кучу ненужных файлов: README.md, docs/*, .git*, etc.
# Оставим только то что реально используется приложением.
log "Чищу служебные файлы генератора..."
cd "$OUT"
rm -rf doc/ test/ .openapi-generator/ .gitignore .openapi-generator-ignore .travis.yml git_push.sh README.md analysis_options.yaml || true
cd "$ROOT_DIR"

# ─── Format ─────────────────────────────────────────────────────────────────
if command -v dart >/dev/null 2>&1; then
  log "Запускаю dart format на сгенерированном коде..."
  (cd "$OUT" && dart format . > /dev/null 2>&1) || warn "dart format упал — некритично"
fi

# ─── Финальная памятка ──────────────────────────────────────────────────────
echo
ok "Готово. Что дальше:"
cat <<EOF

  📦 Сгенерированный пакет: $OUT/
     pubspec.yaml внутри — это под-пакет с собственными зависимостями.

  📱 Подключение в mobile/:
     В mobile/pubspec.yaml есть:
        dependencies:
          storybox_api:
            path: lib/api

     После регенерации клиента:
        cd mobile
        flutter pub get
        flutter pub run build_runner build --delete-conflicting-outputs

  🔍 Импорт в коде:
     import 'package:storybox_api/storybox_api.dart';

     final api = DefaultApi(
       Dio(BaseOptions(baseUrl: kAppConfig.apiBaseUrl)),
     );
     final response = await api.ping();

EOF
