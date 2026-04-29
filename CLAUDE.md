# CLAUDE.md — StoryBox Clone (OTT короткие драмы)

**Это главный контекст-файл для Claude Code. Читай его в начале каждой сессии. Не дублируй его содержимое в промпты — ссылайся на разделы.**

Полное техническое задание лежит в [`docs/tz.md`](./docs/tz.md). Этот файл — компактная навигация по проекту, договорённости и пошаговый план реализации.

---

## 1. О проекте

**StoryBox Clone** — OTT-приложение коротких вертикальных драм и веб-сериалов (аналог StoryBox / ReelShort / DramaBox). Эпизоды по 60–120 секунд, первые 3–5 бесплатные, остальные разблокируются за коины / VIP / просмотр рекламы.

**Платформы:** Android, iOS, Web (PWA), Admin Panel (Filament).
**Стек:** Flutter (клиент) + Laravel 11 / PHP 8.2 (бэкенд + админка).
**Регион:** Таджикистан + СНГ (русскоязычная аудитория).
**Команда:** один разработчик + Claude Code.

**Уникальные требования:**

- Локальные платежи Таджикистана: **Алиф Банк, Эсхата Банк, Душанбе Сити Банк** (Strategy pattern, см. раздел 10).
- Apple IAP / Google Play Billing для международной аудитории.
- 6 языков: ru, en, tg, uz, kk, ky.
- DRM (Widevine + FairPlay) + AES-128 + signed URLs обязательны.
- Запрет скриншотов (FLAG_SECURE) и записи экрана (UIScreen.capturedDidChangeNotification).
- Watermark поверх плеера с user_id.
- Reader-app паттерн на iOS App Store билде (скрытие локальных банков из-за Guideline 3.1.1).

**Стадия:** разработка с нуля. Целевой срок MVP — 5.5 месяцев (23–25 недель) для команды 1+0.5+0.5; ужимаемо до 16–17 недель параллельной работой.

---

## 2. Архитектура (cheat-sheet)

```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  Flutter Mobile │  │  Flutter Web /  │  │  Filament Admin │
│  (Android/iOS)  │  │     PWA         │  │     Panel       │
└────────┬────────┘  └────────┬────────┘  └────────┬────────┘
         │                    │                    │
         └────────────────────┼────────────────────┘
                              │ HTTPS / REST
                              ▼
                  ┌──────────────────────────┐
                  │   Laravel API (nginx)    │
                  │   Sanctum Auth           │
                  │   License Proxy (DRM)    │
                  │   Payment Orchestrator   │
                  └─┬───────┬──────┬─────┬───┘
                    │       │      │     │
       ┌────────────┘       │      │     └─────────────┐
       ▼                    │      │                   ▼
  ┌─────────┐               │      │           ┌──────────────┐
  │ MySQL 8 │               │      │           │  Bank APIs   │
  │ + Redis │               │      │           │ Alif/Eskhata │
  └─────────┘               │      │           │   /DCBank    │
                            ▼      ▼           └──────────────┘
                  ┌────────────┐  ┌─────────┐
                  │ S3/DO/Loc  │  │  CDN    │
                  │ HLS+AES-128│  │HLS HDCP │
                  └────────────┘  └─────────┘
                       ▲
                       │
                  ┌────┴────────┐
                  │  FFmpeg     │
                  │ Worker      │
                  └─────────────┘
```

**API маршруты разделены:**
- `/api/v1/*` — мобильный API (Sanctum-токен)
- `/admin/*` — Filament (web-сессия + Spatie Permission)
- `/license/*` — DRM-прокси (Widevine/FairPlay), сверка по signed token
- `/webhooks/bank/*` — server-to-server callbacks от банков (HMAC + IP whitelist)
- `/payments/*` — payment orchestrator

Полная диаграмма потоков и описание см. в `docs/tz.md` раздел 4.

---

## 3. Технологический стек

### 3.1. Backend

| Слой | Выбор | Назначение |
|---|---|---|
| Язык | PHP 8.2+ | Современные features (readonly, enums, FFI) |
| Фреймворк | Laravel 11.x | API, очереди, миграции, тесты |
| БД | MySQL 8.0 | Основное хранилище |
| Кэш / очереди | Redis 7 | Кэш, очереди (Horizon), rate limit, idempotency keys |
| Auth | Laravel Sanctum | Токены для мобильного API |
| Очереди | Laravel Horizon | UI для очередей, метрики |
| Админка | Filament 3.x | CRUD, роли (Spatie Permission), translatable (Spatie Translatable) |
| Транскодинг | FFmpeg + `php-ffmpeg` | HLS 240/480/720p + AES-128 |
| HTTP | Guzzle 7 | Запросы к банкам, IAP-верификация |
| DRM | Widevine modular + FairPlay key server | License proxy |
| Тесты | Pest 3 | Unit + Feature, snapshot |
| Линтер | Laravel Pint | PSR-12, авто-форматирование |
| Static analysis | PHPStan level 8 + Larastan | Типы, dead code |

### 3.2. Mobile / Web (Flutter)

| Слой | Выбор | Назначение |
|---|---|---|
| SDK | Flutter 3.22+, Dart 3.x | Один кодовая база Android/iOS/Web |
| State | Riverpod 2.x | DI, async, immutable state |
| Routing | go_router | Decl. routing + deep links |
| HTTP | dio + retrofit | Type-safe API клиент |
| Хранилище | hive + shared_preferences + flutter_secure_storage | Кэш, токены, секреты |
| Видео | better_player (HLS+DRM), video_player (fallback) | Вертикальный плеер |
| IAP | in_app_purchase 3.x | Google Play Billing v6, StoreKit 2 |
| WebView | flutter_inappwebview | Bank checkout, OAuth flows |
| Deep links | app_links | `storybox://payment/return` |
| Push | firebase_messaging | Уведомления |
| Ads | google_mobile_ads | Rewarded |
| Локализация | flutter_localizations + intl, ARB | 6 языков |
| QR | qr_flutter | Генерация QR для bank QR-оплаты |
| Анти-скрин | flutter_windowmanager (Android), нативные каналы (iOS) | FLAG_SECURE, UIScreen наблюдатели |
| Безопасность | dio_certificate_pinning, flutter_jailbreak_detection | SSL pinning, root detect |
| Аналитика | firebase_analytics | Events, funnels |
| Тесты | flutter_test, integration_test, mocktail | Unit, widget, E2E |
| Линтер | dart_code_metrics, very_good_analysis | Стиль, метрики сложности |

### 3.3. Инфраструктура

| Компонент | Выбор |
|---|---|
| Контейнеризация | Docker + docker-compose |
| Оркестрация (prod) | Docker Compose на VPS либо k8s (фаза 2) |
| Web-сервер | nginx + php-fpm |
| Process manager | supervisor (Horizon, FFmpeg worker) |
| Хранилище | AWS S3 / DigitalOcean Spaces / локальный диск (через Laravel Filesystem) |
| CDN | CloudFront / Cloudflare Stream / BunnyCDN |
| Errors | Sentry (PHP + Flutter) |
| APM | Laravel Pulse |
| Push backend | Firebase Cloud Messaging |
| Auth providers | Google, Apple, Facebook через Socialite |
| OTP | Telegram-бот основной + SMS fallback (Osonsms / iSMS) |
| CI | GitHub Actions |
| Mobile build | Codemagic / EAS-аналог: Flutter с GitHub Actions + Fastlane |
| DRM key server | self-hosted Laravel endpoint |
| Secrets | Laravel `.env` + `Crypt::encryptString` для банковских ключей в БД |

---

## 4. Структура монорепо

```
storybox-clone/
├── CLAUDE.md                              ← этот файл
├── README.md
├── docker-compose.yml
├── docker-compose.prod.yml
├── .env.example
├── .gitignore
├── .editorconfig
├── docs/
│   ├── tz.md                              ← полное ТЗ v1.2 (источник правды)
│   ├── architecture.md                    ← диаграммы, ADR
│   ├── api.md                             ← OpenAPI spec (auto-gen)
│   ├── runbooks/                          ← инцидент-плейбуки
│   │   ├── bank-webhook-down.md
│   │   ├── ffmpeg-queue-stuck.md
│   │   └── drm-license-failure.md
│   └── decisions/                         ← ADR (Architecture Decision Records)
│       ├── 0001-flutter-vs-react-native.md
│       ├── 0002-laravel-vs-nestjs.md
│       └── 0003-strategy-pattern-banks.md
├── prompts/                               ← каталог отлаженных промптов для Claude
│   ├── add-bank-driver.md
│   ├── add-language.md
│   ├── add-iap-product.md
│   ├── debug-drm.md
│   ├── write-feature-test.md
│   └── reconciliation-check.md
├── scripts/
│   ├── setup-dev.sh                       ← поднимает локально
│   ├── seed-test-data.sh                  ← фикстуры для smoke
│   └── deploy.sh
├── .github/
│   └── workflows/
│       ├── backend-ci.yml
│       ├── mobile-ci.yml
│       ├── web-ci.yml
│       └── security.yml
├── backend/                               # Laravel 11
│   ├── app/
│   │   ├── Console/Commands/
│   │   │   ├── BanksReconcile.php
│   │   │   ├── EpisodeRotateKeys.php
│   │   │   └── DailyAnalyticsAggregate.php
│   │   ├── Filament/
│   │   │   ├── Resources/                 ← UserResource, SeriesResource,
│   │   │   │                                EpisodeResource, IapProductResource,
│   │   │   │                                BankProviderResource, BankTransactionResource,
│   │   │   │                                и т.д.
│   │   │   ├── Pages/                     ← Dashboard, Reconciliation, Translations
│   │   │   └── Widgets/                   ← виджеты статистики, очередей
│   │   ├── Http/
│   │   │   ├── Controllers/
│   │   │   │   ├── Api/V1/                ← AuthController, HomeController,
│   │   │   │   │                            EpisodeController, WalletController,
│   │   │   │   │                            IapController, PaymentBankController,
│   │   │   │   │                            VipController, AdsController, и т.д.
│   │   │   │   ├── License/               ← WidevineProxy, FairPlayProxy
│   │   │   │   └── Webhooks/
│   │   │   │       └── Banks/
│   │   │   │           ├── AlifWebhookController.php
│   │   │   │           ├── EskhataWebhookController.php
│   │   │   │           └── DcbankWebhookController.php
│   │   │   ├── Middleware/
│   │   │   │   ├── BankWebhookIpWhitelist.php
│   │   │   │   ├── EnforceIdempotency.php
│   │   │   │   └── LogStreamAccess.php
│   │   │   ├── Requests/                  ← FormRequest классы
│   │   │   └── Resources/                 ← API Resource классы
│   │   ├── Jobs/
│   │   │   ├── TranscodeEpisode.php
│   │   │   ├── EncryptHlsSegments.php
│   │   │   ├── ReconcileBankTransactions.php
│   │   │   ├── SendPushNotification.php
│   │   │   └── VerifyIapPurchase.php
│   │   ├── Models/                        ← User, Wallet, Series, Episode,
│   │   │                                    BankPaymentProvider, BankTransaction, и т.д.
│   │   ├── Services/
│   │   │   ├── Auth/
│   │   │   │   ├── OtpSenderInterface.php
│   │   │   │   ├── TelegramOtpSender.php
│   │   │   │   └── SmsOtpSender.php
│   │   │   ├── IapVerifier/
│   │   │   │   ├── IapVerifierInterface.php
│   │   │   │   ├── GoogleIapVerifier.php
│   │   │   │   └── AppleIapVerifier.php
│   │   │   ├── Banks/
│   │   │   │   ├── BankPaymentInterface.php
│   │   │   │   ├── BankPaymentManager.php
│   │   │   │   ├── WebhookProcessor.php
│   │   │   │   ├── Drivers/
│   │   │   │   │   ├── AlifBankDriver.php
│   │   │   │   │   ├── EskhataBankDriver.php
│   │   │   │   │   └── DushanbeCityBankDriver.php
│   │   │   │   └── DTOs/
│   │   │   │       ├── PaymentInitRequest.php
│   │   │   │       ├── PaymentInitResponse.php
│   │   │   │       ├── WebhookPayload.php
│   │   │   │       └── ReconciliationItem.php
│   │   │   ├── Wallet/
│   │   │   │   ├── WalletService.php       ← credit, debit, transfer
│   │   │   │   └── EpisodeUnlockService.php
│   │   │   ├── Drm/
│   │   │   │   ├── DrmKeyService.php
│   │   │   │   ├── SignedUrlService.php
│   │   │   │   └── LicenseProxyService.php
│   │   │   ├── Streaming/
│   │   │   │   └── StreamAccessLogger.php
│   │   │   └── Notifications/
│   │   │       └── PushService.php
│   │   ├── Policies/
│   │   ├── Observers/
│   │   ├── Providers/
│   │   │   ├── BankServiceProvider.php
│   │   │   └── IapServiceProvider.php
│   │   ├── Rules/
│   │   ├── Enums/
│   │   │   ├── BankCode.php
│   │   │   ├── BankTransactionStatus.php
│   │   │   ├── WalletTxType.php
│   │   │   └── EpisodeStreamQuality.php
│   │   └── Exceptions/
│   │       ├── AppException.php
│   │       ├── BankPaymentException.php
│   │       └── InsufficientCoinsException.php
│   ├── bootstrap/
│   ├── config/
│   │   ├── storybox.php                   ← флаги фич, лимиты
│   │   ├── banks.php                      ← per-environment URLs
│   │   ├── drm.php
│   │   └── iap.php
│   ├── database/
│   │   ├── migrations/
│   │   ├── factories/
│   │   └── seeders/
│   ├── public/
│   ├── resources/
│   │   └── views/                         ← email-шаблоны, Filament кастом
│   ├── routes/
│   │   ├── api.php                        ← /api/v1/*
│   │   ├── license.php                    ← /license/*
│   │   ├── webhooks.php                   ← /webhooks/bank/*
│   │   ├── web.php
│   │   └── console.php                    ← schedule
│   ├── storage/
│   ├── tests/
│   │   ├── Feature/
│   │   │   ├── Auth/
│   │   │   ├── Episodes/
│   │   │   ├── Iap/
│   │   │   ├── Banks/                     ← AlifFlowTest, WebhookSecurityTest, и т.д.
│   │   │   └── License/
│   │   └── Unit/
│   │       ├── Banks/                     ← AlifBankDriverTest, и т.д.
│   │       └── Wallet/
│   ├── composer.json
│   ├── pint.json
│   ├── phpstan.neon
│   ├── phpunit.xml
│   ├── Dockerfile
│   └── .env.example
├── mobile/                                # Flutter 3.22
│   ├── lib/
│   │   ├── core/
│   │   │   ├── theme/                     ← ThemeData, цвета, типографика
│   │   │   ├── network/
│   │   │   │   ├── api_client.dart        ← Dio + Retrofit
│   │   │   │   ├── interceptors/          ← auth, retry, logger
│   │   │   │   └── ssl_pinning.dart
│   │   │   ├── storage/
│   │   │   │   ├── secure_storage.dart    ← токены
│   │   │   │   └── cache_storage.dart     ← Hive
│   │   │   ├── security/
│   │   │   │   ├── flag_secure.dart       ← Android FLAG_SECURE
│   │   │   │   ├── screen_recording_observer.dart  ← iOS UIScreen
│   │   │   │   ├── jailbreak_check.dart
│   │   │   │   └── watermark_overlay.dart
│   │   │   ├── analytics/
│   │   │   │   └── analytics_service.dart
│   │   │   ├── localization/
│   │   │   │   └── l10n_loader.dart       ← горячие переводы с сервера
│   │   │   ├── routing/
│   │   │   │   └── app_router.dart        ← go_router
│   │   │   └── errors/
│   │   │       └── app_exception.dart
│   │   ├── data/
│   │   │   ├── auth/
│   │   │   ├── content/                   ← series, episodes
│   │   │   ├── payments/
│   │   │   │   ├── iap_repository.dart
│   │   │   │   └── bank_payment_repository.dart
│   │   │   ├── wallet/
│   │   │   ├── ads/
│   │   │   └── notifications/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── usecases/
│   │   │   └── repositories/              ← интерфейсы
│   │   ├── presentation/
│   │   │   ├── splash/
│   │   │   ├── onboarding/
│   │   │   ├── auth/
│   │   │   │   ├── phone_otp_screen.dart
│   │   │   │   ├── email_screen.dart
│   │   │   │   └── social_login_buttons.dart
│   │   │   ├── home/                      ← главный экран с секциями
│   │   │   ├── discover/
│   │   │   ├── library/
│   │   │   ├── series/
│   │   │   │   └── series_detail_screen.dart
│   │   │   ├── player/
│   │   │   │   ├── vertical_player_screen.dart
│   │   │   │   ├── secure_player_widget.dart    ← с watermark
│   │   │   │   ├── overlay_controls.dart
│   │   │   │   └── unlock_sheet.dart
│   │   │   ├── store/
│   │   │   │   ├── coins_store_screen.dart      ← вкладки International/Local
│   │   │   │   ├── bank_selector_sheet.dart
│   │   │   │   ├── method_selector_sheet.dart
│   │   │   │   ├── bank_checkout_webview.dart
│   │   │   │   └── payment_result_screen.dart
│   │   │   ├── vip/
│   │   │   ├── profile/
│   │   │   ├── settings/
│   │   │   │   └── language_picker_screen.dart
│   │   │   └── widgets/                   ← общие виджеты
│   │   ├── l10n/
│   │   │   ├── app_ru.arb
│   │   │   ├── app_en.arb
│   │   │   ├── app_tg.arb
│   │   │   ├── app_uz.arb
│   │   │   ├── app_kk.arb
│   │   │   └── app_ky.arb
│   │   ├── flavors.dart                   ← dev / prod / appstore-reader
│   │   └── main.dart
│   ├── android/
│   │   └── app/src/main/                  ← MainActivity с FLAG_SECURE
│   ├── ios/
│   │   └── Runner/                        ← AppDelegate с UIScreen наблюдателями
│   ├── web/
│   ├── test/
│   ├── integration_test/
│   ├── pubspec.yaml
│   ├── analysis_options.yaml
│   └── l10n.yaml
└── ops/
    ├── nginx/
    ├── supervisor/
    └── ffmpeg-worker/
```

---

## 5. Соглашения по коду — Backend (Laravel)

### 5.1. Стиль и инструменты

- **Форматирование:** Laravel Pint (PSR-12 + Laravel preset). Запуск: `composer lint`. Авто-фикс: `composer lint:fix`.
- **Static analysis:** PHPStan уровень 8 + Larastan. `composer analyse`. Без `mixed`, без `phpdoc` лжи.
- **Запрет `array` без типизации:** используй DTO-классы (readonly classes из PHP 8.2) или typed arrays через Larastan generic.
- **Strict types:** `declare(strict_types=1);` в каждом PHP-файле.
- **Naming:**
  - Классы — `PascalCase` (`BankPaymentManager`)
  - Методы / переменные — `camelCase`
  - Константы — `SCREAMING_SNAKE`
  - Enum cases — `PascalCase` (`BankCode::Alif`)
  - Таблицы БД — `snake_case` множественное (`bank_transactions`)
  - Колонки — `snake_case`
  - Routes — `kebab-case` (`/payments/bank/initiate`)

### 5.2. Архитектурные правила

- **Сервисы**, не «толстые контроллеры». Контроллер: валидация (FormRequest) → вызов сервиса → API Resource. Логика — в `app/Services/`.
- **DTO для всех границ:** запрос внешнего API, webhook payload, JOB payload — через `readonly class`, не массивы.
- **Eloquent → Sanctum:** глобальный scope для tenant'ов не нужен, но всегда фильтруй по `user_id` в репозиториях.
- **Транзакции:** любая операция, изменяющая `wallet` + `wallet_transactions`, — обёрнута в `DB::transaction(function() {...})`. Если есть запросы к внешним API внутри транзакции — рефакторь: внешний вызов снаружи, БД-запись внутри.
- **Idempotency:** ВСЕ платёжные эндпоинты + webhook'и идемпотентны. Ключ хранится в Redis (TTL 24 ч) или в БД (`bank_transactions.idempotency_key UNIQUE`).
- **Enum'ы вместо строк:** все статусы — backed enums (`BankTransactionStatus::Succeeded`).
- **AppException:** все бизнес-ошибки — наследники `App\Exceptions\AppException` с кодом, сообщением, причиной. Ловятся в `app/Exceptions/Handler.php` и превращаются в JSON `{error:{code,message}}`.

### 5.3. Тесты

- **Pest 3** как основной фреймворк.
- **Феньки:** `Feature` тесты — для эндпоинтов и happy path; `Unit` — для драйверов, чистой логики, валидаторов.
- **Покрытие:** wallet + banks + iap_verifier — **минимум 90 %**, остальной backend — **70 %**. Без зелёного `coverage:check` PR не мержится.
- **Mock внешних API:** через `Http::fake()` (банки, IAP), Sentry-моки.
- **Database:** `RefreshDatabase` + factories. Никаких ручных INSERT'ов в тестах.

---

## 6. Соглашения по коду — Frontend (Flutter)

### 6.1. Стиль и инструменты

- **Lints:** `very_good_analysis` или `flutter_lints` + custom правила в `analysis_options.yaml`.
- **Метрики:** `dart_code_metrics` для обнаружения сложных функций (cyclomatic > 10).
- **Форматирование:** `dart format --line-length=100` (commit hook).
- **Naming:**
  - Классы — `PascalCase` (`VerticalPlayerScreen`)
  - Файлы — `snake_case` (`vertical_player_screen.dart`)
  - Константы — `lowerCamelCase` или `kPrefixed` для глобальных (`kDefaultPadding`)
  - Provider'ы — суффикс `Provider` (`coinsBalanceProvider`)

### 6.2. Архитектурные правила

- **Clean architecture:** `data` → `domain` → `presentation`. Зависимости только сверху вниз.
- **State:** Riverpod 2 с `@riverpod` codegen (`flutter_riverpod` + `riverpod_generator` + `riverpod_lint`).
- **Никаких StatefulWidget**, кроме случаев с `AnimationController` или нативной интеграции.
- **API клиент:** Retrofit + Dio. Все эндпоинты типизированы. Никаких `Map<String, dynamic>` в presentation слое.
- **Ошибки:** sealed-классы (`Result.success | Result.failure`) либо `AsyncValue` от Riverpod. Никаких `try/catch` в виджетах.
- **Локализация:** все строки — через `AppLocalizations.of(context).key`. Хардкод запрещён, проверяется линтером.
- **Аналитика:** все ключевые события — через `AnalyticsService.track(eventName, params)`. Имена событий — константы в `analytics_events.dart`.

### 6.3. Платформенные различия

- **Build flavors:**
  - `dev` — staging API, debug-меню, fake-данные
  - `prod` — prod API, все банки видимы
  - `appstore` — prod API, локальные банки скрыты, Reader-app паттерн
- Конфиг через `flavors.dart` + `--dart-define`.

### 6.4. Тесты

- **Unit:** все usecase'ы, валидаторы, маппинги — Pest-style через `flutter_test` + mocktail.
- **Widget:** ключевые экраны (player, store, payment-result) — golden tests для верстки.
- **Integration:** `integration_test/` запускает happy path: login → home → series → unlock → play. Прогон в CI на эмуляторе.

---

## 7. Критические запреты (deal-breakers)

Эти правила нарушать НЕЛЬЗЯ. Если задача требует нарушения — стоп, обсуждение, ADR в `docs/decisions/`.

**1. Никогда не модифицируй `app/Services/Wallet/` и `app/Services/Banks/` без полного набора тестов в том же PR.** Любая ошибка = реальные деньги. Минимум: feature test happy path + edge case (duplicate, bad signature, race).

**2. Никогда не коммить секреты.** Настроены pre-commit hook'и: `gitleaks` + `php artisan check:secrets`. В коде — только `config('services.bank.alif.api_key')` через типизированный `config/banks.php`.

**3. Никогда не отдавай видео без signed URL или DRM.** Public m3u8 / mp4 не существует. Если нужен превью — только короткий клип (5 сек), отдельно сгенерированный, не основной контент.

**4. Никогда не упоминай в iOS App Store билде локальные банки или внешнюю оплату.** Apple отклонит (Guideline 3.1.1). Build flavor `appstore` СКРЫВАЕТ вкладку «Local» и заменяет её на кнопку «Купить на сайте» → Safari.

**5. Никогда не меняй схему БД без миграции.** Прямые `ALTER TABLE` в проде — увольнение. Миграции — через `php artisan make:migration` + проверка `php artisan migrate --pretend` перед прод-деплоем.

**6. Никогда не делай webhook-обработчик без HMAC-проверки + IP-whitelist + идемпотентности.** Полный набор паттернов — в `App\Services\Banks\WebhookProcessor`. Любой новый webhook должен использовать его.

**7. Никогда не принимай номер карты или CVV в наш backend.** Только на checkout-странице банка. PCI DSS scope = ноль.

**8. Никогда не пиши `any`-эквивалент в Dart (`dynamic` без причины) или `mixed` в PHP.** Кроме случаев десериализации перед валидацией — но сразу через DTO.

**9. Никогда не показывай настоящий user_id или email в watermark.** Только хеш или короткий идентификатор сессии.

**10. Никогда не оставляй `pending` / `redirected` транзакции без таймаута.** Все банковские транзакции имеют `expires_at` (по умолчанию +30 мин), reconciliation cron приводит их к финальному статусу.

---

## 8. Безопасность

### 8.1. Аутентификация и авторизация

- Sanctum bearer-токены, TTL 30 дней (refresh через silent re-auth).
- Все mutating-эндпоинты требуют JWT, GET'ы публичных листингов (home, discover) — без аутентификации, но с rate-limit.
- Filament admin: web-сессии + Spatie Permission (`super_admin`, `content_manager`, `finance_manager`, `support`, `viewer`).
- 2FA для админов (`pragmarx/google2fa-laravel`).

### 8.2. Rate limiting

| Endpoint | Limit |
|---|---|
| `/api/v1/auth/*` | 10 rpm на IP |
| `/api/v1/payments/bank/initiate` | 5 rpm на user, 30 rpm на IP |
| `/webhooks/bank/*` | 600 rpm на IP-источник (whitelisted) |
| `/api/v1/home`, `/api/v1/discover` | 60 rpm на user (с кэшем — фактически уходит на CDN) |
| `/license/*` | 10 rpm на user |
| Остальное | 120 rpm на user |

Реализация — Laravel rate limiter в `RouteServiceProvider`, опционально через Redis.

### 8.3. Webhook-безопасность

Все `/webhooks/bank/*` проходят:
1. **IP whitelist** — middleware `BankWebhookIpWhitelist`, IP'и из `bank_payment_providers.allowed_ips` (json).
2. **HMAC-проверка** — header `X-Signature` (имя зависит от банка), HMAC-SHA256 с `webhook_secret`.
3. **Replay protection** — header `X-Timestamp`, окно ±5 минут; nonce-store в Redis на 5 минут.
4. **Идемпотентность** — поиск `bank_transactions` по `external_id` + `provider_id`. Если статус уже финальный — 200 без действий.
5. **Лог в `bank_webhook_logs`** — каждый запрос, валиден или нет.

Никакой webhook-эндпоинт не пишется руками заново. Используй `App\Services\Banks\WebhookProcessor::handle()`.

### 8.4. Хранение секретов

- `.env` — только для dev/staging.
- Prod — через Doppler / AWS Secrets Manager / HashiCorp Vault (определить на этапе 0).
- Банковские ключи в `bank_payment_providers.api_key/secret_key/webhook_secret` шифруются через `Crypt::encryptString` (Laravel APP_KEY). Расшифровка только в драйвере, никогда не отдаётся в API.
- Пользовательские пароли — `Hash::make` (bcrypt cost 12).
- Pre-commit `gitleaks` блокирует AWS keys, GitHub tokens, RSA private keys, Stripe keys.

### 8.5. SSL и сеть

- Все исходящие запросы к банкам — HTTPS only, проверка цепочки.
- TLS pinning для нестабильных CA (опционально, флаг `bank_payment_providers.tls_pin`).
- Входящие — TLS 1.2+, HSTS, secure cookies.

### 8.6. Содержимое и БД

- Шифрование at-rest для MySQL — через managed-сервис (RDS / DigitalOcean Managed Database).
- Backup ежедневный, retention 30 дней.
- PII-минимизация: храним только то, что нужно для работы (телефон, email, имя). История просмотров анонимизируется через 1 год.

### 8.7. Pen-test и аудит

- Перед публичным релизом — internal review + automated scanner (OWASP ZAP, dependency check).
- Раз в полгода или перед крупным релизом — внешний pen-test.
- Все ручные действия админа с финансовым эффектом — в `audit_logs`.

---

## 9. Защита контента (anti-piracy)

### 9.1. Минимальные требования

| Платформа | Минимум | Полная защита |
|---|---|---|
| **Android** | FLAG_SECURE + AES-128 + signed URLs | + Widevine L1 + Play Integrity |
| **iOS** | UIScreen наблюдатели + AES-128 + AirPlay блок | + FairPlay + App Attest |
| **Web** | Widevine EME + signed URLs + watermark | + анти-DevTools + анти-record-API |

### 9.2. Паттерны

- **HLS only.** Никаких прямых mp4. Каждый эпизод транскодируется FFmpeg-job'ом в 240/480/720p HLS с AES-128.
- **Сегменты — signed URLs**, TTL 3–5 минут, привязаны к `user_id + device_id + episode_id`.
- **License proxy.** Клиент получает manifest, для DRM-сегментов запрашивает лицензию у нашего `/license/widevine` или `/license/fairplay`. Прокси сверяет JWT юзера и право доступа к эпизоду, потом ходит к Widevine/FairPlay серверу.
- **Watermark.** Полупрозрачный (alpha 0.08) хеш `user_id` поверх плеера, позиция меняется каждые 8 секунд. Реализация — overlay-виджет в `core/security/watermark_overlay.dart`.
- **Root/jailbreak detect.** При обнаружении — отказ в запуске премиум-плеера, лог в `stream_access_logs`.
- **Anomaly detection.** Cron каждый час: если у `user_id` >3 IP за сутки или >10 device_id — shadow-ban (плеер показывает заглушку), алерт в Slack `#anti-piracy`.
- **Honeypot эпизод.** 1 эпизод-приманка, никогда не показывается реальным юзерам, только в фид-парсерах сторонних агрегаторов. Если кто-то пытается его открыть — ban + DMCA.

### 9.3. Watermark детали

```dart
// pseudo
final watermarkText = sha256(userId).substring(0, 8);
Stack(
  children: [
    SecurePlayer(...),
    Positioned.directional(
      start: animatedX,
      top: animatedY,
      child: Text(watermarkText,
        style: TextStyle(color: Colors.white.withOpacity(0.08))),
    ),
  ],
);
// каждые 8 секунд animatedX/animatedY меняются на случайные.
```

### 9.4. FLAG_SECURE / UIScreen наблюдатели

- Android: `core/security/flag_secure.dart` оборачивает `_VerticalPlayerScreenState.initState()` — вызывает нативный канал, который ставит `getWindow().setFlags(FLAG_SECURE)`. На `dispose()` снимает.
- iOS: `core/security/screen_recording_observer.dart` слушает `UIScreen.capturedDidChangeNotification`. При записи — пауза плеера + diagnostic toast.

Те же FLAG_SECURE применяются на ЭКРАНАХ ПЛАТЕЖА (карта на webview). Это безопасно, не нарушает Apple правил.

---

## 10. Локальные банки Таджикистана

### 10.1. Поддерживаемые провайдеры

| Код | Банк | Методы |
|---|---|---|
| `alif` | Алиф Банк | Card, QR, Alif Mobi (wallet deep-link) |
| `eskhata` | Эсхата Банк | Card, QR |
| `dcbank` | Душанбе Сити Банк | Card, перевод |
| `korti_milli` (фаза 2) | Корти Милли | Card, QR |

API-документации каждого банка предоставляются по NDA после подписания мерчант-договора.

### 10.2. Архитектура — Strategy pattern

```
App\Services\Banks\
├── BankPaymentInterface          ← обязательный контракт
├── BankPaymentManager            ← резолвит драйвер по коду
├── WebhookProcessor              ← общий handler для всех webhook'ов
├── Drivers\
│   ├── AlifBankDriver
│   ├── EskhataBankDriver
│   └── DushanbeCityBankDriver
└── DTOs\
    ├── PaymentInitRequest
    ├── PaymentInitResponse
    ├── WebhookPayload
    └── ReconciliationItem
```

`BankPaymentInterface` (обязательно реализовать в каждом драйвере):

```php
public function initiate(PaymentInitRequest $req): PaymentInitResponse;
public function getStatus(string $externalId): PaymentStatus;
public function cancel(string $externalId): bool;
public function refund(string $externalId, ?int $amountTjsCents = null): bool;
public function verifyWebhookSignature(array $headers, string $body): bool;
public function parseWebhook(string $body): WebhookPayload;
public function reconcile(\DateTime $from, \DateTime $to): array;
```

### 10.3. Поток инициации платежа (от клиента до начисления коинов)

Полный sequence diagram — в `docs/tz.md` раздел 13.3. TL;DR:

```
1. Client  → POST /payments/bank/initiate (idempotency_key)
2. Backend → создать bank_transactions (status=pending)
3. Backend → driver.initiate() → банк создаёт сессию
4. Backend ← checkout_url + external_id
5. Backend → tx.status=redirected, отдаёт checkout_url клиенту
6. Client  → flutter_inappwebview открывает checkout_url
7. User    → вводит карту / 3DS / QR-скан / Alif Mobi
8. Bank    → POST /webhooks/bank/{code} (HMAC-signed)
9. Backend → WebhookProcessor.handle():
              a. IP whitelist
              b. HMAC verify
              c. Replay protection (timestamp)
              d. find tx by external_id
              e. idempotency check (если status уже финальный — 200)
              f. DB::transaction(): update tx + WalletService::credit()
              g. log в bank_webhook_logs
10. Client ← deep-link return_url, polling /payments/bank/{id}
11. Client → PaymentResultScreen с анимацией зачисления.
```

### 10.4. Reconciliation

`php artisan banks:reconcile` (cron каждый час):

1. Найти все `bank_transactions` со статусом `pending` или `redirected` старше 1 часа.
2. Для каждой `$driver->getStatus($externalId)`.
3. Если банк говорит `succeeded` — догнать webhook (тот же код в `WalletService::credit`).
4. Если `failed` — обновить локально.
5. Если `pending >24h` — `expired`.

Раз в неделю — полный `$driver->reconcile($from, $to)`, сверка всех транзакций за период с банковской выпиской, отчёт о расхождениях в Slack `#payments`.

### 10.5. Reader-app паттерн на iOS

iOS App Store сборка (flavor `appstore`):
- На `CoinsStoreScreen` вкладка «Local» **не показывается**.
- Вместо неё — кнопка «Купить на сайте», ведущая в Safari (`https://example.com/store?token=<short-lived>`), там пользователь оплачивает через банк.
- После оплаты приложение при следующем запуске синхронизирует баланс с бэка.
- Никаких прямых упоминаний банков, цен, конверсии в TJS в самом приложении.

### 10.6. Где смотреть полную спецификацию

Раздел 13 в `docs/tz.md` — с диаграммами потока, кодом `WebhookProcessor`, требованиями к sandbox-режимам.

---

## 11. Локализация (6 языков)

| Код | Язык | Письменность | Fallback |
|---|---|---|---|
| `ru` | Русский | Кириллица | (default) |
| `en` | English | Латиница | ru |
| `tg` | Тоҷикӣ | Кириллица | ru |
| `uz` | Oʻzbekcha | Латиница | ru |
| `kk` | Қазақша | Кириллица | ru |
| `ky` | Кыргызча | Кириллица | ru |

### 11.1. Технические правила

- **UI-строки Flutter:** ARB-файлы в `mobile/lib/l10n/app_<locale>.arb`. Codegen — `flutter gen-l10n`. Все ключи вызываются через `AppLocalizations.of(context).<key>`. Линтер ловит хардкод.
- **Контентные поля:** Spatie Translatable JSON-колонки в `series.title`, `episodes.synopsis`, `bank_payment_providers.name`, и т.д. Структура: `{"ru":"...","en":"...","tg":"..."}`.
- **Auto-detect** на первом запуске приложения по `Platform.localeName`, fallback `ru`.
- **Горячее обновление:** эндпоинт `GET /api/v1/translations/{locale}` с ETag-кэшем. Клиент кэширует в Hive, пере-загружает при изменении ETag. Полезно для срочных правок без релиза.
- **Форматирование чисел / дат / валют:** `intl` пакет. `NumberFormat.currency(locale: 'tg', symbol: 'TJS')`.
- **Псевдо-локаль для тестов:** `app_xx.arb` с обёрткой каждого ключа в `[«...»]` чтобы найти забытые переводы и обрезание текста.

### 11.2. Контент-флоу

1. Контент-менеджер пишет описание сериала на русском.
2. Через интеграцию с переводчиком (DeepL API / OpenAI) генерируется черновой перевод на 5 языков.
3. Переводчик-человек правит в Filament (multilang form Spatie Translatable).
4. После approve — публикация. Кэш `/home`, `/series/*` инвалидируется per-locale.

---

## 12. Тестирование

| Уровень | Инструмент | Что покрываем | Min coverage |
|---|---|---|---|
| Backend Unit | Pest | Драйверы банков, WalletService, валидаторы | 90 % |
| Backend Feature | Pest | Все эндпоинты `/api/v1`, webhook'и | 80 % |
| Backend Integration | Pest + MySQL test DB | Миграции, RLS-аналог через policies, FFmpeg jobs (с моком ffmpeg бинаря) | 70 % |
| Mobile Unit | flutter_test + mocktail | Repositories, usecase'ы, валидаторы | 70 % |
| Mobile Widget | flutter_test + golden | Player, Store, PaymentResult | критические экраны |
| Mobile Integration | integration_test | Happy path: login → home → unlock → play | 1 базовый сценарий обязателен |
| E2E Web | Playwright | Регистрация → коины (Stripe sandbox) → разблокировка | в фазе 6 |
| Load | k6 | `/home` 500 RPS, `/license` 200 RPS, P95 < 300 мс | раз в неделю на staging |

**CI блокирует merge без зелёных тестов.**

### 12.1. Mock-стратегия

- **HTTP-вызовы к банкам:** `Http::fake([...])` с фикстурами в `tests/fixtures/banks/<code>/`.
- **IAP:** sandbox от Apple/Google + локальный `IapVerifier` с заглушкой.
- **FFmpeg:** в тестах подменяется на echo-скрипт, проверяется только команда и job-state.
- **Sentry:** `Sentry::testing()`, отлов событий через `expect(Sentry::lastEvent())->toContain(...)`.
- **Push:** Firebase Admin SDK с `FAKE_FCM=true`.

### 12.2. Property-based тесты

Для `WalletService` — обязательно. Используем `pestphp/pest-plugin-faker` + `eris/eris` (PHP property testing). Свойства:
- credit + debit на одну сумму = тот же баланс.
- Сумма всех `wallet_transactions` = текущий `coins_balance`.
- Concurrent credit (через `LOCK FOR UPDATE`) не приводит к race.

---

## 13. Git workflow

- **Ветки:**
  - `main` — protected, только squash-merge через PR.
  - `develop` — интеграционная, deploy на staging.
  - `feat/<area>-<short>`, `fix/<area>-<short>`, `chore/<short>` — рабочие.
  - `hotfix/<short>` — от main, fast-track.
- **Conventional Commits:** `feat(banks):`, `fix(player):`, `chore(deps):`, `refactor(api):`, `test(wallet):`, `docs(tz):`.
- **PR:** один логический change, ≤ 400 строк дифа. Иначе дроби.
- **Review:** обязателен для PR в main. Self-review только для chore/docs.
- **Merge:** squash (linear history).
- **Tag:** `v<major>.<minor>.<patch>` для релизов; CI запускает prod-deploy.

---

## 14. CI/CD (GitHub Actions)

### 14.1. Workflow'ы

| File | Trigger | Что делает |
|---|---|---|
| `backend-ci.yml` | PR + push в backend/ | Pint, PHPStan, Pest unit + feature, coverage check |
| `mobile-ci.yml` | PR + push в mobile/ | flutter analyze, flutter test, integration_test on emulator (only on main) |
| `web-ci.yml` | PR + push в mobile/ (web flavor) | flutter build web, lighthouse-ci |
| `security.yml` | Daily | gitleaks, dependabot, OWASP dependency check, snyk |
| `deploy-staging.yml` | push в develop | Build Docker, push to registry, deploy на staging VPS |
| `deploy-prod.yml` | tag `v*` | Build, run migrations с `--pretend` review, ручное approve в GH, deploy |
| `mobile-build-android.yml` | tag `v*` | Fastlane: build AAB + APK, upload в Play Console internal track |
| `mobile-build-ios.yml` | tag `v*` | Fastlane: build IPA, upload в TestFlight |

### 14.2. Артефакты

- Retention 14 дней.
- Coverage отчёты — в Codecov.
- Sentry release — auto через `sentry-cli` в pipeline.

---

## 15. Стандартные команды разработки

### 15.1. Backend

```bash
# Поднять локально
docker compose up -d
docker compose exec app composer install
docker compose exec app php artisan migrate --seed
docker compose exec app php artisan key:generate
docker compose exec app php artisan storage:link

# Разработка
docker compose exec app php artisan serve              # dev-сервер
docker compose exec app php artisan horizon            # очереди
docker compose exec app php artisan tinker             # REPL

# Качество кода
docker compose exec app composer lint                  # Pint check
docker compose exec app composer lint:fix              # Pint --fix
docker compose exec app composer analyse               # PHPStan
docker compose exec app composer test                  # Pest
docker compose exec app composer coverage              # Pest --coverage

# Миграции
docker compose exec app php artisan make:migration <name>
docker compose exec app php artisan migrate
docker compose exec app php artisan migrate:rollback
docker compose exec app php artisan migrate:fresh --seed

# Cron / scheduled tasks (вручную)
docker compose exec app php artisan banks:reconcile
docker compose exec app php artisan episode:rotate-keys
docker compose exec app php artisan analytics:aggregate-daily

# Filament
docker compose exec app php artisan make:filament-resource SeriesResource
docker compose exec app php artisan filament:upgrade
```

### 15.2. Mobile

```bash
cd mobile
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter gen-l10n

# Запуск
flutter run --flavor dev -t lib/main.dart                  # dev
flutter run --flavor prod -t lib/main.dart                 # prod
flutter run --flavor appstore -t lib/main.dart             # iOS App Store билд

# Качество
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test/

# Билды
flutter build apk --flavor prod --release                  # Android APK (для альтернативных сторов)
flutter build appbundle --flavor prod --release            # Android AAB (Play Store)
flutter build ipa --flavor appstore --release              # iOS
flutter build web --release                                # Web PWA
```

### 15.3. Корневые скрипты

```bash
./scripts/setup-dev.sh        # Полный setup: backend + mobile, миграции, seed
./scripts/seed-test-data.sh   # 5 жанров, 20 сериалов, 30 эпизодов, 3 банка в test mode
./scripts/deploy.sh staging
./scripts/deploy.sh prod
```

---

## 16. Работа с Claude Code — правила экономии ресурсов

**Главный принцип:** один токен сэкономлен — два часа сохранены. Без дисциплины сессия уходит в дорогой Opus, где Claude переписывает то, что уже написал.

### 16.1. Выбор модели

| Задача | Модель |
|---|---|
| Шаблонный код, миграции, переименования, форматирование | **Haiku** |
| Большинство фич, рефакторинг, тесты, FormRequest'ы | **Sonnet** (default) |
| Архитектура, дебаг банковской интеграции, security review, ADR | **Opus** (точечно) |

Default в `~/.claude/settings.json` — Sonnet. Переключение `/model haiku` / `/model opus`.

### 16.2. Plan mode

Любая задача >15 минут или >3 файлов — сначала **Plan mode** (`Shift+Tab` дважды). План → review → исполнение. Экономит 30–50 % токенов.

### 16.3. Subagents

Используй для:
- **Поиска по кодовой базе** (`Explore`) — не загромождает основной контекст.
- **Чтения больших файлов** — пусть subagent читает 800 строк миграции и возвращает 50-строчный summary.
- **Параллельной работы** — один пишет миграцию, второй пишет тест.
- **Code review своего кода** — subagent с инструкцией «найди баги», свежий взгляд.
- **Написания драйвера банка** — отдельный subagent с контекстом раздела 10 + NDA-документации.

### 16.4. Slash-команды (`.claude/commands/`)

| Команда | Что делает |
|---|---|
| `/new-feature <area> <name>` | FormRequest + Controller + Resource + Test + Filament resource |
| `/add-bank <code>` | Скаффолдит драйвер по интерфейсу + webhook + миграция config + Filament |
| `/db-migration <desc>` | Миграция через `make:migration` + откат тест |
| `/wallet-change` | Чек-лист: тесты, ADR, ревью, property-based test |
| `/security-check` | Subagent проверяет diff на OWASP-паттерны |
| `/coverage-gap` | Находит модули с покрытием < 70% |
| `/translate-arb <key> <ru-text>` | Добавляет ключ во все 6 ARB-файлов с черновым переводом |
| `/release-note` | Генерирует CHANGELOG.md из conventional commits с последнего тега |
| `/reconciliation-check` | Запускает `banks:reconcile` в dry-run режиме и показывает diff |

### 16.5. Промпт-шаблоны (`prompts/`)

Хорошо отлаженный промпт ценнее, чем «само придумаю».

```
prompts/
├── add-bank-driver.md            ← полный туториал на добавление нового банка
├── add-language.md               ← добавить локализацию + ARB + Spatie Translatable
├── add-iap-product.md            ← новая SKU в IapProduct + админ-форма
├── debug-drm.md                  ← диагностика проблем с Widevine/FairPlay
├── write-feature-test.md         ← шаблон Pest feature-теста
├── write-property-test.md        ← property-based тест для wallet
├── reconciliation-check.md       ← как разбирать расхождения с банком
├── translate-screen.md           ← добавить локализацию экрана на 6 языков
├── adapt-bank-webhook.md         ← новый webhook через WebhookProcessor
└── flutter-secure-screen.md      ← добавить FLAG_SECURE / UIScreen наблюдатели на экран
```

### 16.6. Правила экономии токенов в сессии

- **Не вставляй большие файлы в чат.** Указывай путь.
- **Используй Grep/Glob, а не Read целиком.**
- **Edit вместо Write** для существующих файлов — только diff.
- **`/clear` между несвязанными задачами.**
- **Не пиши «спасибо», «давай ещё подумаем».** Каждое лишнее сообщение = повтор контекста.
- **Конкретика в запросах:** «проверь, что webhook handler в `WebhookProcessor::handle()` идемпотентен — посмотри `tests/Feature/Banks/WebhookSecurityTest.php`».
- **`--resume`** для продолжения вчерашней сессии.

### 16.7. Codegen вместо ручного кода

- `composer dump-autoload`
- `php artisan ide-helper:generate` + `ide-helper:models` — типы для Eloquent
- `flutter pub run build_runner build` — Riverpod, Retrofit, Freezed
- `flutter gen-l10n` — ARB → Dart
- `php artisan make:filament-resource X --generate` — авто-форма по миграции

### 16.8. Решающее дерево

```
Архитектура / выбор стека / новый банк → Plan mode + Opus
Знакомая фича по образцу → slash-команда + Sonnet
Поиск по коду → subagent Explore
Багфикс с воспроизведением → Sonnet, прицельно
Локальный рефакторинг файла → Edit + Haiku
Большой дебаг (DRM, race condition) → Plan mode + Opus, потом Sonnet
Тесты к существующему модулю → Sonnet с шаблоном из prompts/
Миграция БД → /db-migration + ручная проверка
```

---

## 17. Подробный план разработки (Roadmap, vibe-coding оптимизированный)

> **v2 — оптимизирован под возможности Claude Code.** Прежняя версия (горизонтальные срезы, монолитные этапы) перенесена в `docs/decisions/0001-roadmap-v1-vs-v2.md`. См. также раздел 16 — правила работы с моделями.

### 17.0. Принципы (применять везде)

| Принцип | Что значит | Где обязателен |
|---|---|---|
| **Walking Skeleton First** | Сначала e2e stub (1 эндпоинт + 1 экран + связь), потом наслаиваем фичи | Фаза 0 |
| **Vertical Slice** | Одна фича = миграция + API + UI + тест в одном PR | Все фичи после skeleton |
| **TDD для High-Risk** | Pest тест (red) → реализация (green) → рефакторинг | wallet, banks, IAP, DRM |
| **Type Contracts First** | OpenAPI / DTO определяются ДО кода. Codegen клиента (`openapi_generator`) | Все API-эндпоинты |
| **Codegen Maximization** | Filament `--generate`, retrofit_generator, riverpod_generator, freezed | Всегда |
| **Mock-first для Parallelism** | Backend пишет фейк-эндпоинт → mobile параллелит | После skeleton |
| **One Session = One PR** | Каждая задача атомарна, помещается в 30-90 мин Claude-сессии | Все задачи |
| **Plan Mode + Opus для Risky** | Финансы, безопасность, новые интеграции | wallet, banks, DRM, IAP, новый банк |
| **Demo Friday** | В конце каждой недели — кликабельная демка / staging deploy | Каждая фаза |
| **Spike перед интеграцией** | Неизвестный внешний API — Postman + ADR ДО кода | Каждый банк, AdMob SSV, FairPlay |
| **One-then-Template** | Первый банк end-to-end до зелёного, потом остальные по шаблону за 3 дня | Banks, языки |

**Каждая задача в таблицах ниже = одна Claude-сессия.** Колонка «Модель» — рекомендация (`/model haiku|sonnet|opus`). Колонка «TDD» — обязательно ли начинать с теста.

---

### Фаза 0. Walking Skeleton (1 неделя, ~10 сессий)

**Цель:** end-to-end stub за неделю — фейковый API + фейковый mobile + связь работает. Дальше всё нанизывается, треки разблокированы для параллельной работы.

| # | Задача | Модель | DoD |
|---|---|---|---|
| 0.1 | git init + `.gitignore` + `.editorconfig` + `scripts/setup-dev.sh` | Haiku | git push |
| 0.2 | `docker-compose.yml` (app, nginx, mysql, redis, mailhog, horizon, ffmpeg-worker) + Laravel `create-project` + эндпоинт `/api/v1/ping` | Sonnet | `curl /ping` = 200 |
| 0.3 | `flutter create` + 3 flavors (`dev`/`prod`/`appstore`) + экран "API ping = OK" | Sonnet | apk запускается на эмуляторе |
| 0.4 | GitHub Actions: backend-ci + mobile-ci + security.yml зелёные на skeleton | Haiku | green badges в README |
| 0.5 | OpenAPI spec для `/ping` + codegen клиента (`openapi_generator`) | Sonnet | `mobile/lib/api/` auto-generated |
| 0.6 | Sentry baseline (test event из обоих проектов) + Firebase project | Haiku | events в Sentry dashboard |
| 0.7 | `CLAUDE.md` + `docs/tz.md` + 3 базовых `prompts/*.md` (add-bank-driver, write-feature-test, translate-arb) | Sonnet | docs commit |
| 0.8 | Filament UserResource + super_admin role + seeder | Haiku | `/admin` логин работает |
| 0.9 | `scripts/seed-test-data.sh` (1 user, 1 wallet, 1 series, 1 episode, 3 банка test mode) | Sonnet | `pnpm seed` запускается |
| 0.10 | **Demo Friday:** деплой на staging VPS, screenshot в README | Sonnet | staging URL живёт |

**DoD фазы:** `./scripts/setup-dev.sh && open http://localhost` — работает у любого с нуля. CI зелёный. Можно приглашать дизайнера и контент-менеджера тыкать в Filament.

---

### Фаза 1. Auth Vertical Slice (1 неделя, ~8 сессий)

**Цель:** регистрация через OTP end-to-end. На симуляторе можно зарегистрироваться, токен сохраняется.

| # | Задача | Модель | TDD? |
|---|---|---|---|
| 1.1 | Миграции `users` + `wallets` + `user_social_accounts` + factories | Haiku | — |
| 1.2 | Pest тест на `POST /auth/otp/request` (red) | Sonnet | red |
| 1.3 | Реализация эндпоинта + `OtpSenderInterface` + `TelegramOtpSender` (логгер-заглушка) | Sonnet | green |
| 1.4 | Pest тест на `POST /auth/otp/verify` → возврат Sanctum-токена (red) | Sonnet | red |
| 1.5 | Реализация verify + Sanctum + API Resource | Sonnet | green |
| 1.6 | OpenAPI обновление + codegen Retrofit-клиента | Haiku | — |
| 1.7 | Flutter: `PhoneOtpScreen` + `OtpInputScreen` + Riverpod auth provider | Sonnet | — |
| 1.8 | Integration test (Flutter): полный flow login → home stub | Sonnet | green |

**DoD:** на симуляторе можно зарегистрироваться, токен сохраняется в secure_storage, при перезапуске не нужно логиниться. Coverage `AuthController` = 100%.

---

### Фаза 2. Content Vertical Slice (1.5 недели, ~12 сессий)

**Цель:** контент-менеджер заливает сериал в Filament → юзер видит его в Home + открывает плеер с stub-видео.

| # | Задача | Модель |
|---|---|---|
| 2.1 | Миграции: `genres`, `series` (Spatie Translatable), `episodes`, `episode_streams` | Haiku |
| 2.2 | Pest → `GET /home` (5 секций) + Redis-кэш | Sonnet |
| 2.3 | Реализация HomeController + invalidation хук на изменение series | Sonnet |
| 2.4 | Pest → `GET /series/{id}` + `GET /episodes/{id}` (с проверкой доступа) | Sonnet |
| 2.5 | EpisodeAccessPolicy + контроллеры | Sonnet |
| 2.6 | Filament SeriesResource + EpisodeResource (без upload пока) | Sonnet |
| 2.7 | EpisodeResource + upload-поле + stub `TranscodeEpisode` job | Sonnet |
| 2.8 | OpenAPI обновление + codegen клиента | Haiku |
| 2.9 | Flutter HomeScreen со списком из API | Sonnet |
| 2.10 | Flutter SeriesDetailScreen | Sonnet |
| 2.11 | Flutter VerticalPlayerScreen со stub HLS (любой публичный m3u8 для теста) | Sonnet |
| 2.12 | **Demo Friday** + integration test happy-path + локализация baseline (ru + en через ARB) | Sonnet |

**DoD:** контент-менеджер в `/admin` создал сериал → видно в Flutter app → плеер крутит stub-видео.

---

### Фаза 3. Wallet + Unlock Vertical Slice (1 неделя, ~8 сессий) — **TDD ОБЯЗАТЕЛЕН**

**Цель:** разблокировка эпизода за коины. WalletService атомарен и идемпотентен.

| # | Задача | Модель | Особенность |
|---|---|---|---|
| 3.1 | Миграции `wallet_transactions`, `user_episode_unlocks` | Haiku | — |
| 3.2 | **Plan mode + Opus**: WalletService архитектура (locks, инварианты, race conditions) | **Opus** | Plan |
| 3.3 | Property-based тесты WalletService (Pest + Eris): credit-debit инвариант, balance_after = sum(transactions), concurrent credit no race | Sonnet | TDD red |
| 3.4 | Реализация WalletService::credit/debit с `LOCK FOR UPDATE` + `DB::transaction` | Sonnet | TDD green |
| 3.5 | Pest тест EpisodeUnlockService (4 сценария: enough/not enough/already/VIP) | Sonnet | TDD red |
| 3.6 | Реализация EpisodeUnlockService | Sonnet | TDD green |
| 3.7 | Эндпоинты `POST /episodes/{id}/unlock` (idempotent), `GET /wallet`, `GET /wallet/transactions` | Sonnet | — |
| 3.8 | Flutter UnlockSheet + WalletScreen + интеграция в плеер | Sonnet | — |

**DoD:** coverage WalletService = 100%, EpisodeUnlockService = 100%. Property-tests проходят 1000× без ошибок. На симуляторе разблокировка работает.

---

### Фаза 4. FFmpeg + Real Video (3-4 дня, ~5 сессий)

**Цель:** загруженное видео конвертируется в HLS, AES-128, играет в плеере.

| # | Задача | Модель |
|---|---|---|
| 4.1 | Job `TranscodeEpisode` (HLS 240/480/720, segment 4 сек, без шифрования пока) | Sonnet |
| 4.2 | Тест job с echo-mock FFmpeg — проверка команды и state-machine | Sonnet |
| 4.3 | Реальный прогон: загрузить mp4 → получить HLS на MinIO локально | Sonnet |
| 4.4 | Job `EncryptHlsSegments` — AES-128, ключи в `episode_keys` | Sonnet |
| 4.5 | Flutter: better_player с реальным HLS+AES → играет | Sonnet |

**DoD:** контент-менеджер залил mp4 → через 2 минуты эпизод доступен в приложении и реально играет.

---

### Фаза 5. IAP Vertical Slice (1.5 недели, ~10 сессий) — **TDD ОБЯЗАТЕЛЕН**

**Цель:** покупка коинов через Google Play sandbox работает end-to-end. RTDN/Apple Server Notifications обрабатывают refund.

| # | Задача | Модель | Plan? |
|---|---|---|---|
| 5.1 | **Plan mode**: IAP flow + edge cases (refund, expired, replay, race) | **Opus** | да |
| 5.2 | Миграции `iap_products`, `iap_transactions`, `vip_plans`, `user_subscriptions` | Haiku | — |
| 5.3 | Pest GoogleIapVerifier (с моком Play Developer API через `Http::fake`) | Sonnet | TDD red |
| 5.4 | Реализация GoogleIapVerifier | Sonnet | TDD green |
| 5.5 | Pest AppleIapVerifier (с моком App Store Server API v2) | Sonnet | TDD red |
| 5.6 | Реализация AppleIapVerifier | Sonnet | TDD green |
| 5.7 | `POST /iap/verify` с idempotency (key = purchase_token) | Sonnet | — |
| 5.8 | Webhooks `/webhooks/iap/google` (RTDN) + `/webhooks/iap/apple` для refund | Sonnet | — |
| 5.9 | Filament IapProductResource + IapTransactionResource (с фильтрами + manual refund) | Sonnet | — |
| 5.10 | Flutter CoinsStoreScreen (только International tab пока) + покупка через `in_app_purchase` | Sonnet | — |

**DoD:** sandbox-аккаунт Google: покупка `coins_100` → `/iap/verify` → +100 коинов в кошельке. Coverage IapVerifier = 100%. Refund через RTDN списывает коины.

---

### Фаза 6. Banks — ONE FIRST, потом ШАБЛОН (3 недели)

**Принцип:** один банк end-to-end до зелёного теста. Только потом второй и третий по шаблону.

#### 6A. Spike Alif Bank (1-2 дня, ~3 сессии)

| # | Задача | Модель |
|---|---|---|
| 6A.1 | **Plan + Opus**: подписать NDA, прочитать API доку Алиф, нарисовать sequence-диаграмму, выяснить особенности (HMAC алгоритм, формат payload) | Opus |
| 6A.2 | Postman-коллекция: ручной запрос init → callback (поддельный) в sandbox | Sonnet |
| 6A.3 | ADR `docs/decisions/0004-alif-integration.md` — что узнали, как маппим статусы, риски | Sonnet |

#### 6B. Strategy + Alif end-to-end (4-5 дней, ~8 сессий) — **TDD**

| # | Задача | Модель |
|---|---|---|
| 6B.1 | Миграции `bank_payment_providers`, `bank_products`, `bank_transactions`, `bank_webhook_logs` (с шифрованием через `Crypt::encryptString` cast) | Haiku |
| 6B.2 | DTO (`PaymentInitRequest`, `PaymentInitResponse`, `WebhookPayload`, `ReconciliationItem` — readonly classes) + `BankPaymentInterface` + `BankPaymentManager` (Laravel Manager pattern) | Sonnet |
| 6B.3 | Pest AlifBankDriver (моки HTTP через `Http::fake`, фейковые HMAC-подписи, маппинг статусов) | Sonnet |
| 6B.4 | Реализация AlifBankDriver (init/getStatus/cancel/refund/verifyWebhook/parseWebhook/reconcile) | Sonnet |
| 6B.5 | Pest WebhookProcessor (HMAC, IP-whitelist, replay, idempotency, duplicate, tx not found, bad signature) | Sonnet |
| 6B.6 | Реализация WebhookProcessor (общий для всех банков по паттерну `docs/tz.md` 13.4) | Sonnet |
| 6B.7 | Endpoints `/payments/banks`, `/payments/banks/{code}/products`, `POST /payments/bank/initiate` (idempotency_key), `GET /payments/bank/{id}`, `POST /payments/bank/{id}/cancel`, `/webhooks/bank/alif` | Sonnet |
| 6B.8 | Job `BanksReconcile` + cron schedule + тест с зависшими transactions | Sonnet |

#### 6C. Filament + Mobile UI Alif (3 дня, ~5 сессий)

| # | Задача | Модель |
|---|---|---|
| 6C.1 | Filament BankProviderResource (password-fields для ключей, action «Test connection») | Sonnet |
| 6C.2 | Filament BankTransactionResource + BankWebhookLogResource (read-only, raw payload) | Sonnet |
| 6C.3 | Flutter Riverpod state-machine (`idle → selectingBank → selectingMethod → initiating → inWebView → polling → succeeded\|failed\|expired`) + BankPaymentRepository | Sonnet |
| 6C.4 | Flutter BankSelectorSheet + MethodSelectorSheet + BankCheckoutWebView (whitelisted hosts) + PaymentResultScreen (polling 2 сек × 60 сек, анимация) + deep-link через app_links | Sonnet |
| 6C.5 | Reader-app в `appstore` flavor: Local скрыт, кнопка «Купить на сайте» → `url_launcher` Safari | Haiku |

**DoD первого банка:** Alif test full happy-path: client → initiate → checkout → webhook → coins credited. Bad signature → 401. Duplicate → idempotent. IP не из whitelist → 403. Replay → 401. Coverage `app/Services/Banks/` = 100%.

#### 6D. Eskhata Bank по шаблону (3-4 дня, ~5 сессий)

| # | Задача | Модель |
|---|---|---|
| 6D.1 | Spike Eskhata sandbox + ADR `0005-eskhata-integration.md` | Opus |
| 6D.2 | EskhataBankDriver — TDD по шаблону Alif (особенности: возможно XML payload вместо JSON) | Sonnet |
| 6D.3 | Webhook controller + integration tests (с фиктивными подписанными payload) | Sonnet |
| 6D.4 | Filament seeder + UI integration (банк появляется в `BankSelectorSheet`) | Haiku |
| 6D.5 | E2e зелёный + polish | Sonnet |

#### 6E. Dushanbe City Bank (3-4 дня, ~5 сессий)

| # | Задача | Модель |
|---|---|---|
| 6E.1 | Spike DCBank sandbox + ADR `0006-dcbank-integration.md` | Opus |
| 6E.2 | DushanbeCityBankDriver по шаблону (методы card + transfer) | Sonnet |
| 6E.3 | Webhook controller + tests | Sonnet |
| 6E.4 | Seeder + UI integration | Haiku |
| 6E.5 | E2e зелёный | Sonnet |

#### 6F. Demo: 3 банка работают, reconciliation cron на staging — 1 сессия

---

### Фаза 7. Retention Features (1.5 недели, параллельные slice'ы)

Каждая — отдельный vertical slice по 1-2 дня. Можно параллелить — 2 трека по 4-5 дней.

| # | Slice | Сессий | Модель |
|---|---|---|---|
| 7.1 | Push (FCM register + send + open from notification + deep-link) | 3 | Sonnet |
| 7.2 | Comments (CRUD + модерация в Filament + bottom sheet в Flutter) | 3 | Sonnet |
| 7.3 | Likes + Favorites (counter cache, Library screen) | 2 | Sonnet |
| 7.4 | Watch History (с progress sync — batched раз в 10 сек) | 2 | Sonnet |
| 7.5 | Search (FULLTEXT MySQL + recent queries в Hive) | 2 | Sonnet |
| 7.6 | Daily Check-in + Referrals (share-link, claim) | 3 | Sonnet |
| 7.7 | Rewarded Ads + SSV (со spike на ECDSA-проверку подписи AdMob) | 3 | Sonnet |

**DoD:** все эндпоинты разделов 6.7–6.10 ТЗ работают. Push доставляется за <30 сек. Coverage этих модулей >= 70%.

---

### Фаза 8. Localization (3-4 дня, ~6 сессий)

**Цель:** все 6 языков работают, контент переводится через Filament, переводы обновляются на лету.

| # | Задача | Модель |
|---|---|---|
| 8.1 | ARB-файлы 6 языков (ru/en/tg/uz/kk/ky) + `flutter gen-l10n` | Haiku |
| 8.2 | Custom lint rule: запрет хардкод-строк в Flutter (через `dart_code_metrics`) | Sonnet |
| 8.3 | Spatie Translatable forms в Filament на 6 языков (для series, episodes, bank_payment_providers.name) | Sonnet |
| 8.4 | `/translations/{locale}` с ETag-кэшем + invalidation | Sonnet |
| 8.5 | Hot-reload переводов на клиенте (Hive cache, ETag check на старте) | Sonnet |
| 8.6 | Псевдо-локаль `xx` для smoke забытых строк (`[«...»]` обёртка) | Haiku |

**DoD:** все экраны переключаются на любой из 6 языков. Псевдо-локаль `xx` не показывает голые ключи.

---

### Фаза 9. Anti-Piracy (2 недели) — **TDD ОБЯЗАТЕЛЕН**

**Цель:** все anti-piracy меры из раздела 9 этого CLAUDE.md и раздела 12 ТЗ работают.

| # | Задача | Модель | Plan? |
|---|---|---|---|
| 9.1 | **Plan + Opus**: DRM full architecture — Widevine + FairPlay key servers, license proxy, key rotation | **Opus** | да |
| 9.2 | SignedUrlService + LogStreamAccess middleware + tests (TTL 5 мин, HMAC) | Sonnet | TDD |
| 9.3 | License proxy `/license/widevine` (POST с эпизодом ID + JWT, сверка доступа, ходит к Widevine modular server) | Sonnet | — |
| 9.4 | License proxy `/license/fairplay` (CBCS, аналогично) | Sonnet | — |
| 9.5 | Job EpisodeRotateKeys + cron weekly (старые ключи сохраняются для скачанных, новые скачивания только с новым ключом) | Sonnet | — |
| 9.6 | Flutter WatermarkOverlay (alpha 0.08, позиция меняется каждые 8 сек, hash user_id) + golden test | Sonnet | — |
| 9.7 | Flutter FLAG_SECURE Android через method channel (применяется на `VerticalPlayerScreen` + `BankCheckoutWebView`) | Sonnet | — |
| 9.8 | Flutter UIScreen.capturedDidChangeNotification iOS (нативный канал, пауза + diagnostic toast) | Sonnet | — |
| 9.9 | dio_certificate_pinning + integration test (попытка MITM через Charles → fail) | Sonnet | — |
| 9.10 | Play Integrity backend верификация (header `X-Integrity-Token` на login/payment) | Sonnet | — |
| 9.11 | App Attest backend верификация iOS | Sonnet | — |
| 9.12 | Anomaly detection cron (>3 IP / >10 device_id за сутки → shadow_ban) + Slack alert + honeypot эпизод | Sonnet | — |

**DoD:** Android — попытка скриншота в плеере = чёрный кадр. iOS — запись экрана = пауза. Watermark виден. AirPlay/Chromecast блокированы. SSL pinning блокирует MITM. Coverage `app/Services/Drm/` >= 80%.

---

### Фаза 10. Web (1 неделя, ~8 сессий)

**Цель:** Flutter Web как PWA, Stripe + локальные банки, SEO.

| # | Задача | Модель |
|---|---|---|
| 10.1 | `flutter build web --release` + manifest + service worker + иконки | Sonnet |
| 10.2 | Адаптивный layout (responsive_framework / breakpoints): сайдбар на desktop, мобильное меню на mobile | Sonnet |
| 10.3 | Stripe Checkout endpoint + webhook (для международных карт) | Sonnet |
| 10.4 | SEO meta-tags + sitemap.xml + JSON-LD VideoObject + robots.txt | Haiku |
| 10.5 | Pre-render контентных страниц (rendertron / SSR proxy) | Sonnet |
| 10.6 | Lighthouse fix-up до PWA ≥90 / Performance ≥80 / Accessibility ≥90 | Sonnet |
| 10.7 | EME Widevine на вебе (для DRM в Chrome) | Sonnet |
| 10.8 | Deploy на staging Cloudflare + SSL Let's Encrypt | Haiku |

**DoD:** Web публикуется на staging URL, Lighthouse audit зелёный. Покупка через Stripe sandbox + Алиф test-mode завершается успешно на вебе.

---

### Фаза 11. Admin Polish (3-4 дня, ~5 сессий)

| # | Задача | Модель |
|---|---|---|
| 11.1 | Dashboard widgets: DAU/MAU, Revenue (Google/Apple/Bank breakdown), Top series, Top spenders, FFmpeg queue, Storage usage, Anomaly alerts, Bank webhook health | Sonnet |
| 11.2 | Audit log + Observer на действия с финансовым эффектом + AuditLogResource (read-only, фильтры) | Sonnet |
| 11.3 | Translations management page в Filament (CRUD + кнопка «Push to mobile» с ETag bump) | Sonnet |
| 11.4 | Broadcast notifications form (текст 6 языков, сегмент, schedule, очередь Horizon) | Sonnet |
| 11.5 | Reconciliation tool: загрузка CSV-выписки → парсер → сравнение с `bank_transactions` → отчёт matched/unmatched/mismatch + экспорт | Sonnet |

**DoD:** все сценарии раздела 9 ТЗ покрыты. Финансовый менеджер может пройти reconciliation без помощи разработчика.

---

### Фаза 12. Release Prep (1 неделя)

| # | Задача | Модель |
|---|---|---|
| 12.1 | k6 load test (`/home` 500 RPS, `/license` 200 RPS, `/payments/bank/initiate` 50 RPS, P95 < 300 мс) → fix N+1, добавить indexes | Sonnet |
| 12.2 | OWASP ZAP scan + `composer audit` + `flutter pub outdated` → fix issues | Sonnet |
| 12.3 | Google Play Console: app, metadata 6 языков, IAP SKU, Privacy + Terms (iubenda), data safety, internal track upload | Haiku |
| 12.4 | Apple App Store Connect: bundle ID, StoreKit products, TestFlight, Reader-app в Review notes, privacy nutrition labels | Haiku |
| 12.5 | RuStore + Galaxy Store альтернативные публикации (APK без Play Billing) | Haiku |
| 12.6 | Privacy + Terms на 6 языках через iubenda Starter | Haiku |
| 12.7 | Runbooks: `bank-webhook-down.md`, `ffmpeg-queue-stuck.md`, `drm-license-failure.md` | Sonnet |
| 12.8 | CHANGELOG.md обновлён + Sentry release tagged + tag `v1.0.0` + prod deploy | Sonnet |

**DoD проекта:**
- [ ] Все Acceptance Criteria из раздела 20 ТЗ выполнены
- [ ] Sentry — нет unresolved P0/P1 issues
- [ ] Coverage: backend ≥75%, wallet/banks/iap/drm ≥90%
- [ ] Google Play review pass + Apple App Review pass
- [ ] Boevaja аудитория получила доступ к продукту

---

### 17.13. Сводка: что дала vibe-coding оптимизация

| Аспект | Было (v1) | Стало (v2) |
|---|---|---|
| Подход | Горизонтально (весь backend → весь mobile) | Walking skeleton + vertical slices |
| Размер задачи | Недели-монолиты («Backend Core 3 недели») | Атомарные сессии 30-90 минут |
| Тесты | После кода | TDD для wallet / banks / IAP / DRM |
| Type contracts | Ручные ресурсы в 3 местах | OpenAPI + codegen — одно место |
| Reader-app iOS | Этап 4 | Фаза 0 (флавор `appstore` пустой с дня 1) |
| Banks | 3 параллельно | 1 end-to-end → шаблон → 2-3 быстро |
| DB миграции | Все на этапе 1 | Per feature |
| Demo | В конце фазы | Каждую неделю Demo Friday |
| Plan Mode маркеры | Нет | Явно для всех high-risk |
| Codegen | Упомянут | Принципиальная ось pipeline |
| Параллелизм | Sequential | После skeleton — параллельные треки |
| **Общий срок MVP** | **23-25 недель** | **~14 недель при том же качестве** |

---

## 18. Ловушки и FAQ

**Q: Можно ли сложную логику wallet вынести на frontend?**
A: Нет. Деньги считает только сервер. Любой клиентский расчёт — дубль для UX, не источник правды. Все балансы → `/api/v1/wallet`.

**Q: Webhook от банка пришёл повторно — что делать?**
A: Идемпотентно: `WebhookProcessor` ищет `bank_transactions` по `(provider_code, external_id)`. Если статус уже `succeeded` — return 200 без действий. Это не баг банка, это норма (banks retry on 5xx).

**Q: Pop-up «купите коины» в iOS App Store билде — можно показать ссылку на сайт?**
A: ДА, через Reader-app паттерн (просто кнопка, открывающая Safari). НЕТ для прямой кнопки «Купить через банк» в самом приложении (Guideline 3.1.1 — отклонят).

**Q: Видео грузится медленно из РФ — что включить?**
A: Cloudflare с регионом `auto` + BunnyCDN pull zone в Frankfurt. Для tg/uz аудитории — Frankfurt edge даёт <100мс.

**Q: User жалуется на чёрный экран при записи в TikTok — это баг?**
A: Это фича. FLAG_SECURE / capturedDidChange — работают как надо. В FAQ приложения — пояснение.

**Q: Тест падает только в CI, локально зелёный.**
A: 90% случаев — race condition в integration-тесте. Запусти `pest --processes=1`. Если зелёный — у тебя shared state между тестами. Используй `RefreshDatabase` корректно.

**Q: HLS сегменты не дешифруются на iOS, на Android всё ок.**
A: Скорее всего проблема с CORS на manifest или с FairPlay key server. Проверь:
- `/license/fairplay` отдаёт `application/octet-stream`, не JSON.
- В manifest указан `EXT-X-KEY:METHOD=SAMPLE-AES,URI=...,KEYFORMAT="com.apple.streamingkeydelivery"`.
- Persistent key server URL правильный.

**Q: Banks reconciliation сообщает о расхождении на 3 транзакции, что делать?**
A: Открой `BankTransactionResource` в Filament, фильтр по `provider_code` + период. Сравни с банковской выпиской вручную. Если банк говорит `succeeded`, у нас `pending` — webhook не дошёл, начисли вручную через action «Manually mark as succeeded» (audit log записывается). Если у нас `succeeded`, банк говорит ничего — баг в драйвере, разбираемся в логах.

**Q: Можно ли добавить четвёртый банк (например, Spitamen)?**
A: Да. Один драйвер + один webhook controller + один seeder. Шаблон в `prompts/add-bank-driver.md`. Никаких изменений в `BankPaymentManager` — он динамически резолвит по коду.

**Q: Почему мы не используем Stripe в Таджикистане?**
A: Stripe не работает в TJ напрямую, плюс комиссия выше + конверсия ниже из-за того что у местных нет международных карт.

**Q: Apple отклонил билд из-за упоминания «коины можно купить дешевле на сайте». Что делать?**
A: Удалить любые упоминания внешних цен, способов оплаты, названий банков. Reader-app паттерн = «Visit our website to purchase content» без указания цены/банка. Прочитай Guideline 3.1.1 ещё раз.

**Q: Watermark с user_id видно слишком явно — пользователи жалуются.**
A: alpha 0.08 — это уже почти невидимо при дневном просмотре. Если жалуются — это user уже пытался записать экран. Сценарий «вижу — значит, защита работает».

**Q: FFmpeg job'ы накапливаются, очередь не разгребается.**
A: Runbook `docs/runbooks/ffmpeg-queue-stuck.md`. TL;DR: проверь supervisor → `php artisan horizon:status` → если worker'ы упали (OOM) — увеличь память или ограничь число параллельных job'ов через `max_jobs` в `config/horizon.php`.

---

## 19. Onboarding для нового разработчика (или новой сессии Claude)

1. Прочитать **этот файл целиком**.
2. Прочитать `docs/tz.md` (полное ТЗ).
3. Прочитать `docs/architecture.md`.
4. Открыть `prompts/` — пробежать названия шаблонов.
5. `./scripts/setup-dev.sh` — поднять локально.
6. Открыть `http://localhost/admin`, залогиниться (`admin@storybox.tj` / `password`).
7. Открыть Flutter app на симуляторе, пройти сценарий: register → home → free episode → unlock attempt.
8. Запустить `composer test` + `flutter test` — все зелёные.
9. Прочитать **раздел 7 (запреты)** ещё раз.
10. Выбрать первую задачу из текущего этапа (раздел 17).

После этого — готов к задачам.

---

## 20. Не входит в первую версию (out of scope)

- UGC (загрузка контента пользователями).
- Подписки на каналов / авторов.
- Live-стриминг.
- Чат, личные сообщения.
- Offline-скачивание (DRM offline keys) — фаза 2.
- Apple TV / Android TV / iOS App Clips / Android Instant Apps.
- Donation / tip креаторам.
- Дополнительные банки (Spitamen, Tojiksodirotbonk, Amonatbonk) — фаза 2 через Strategy расширение.
- Криптоплатежи (TRX, USDT) — фаза 2.
- Click / Payme / Kaspi.kz / ElCart (Узбекистан, Казахстан, Киргизия) — фаза 2.

---

## 21. Контакты и ответственные

- Разработка / архитектура: владелец проекта
- Контент-продюсер: TBD
- Юр.поддержка: TBD (iubenda или штатный юрист)
- On-call (инциденты): владелец, runbook'и в `docs/runbooks/`

---

**Дата создания:** 29 апреля 2026.
**Версия CLAUDE.md:** 1.0.
**Версия источника-ТЗ:** 1.2.

> Если что-то в этом файле устарело — обнови сразу же, не «потом». Устаревший CLAUDE.md хуже, чем его отсутствие.
