# StoryBox Clone

OTT-приложение коротких вертикальных драм и веб-сериалов (аналог StoryBox / ReelShort / DramaBox) для Таджикистана и СНГ.

[![backend-ci](https://github.com/muboboev-doc/storyboxtj/actions/workflows/backend-ci.yml/badge.svg)](https://github.com/muboboev-doc/storyboxtj/actions/workflows/backend-ci.yml)
[![mobile-ci](https://github.com/muboboev-doc/storyboxtj/actions/workflows/mobile-ci.yml/badge.svg)](https://github.com/muboboev-doc/storyboxtj/actions/workflows/mobile-ci.yml)
[![secrets-scan](https://github.com/muboboev-doc/storyboxtj/actions/workflows/secrets-scan.yml/badge.svg)](https://github.com/muboboev-doc/storyboxtj/actions/workflows/secrets-scan.yml)
[![deploy-web-staging](https://github.com/muboboev-doc/storyboxtj/actions/workflows/deploy-web-staging.yml/badge.svg)](https://github.com/muboboev-doc/storyboxtj/actions/workflows/deploy-web-staging.yml)

🌐 **Live demo (staging Web):** [muboboev-doc.github.io/storyboxtj](https://muboboev-doc.github.io/storyboxtj/) (обновляется при каждом merge в main)

> ⚠️ **Этот репозиторий — основной источник правды только в связке с [`CLAUDE.md`](./CLAUDE.md)**.
> Перед любым контрибьютом / новой Claude-сессией прочитай его целиком — там conventions, security rules, roadmap.

---

## Что это

- **Платформы:** Android, iOS, Web (PWA), Admin Panel
- **Стек:** Flutter 3.41 (клиент) + Laravel 11 / PHP 8.2 (бэкенд + Filament admin)
- **Регион:** Таджикистан + русскоязычная аудитория СНГ
- **Контент:** короткие вертикальные эпизоды 60-120 сек; первые 3-5 бесплатные, остальные — за коины / VIP / просмотр рекламы
- **Платежи:** Google Play Billing + Apple StoreKit (международная аудитория) + локальные банки Таджикистана (Алиф, Эсхата, ДС Банк)
- **Защита контента:** Widevine + FairPlay DRM, AES-128 HLS, signed URLs, FLAG_SECURE, watermark

Полная спецификация — [`docs/tz.md`](./docs/tz.md). Архитектурный обзор — [`docs/architecture.md`](./docs/architecture.md). Deploy на staging — [`docs/deploy.md`](./docs/deploy.md). Sentry + Firebase setup — [`docs/setup-monitoring.md`](./docs/setup-monitoring.md).

---

## Быстрый старт

### Требования

| | Версия | Зачем |
|---|---|---|
| Docker Desktop | последняя | поднимает backend стек (PHP, MySQL, Redis, nginx, mailhog) |
| Flutter SDK | 3.41+ | mobile / web клиент |
| Git | 2.40+ | работа с репозиторием |
| Android Studio | опционально | для Android-сборок и эмулятора |

### Первый запуск

```bash
git clone https://github.com/muboboev-doc/storyboxtj.git
cd storyboxtj
./scripts/setup-dev.sh
```

Скрипт:
1. Поднимает `docker-compose` (5 сервисов: app, nginx, mysql, redis, mailhog).
2. Устанавливает composer-зависимости в `backend/`.
3. Генерирует `APP_KEY` и прогоняет миграции.
4. Устанавливает Flutter-зависимости в `mobile/` (если есть Flutter в PATH).
5. Печатает URL'ы доступа.

После этого:

```bash
# Backend smoke check
curl http://localhost:8080/api/v1/ping
# {"status":"ok","service":"StoryBox","version":"0.0.1",...}

# Mobile (Web flavor через Chrome)
cd mobile
flutter run --target lib/main_dev.dart -d chrome
```

### URL'ы локально

| Сервис | URL |
|---|---|
| Backend API | http://localhost:8080 |
| Filament Admin | http://localhost:8080/admin |
| Mailhog UI | http://localhost:8025 |
| MySQL | `localhost:3306` (storybox / storybox) |
| Redis | `localhost:6380` (внутри сети — `redis:6379`) |

### Тестовые аккаунты (после `setup-dev.sh` или `seed-test-data.sh`)

Все с паролем **`password`**:

| Email | Роль |
|---|---|
| `admin@storybox.tj` | super_admin |
| `content@storybox.tj` | content_manager |
| `finance@storybox.tj` | finance_manager |
| `support@storybox.tj` | support |
| `viewer@storybox.tj` | viewer (read-only) |
| `noroles@storybox.tj` | — (для проверки 403) |

### Сброс тестовых данных

```bash
./scripts/seed-test-data.sh           # просто прогнать сидеры (idempotent)
./scripts/seed-test-data.sh --reset   # migrate:fresh + db:seed (DROP всех данных!)
./scripts/seed-test-data.sh --only=TestUsers   # один сидер
```

---

## Структура репозитория

```
storyboxtj/
├── CLAUDE.md                    ← главный контекст-файл (читать первым!)
├── README.md                    ← этот файл
├── docker-compose.yml           ← локальное окружение разработки
├── scripts/
│   └── setup-dev.sh             ← bootstrap-скрипт
├── backend/                     ← Laravel 11 API + Filament admin
│   ├── app/                     # контроллеры, модели, сервисы
│   ├── routes/api.php           # /api/v1/* endpoints
│   ├── tests/                   # Pest 3 (Feature + Unit)
│   ├── phpstan.neon             # Larastan уровень 6
│   ├── composer.json
│   └── Dockerfile               # multi-stage PHP 8.2-fpm + ffmpeg
├── mobile/                      ← Flutter 3.41 (Android / iOS / Web)
│   ├── lib/
│   │   ├── flavors.dart         # dev / prod / appstore конфиги
│   │   ├── main_dev.dart        # точка входа DEV
│   │   ├── main_prod.dart       # точка входа PROD
│   │   ├── main_appstore.dart   # точка входа Apple App Store (Reader-app pattern)
│   │   ├── app.dart             # MaterialApp + theming
│   │   └── screens/             # экраны (UI)
│   ├── analysis_options.yaml    # very_good_analysis preset
│   └── pubspec.yaml
├── ops/
│   └── nginx/default.conf       # reverse proxy к app:9000
├── docs/
│   ├── tz.md                    ← полное ТЗ v1.2 (источник правды)
│   ├── architecture.md          ← архитектурный обзор + диаграммы
│   └── decisions/               ← ADR (Architecture Decision Records)
│       └── 0001-roadmap-v1-vs-v2.md
├── prompts/                     ← отлаженные промпты для Claude Code
│   ├── add-bank-driver.md       # как добавить новый банк (Strategy pattern)
│   ├── write-feature-test.md    # шаблон Pest feature-теста
│   └── translate-arb.md         # как добавить локализованную строку
└── .github/workflows/
    ├── backend-ci.yml           # Pint + PHPStan + Pest
    ├── mobile-ci.yml            # dart format + analyze + test
    └── secrets-scan.yml         # gitleaks
```

---

## Команды разработки

Полный список — [`CLAUDE.md` §15](./CLAUDE.md#15-стандартные-команды-разработки).

### Backend (внутри docker)

```bash
docker compose up -d                                    # поднять стек
docker compose exec app composer ci                     # lint + analyse + test (полный CI локально)
docker compose exec app composer lint:fix               # авто-фикс стиля (Pint)
docker compose exec app composer test                   # только тесты (Pest)
docker compose exec app php artisan migrate             # применить миграции
docker compose exec app php artisan tinker              # REPL
```

### Mobile

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run --target lib/main_dev.dart -d chrome        # запуск в Chrome
flutter build web --target lib/main_dev.dart            # сборка Web
flutter build apk --flavor prod                         # Android APK (после Android SDK)
```

---

## Roadmap

Проект идёт по этапам, описанным в [`CLAUDE.md` §17](./CLAUDE.md#17-подробный-план-разработки-roadmap-vibe-coding-оптимизированный). Текущее состояние:

- ✅ **Phase 0.1** — bootstrap репозитория
- ✅ **Phase 0.2** — Docker + Laravel 11 + `/api/v1/ping`
- ✅ **Phase 0.3** — Flutter app + 3 flavors + ping screen
- ✅ **Phase 0.4** — GitHub Actions CI (3 workflows зелёные)
- ✅ **Phase 0.5** — OpenAPI spec + type-safe Dart client
- ✅ **Phase 0.6** — Sentry + Firebase baseline (graceful no-op)
- ✅ **Phase 0.7** — README + architecture + 3 prompt templates
- ✅ **Phase 0.8** — Filament 3 + Spatie Permission + super_admin
- ✅ **Phase 0.9** — `seed-test-data.sh` + TestUsersSeeder
- ✅ **Phase 0.10** — Demo Friday: Web → GitHub Pages, Backend → VPS template
- ⏳ **Phase 1+** — vertical slices (Auth → Content → Wallet → IAP → Banks → Anti-piracy)

**Walking Skeleton complete!** Next: Phase 1 Auth Vertical Slice.

Целевой срок MVP — ~14 недель vibe-coding оптимизированно. См. [ADR-0001](./docs/decisions/0001-roadmap-v1-vs-v2.md) — почему v2 быстрее v1.

---

## Contributing

1. Прочитать [`CLAUDE.md`](./CLAUDE.md) целиком.
2. Создать ветку: `feat/<area>-<short>` от `main`.
3. Один логический change на PR, ≤ 400 строк дифа.
4. Conventional Commits: `feat:`, `fix:`, `chore:`, `refactor:`, `test:`, `docs:`.
5. **Ни в коем случае** не модифицировать `app/Services/Wallet/`, `app/Services/Banks/`, `app/Services/Drm/` без полного TDD-цикла (см. [`CLAUDE.md` §7](./CLAUDE.md#7-критические-запреты-deal-breakers)).
6. CI должен быть зелёный перед merge.
7. Squash merge в `main` (линейная история).

---

## Лицензия

Private. Все права принадлежат владельцу проекта.

---

**Дата последнего обновления:** 30 апреля 2026.
