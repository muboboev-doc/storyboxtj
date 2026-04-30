# Архитектура StoryBox Clone

> **Уровень:** обзорный + ключевые потоки. Полная спецификация — [`tz.md`](./tz.md).
> Принципы реализации (vertical slices, TDD для high-risk, codegen) — [`../CLAUDE.md` §17](../CLAUDE.md#17-подробный-план-разработки-roadmap-vibe-coding-оптимизированный).

---

## 1. Высокоуровневая схема

```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  Flutter Mobile │  │  Flutter Web /  │  │  Filament Admin │
│  (Android/iOS)  │  │     PWA         │  │  Panel (web)    │
└────────┬────────┘  └────────┬────────┘  └────────┬────────┘
         │                    │                    │
         └────────────────────┼────────────────────┘
                              │ HTTPS / REST
                              ▼
                  ┌──────────────────────────┐
                  │  Laravel API (nginx)     │
                  │  ┌──────────────────┐    │
                  │  │ /api/v1/*        │    │  ← Sanctum bearer-token
                  │  │ /admin/*         │    │  ← Filament + sessions + 2FA
                  │  │ /license/*       │    │  ← DRM proxy (Widevine + FairPlay)
                  │  │ /webhooks/bank/* │    │  ← HMAC + IP-whitelist + idempotency
                  │  │ /webhooks/iap/*  │    │  ← Google RTDN, Apple Server Notifications
                  │  └──────────────────┘    │
                  └─┬───────┬──────┬─────┬───┘
                    │       │      │     │
       ┌────────────┘       │      │     └─────────────┐
       ▼                    │      │                   ▼
  ┌─────────┐               │      │           ┌──────────────┐
  │ MySQL 8 │               │      │           │   Banks API  │
  │ + Redis │               │      │           │ Alif / Eskhata│
  │  cache  │               │      │           │   / DCBank   │
  │ queues  │               │      │           └──────────────┘
  └─────────┘               ▼      ▼
                  ┌────────────┐  ┌──────────┐
                  │  S3 / DO   │  │   CDN    │
                  │ Spaces /   │  │CloudFront│
                  │ local disk │  │ Bunny    │
                  │ HLS+AES128 │  │   etc.   │
                  └────────────┘  └──────────┘
                       ▲
                       │
                  ┌────┴────────┐
                  │  FFmpeg     │
                  │ Worker      │  ← async via Horizon queue
                  │ (transcode) │
                  └─────────────┘
```

---

## 2. Компоненты

### 2.1. Backend (Laravel 11)

Один Laravel-проект обслуживает 5 доменов одновременно:

| Группа маршрутов | Назначение | Auth | Rate-limit |
|---|---|---|---|
| `/api/v1/*` | Мобильный + Web клиент (REST + JSON) | Sanctum bearer-token | per-endpoint, см. [`tz.md` §11](./tz.md) |
| `/admin/*` | Filament CMS для контент-менеджеров и финансистов | Web сессия + Spatie Permission + 2FA | стандартный |
| `/license/*` | DRM license proxy (Widevine + FairPlay) | JWT-токен из Sanctum + device fingerprint | 10 rpm на user |
| `/webhooks/bank/*` | Server-to-server callback от банков | HMAC + IP whitelist + replay protection | 600 rpm на IP-источник |
| `/webhooks/iap/*` | Google RTDN + Apple Server Notifications | подпись провайдера | 600 rpm на IP |

**Структура `app/Services/`** (CLAUDE.md §4):

- `Wallet/WalletService` — атомарный leджер коинов (`DB::transaction` + `LOCK FOR UPDATE`)
- `Wallet/EpisodeUnlockService` — разблокировка эпизода: коины / VIP / реклама
- `Banks/BankPaymentManager` + `BankPaymentInterface` + 3 драйвера (Strategy pattern)
- `Banks/WebhookProcessor` — общий handler с HMAC, IP-whitelist, idempotency
- `IapVerifier/{GoogleIapVerifier, AppleIapVerifier}` — серверная верификация покупок
- `Drm/{DrmKeyService, SignedUrlService, LicenseProxyService}`
- `Streaming/StreamAccessLogger` — для anomaly detection

### 2.2. Frontend (Flutter)

Один Dart-кодbase для трёх таргетов: Android, iOS, Web. Build flavors (`lib/flavors.dart`):

| Flavor | Apple App Store | Google Play | Web | Локальные банки видимы? |
|---|---|---|---|---|
| `dev` | — | — | dev URL | да |
| `prod` | — | ✅ | ✅ | да |
| `appstore` | ✅ | — | — | **нет** (Reader-app pattern, [`tz.md` §13.7](./tz.md)) |

Запуск разных flavor'ов через `--target lib/main_<flavor>.dart`.

### 2.3. FFmpeg worker

Отдельный контейнер, слушает очередь `transcoding` (Horizon → Redis). Job `TranscodeEpisode`:

```
1. Скачивает оригинал из временного S3 storage
2. FFmpeg → 240p / 480p / 720p HLS, segment 4 сек
3. AES-128 ключ → episode_keys.content_key (encrypted)
4. Сегменты заливаются в активный диск (s3 / spaces / local)
5. episode_streams заполняется
6. Episode.status = 'ready'
```

### 2.4. CDN

CloudFront / Cloudflare Stream / BunnyCDN. Edge проверяет signed URL подпись (HMAC + TTL 5 мин + bound to user_id+device_id).

### 2.5. DRM key servers

- **Widevine modular license server** — для Android и Chrome (Web).
- **FairPlay key server** — для iOS / Safari.

Наш `/license/*` — proxy между клиентом и этими серверами. Сверяет JWT, проверяет права на эпизод, логирует в `stream_access_logs` для anomaly detection.

---

## 3. Ключевые потоки

### 3.1. Просмотр эпизода (happy path)

```
Client                Backend                     CDN          DRM Server
  │                      │                         │                │
  │── GET /api/v1/        │                         │                │
  │   episodes/123 ──────►│                         │                │
  │                      │ check user.unlocked      │                │
  │                      │ ✓ free or ✓ unlocked     │                │
  │◄── manifest URL ─────│ + signed URL (TTL 5m)   │                │
  │                      │                         │                │
  │── GET manifest.m3u8 ──────────────────────────►│                │
  │   (signed URL)       │                         │                │
  │◄── m3u8 ─────────────────────────────────────────│                │
  │                      │                         │                │
  │── Widevine challenge ►│                         │                │
  │   /license/widevine  │                         │                │
  │                      │ JWT verify               │                │
  │                      │ check episode access     │                │
  │                      │ check device whitelist   │                │
  │                      │── proxy to Widevine ────────────────────►│
  │                      │◄── license response ────────────────────│
  │◄── license ──────────│                         │                │
  │                      │                         │                │
  │── GET segment_001.ts ─────────────────────────►│                │
  │◄── encrypted bytes ─────────────────────────────│                │
  │                      │                         │                │
  │ decrypt + play       │                         │                │
  │ + watermark overlay  │                         │                │
```

Anti-piracy слои на клиенте: FLAG_SECURE (Android), `UIScreen.capturedDidChange` (iOS), watermark с user_id хешем, alpha 0.08 поверх плеера. См. [`CLAUDE.md` §9](../CLAUDE.md#9-защита-контента-anti-piracy).

### 3.2. Покупка коинов через локальный банк

Полная sequence-диаграмма — в [`tz.md` §13.3](./tz.md). TL;DR:

```
1. Client  → POST /api/v1/payments/bank/initiate (idempotency_key)
2. Backend → создать bank_transactions (status=pending)
3. Backend → driver.initiate() → банк создаёт сессию
4. Backend ← checkout_url + external_id
5. Backend → tx.status=redirected, отдаёт checkout_url клиенту
6. Client  → flutter_inappwebview открывает checkout_url
7. User    → вводит карту / 3DS / QR-скан / Alif Mobi deep-link
8. Bank    → POST /webhooks/bank/{code} (HMAC-signed)
9. Backend → WebhookProcessor.handle():
              a. IP whitelist
              b. HMAC verify
              c. Replay protection (timestamp ±5 min)
              d. find tx by external_id
              e. idempotency check (если status уже финальный — 200)
              f. DB::transaction(): update tx + WalletService::credit()
              g. log в bank_webhook_logs
10. Client ← deep-link return_url, polling /payments/bank/{id}
11. Client → PaymentResultScreen с анимацией зачисления
```

Reconciliation cron `php artisan banks:reconcile` (раз в час) ловит зависшие `pending`/`redirected` транзакции и приводит их в финальный статус через `driver.getStatus()`.

### 3.3. Загрузка контента (контент-менеджер)

```
Editor (Filament)               Backend            FFmpeg Worker      Storage
     │                             │                     │                │
     │── upload mp4 (chunked) ────►│                     │                │
     │                             │ store in temp S3    │                │
     │◄── episode created ─────────│                     │                │
     │                             │                     │                │
     │                             │── dispatch ────────►│                │
     │                             │   TranscodeEpisode  │                │
     │                             │   job (Horizon)     │                │
     │                             │                     │                │
     │                             │                     │── download ────►│
     │                             │                     │◄── mp4 bytes ──│
     │                             │                     │                │
     │                             │                     │ ffmpeg → HLS   │
     │                             │                     │ AES-128 key    │
     │                             │                     │                │
     │                             │                     │── upload ──────►│
     │                             │                     │   240p+480p+720p│
     │                             │                     │   + key.bin     │
     │                             │                     │                │
     │                             │◄── job completed ───│                │
     │                             │ episode.status=ready│                │
     │                             │ episode_streams INS │                │
     │                             │ episode_keys INS    │                │
     │                             │                     │                │
     │ refresh /admin/episodes ───►│                     │                │
     │◄── status=ready ─────────────│                     │                │
```

### 3.4. Auth flow (Phone OTP)

```
Client                            Backend             Telegram-bot / SMS
  │                                  │                       │
  │── POST /auth/otp/request ───────►│                       │
  │   { phone: "+992...." }          │                       │
  │                                  │ rate-limit per IP     │
  │                                  │ generate 6-digit OTP  │
  │                                  │ store in Redis (5m)   │
  │                                  │── send via ──────────►│
  │                                  │   OtpSenderInterface  │
  │◄── { sent: true } ────────────────│                       │
  │                                  │                       │
  │  user receives OTP               │                       │
  │                                  │                       │
  │── POST /auth/otp/verify ────────►│                       │
  │   { phone, code }                │                       │
  │                                  │ check Redis           │
  │                                  │ create or get user    │
  │                                  │ create wallet if new  │
  │                                  │ issue Sanctum token   │
  │◄── { user, wallet, token } ──────│                       │
  │                                  │                       │
  │  store token in secure_storage   │                       │
```

---

## 4. Cross-cutting concerns

### 4.1. Errors

- **Backend:** custom `App\Exceptions\AppException(code, message, ?cause)`. Все бизнес-ошибки — наследники. Хендлер в `app/Exceptions/Handler.php` превращает их в JSON `{error: {code, message}}`. Никаких `throw 'string';`.
- **Mobile:** sealed-классы `Result.success | Result.failure` либо `AsyncValue` от Riverpod. Никаких `try/catch` в виджетах — только в репозиториях / usecase'ах.

### 4.2. Logging / Monitoring

| Слой | Инструмент | Что логируем |
|---|---|---|
| Backend errors | Sentry (sentry-laravel) | unhandled exceptions, slow queries, jobs failures |
| Backend events | Stream logs в storage/logs + Better Stack Free | structured JSON, 14-day retention |
| Backend APM | Laravel Pulse | request duration, queue lag, cache hit rate |
| Mobile errors | Sentry (sentry_flutter) | crashes, network errors, custom events |
| Mobile analytics | Firebase Analytics | screen_view, episode_play, unlock_attempt, и т.д. (см. [`tz.md` §16](./tz.md)) |
| Webhook audit | `bank_webhook_logs` + `iap_webhook_logs` (БД) | каждый callback с raw payload и signature_valid |
| Stream access | `stream_access_logs` (БД) | manifest, segment, license запросы для anomaly detection |
| Audit trail | `audit_logs` (БД) | все ручные действия админа с финансовым эффектом |

### 4.3. Idempotency

Обязательно для:
- `POST /api/v1/payments/bank/initiate` — header `X-Idempotency-Key` или body field
- `POST /api/v1/iap/verify` — natural key `(platform, purchase_token)`
- `POST /api/v1/episodes/{id}/unlock` — natural key `(user_id, episode_id)`
- Все `/webhooks/*` — natural key `(provider_code, external_id)` или `(provider, notification_id)`

Хранение: либо Redis (TTL 24h), либо БД с UNIQUE constraint.

### 4.4. Type contracts

OpenAPI 3.1 spec в `docs/api.md` (генерируется autoматически). Codegen клиент через `openapi_generator` для Flutter (Retrofit-стиль). Это значит что для добавления нового endpoint — правка в одном месте (OpenAPI) → пере-генерация клиента → типы на mobile обновляются.

### 4.5. Environment / Secrets

| Где | Что |
|---|---|
| `.env` (gitignored) | local secrets |
| `.env.example` (committed) | шаблон с safe-defaults |
| Doppler / AWS Secrets Manager (prod) | production secrets |
| `bank_payment_providers` table (encrypted) | banking API keys, HMAC secrets, webhook secrets — через `Crypt::encryptString` (Laravel APP_KEY) |
| GitHub Secrets | CI tokens (`SENTRY_AUTH_TOKEN`, `FIREBASE_TOKEN`, `DOCKER_HUB_TOKEN`) |

---

## 5. Архитектурные решения (ADR)

Документируются в `docs/decisions/` по шаблону Michael Nygard. Текущие:

| # | ADR | Статус |
|---|---|---|
| [0001](./decisions/0001-roadmap-v1-vs-v2.md) | Roadmap v1 → v2 (vibe-coding оптимизация) | принят |

**Когда писать ADR:**
- Выбор тех.стека (БД, очереди, CDN)
- Введение нового внешнего сервиса (новый банк, новый CDN, новый payment provider)
- Изменение архитектурной схемы (e.g., переход на event-sourcing для wallet)
- Trade-off с долгосрочными последствиями (e.g., level 6 PHPStan вместо 8 на старте)

**Когда НЕ писать ADR:** мелкие фиксы, переименования, обычные feature commits.

---

## 6. Что не покрыто этим документом

- Полная схема БД (34 таблицы) — [`tz.md` §5](./tz.md)
- Точные API endpoints с примерами запросов/ответов — [`tz.md` §6](./tz.md)
- Дизайн-система и UX flows — [`tz.md` §7](./tz.md)
- Список конкретных rate-limit'ов и лимитов — [`tz.md` §11](./tz.md), [`CLAUDE.md` §8.2](../CLAUDE.md)
- Подробные правила для Claude Code — [`CLAUDE.md` §16](../CLAUDE.md)

---

**Дата последнего обновления:** 30 апреля 2026.
