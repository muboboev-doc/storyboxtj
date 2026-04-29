# Техническое задание: клон StoryBox

**Проект:** OTT-приложение коротких драм и веб-сериалов (аналог StoryBox / ReelShort / DramaBox)
**Платформы:** Android, iOS, Web, Admin Panel
**Стек:** Flutter (клиент) + Laravel/PHP (бэкенд + админка)
**Дата:** апрель 2026
**Версия документа:** 1.2

---

## 1. Цели и общее описание

Разработать полнофункциональное стриминговое приложение для коротких вертикальных видео-драм и веб-сериалов с эпизодической структурой контента. Пользователь смотрит сериал в формате коротких эпизодов (60–120 секунд), первые несколько эпизодов бесплатные, остальные разблокируются за коины, по VIP-подписке или просмотром рекламы.

Ключевые свойства продукта:

- Вертикальный TikTok-подобный плеер с полноэкранным проигрыванием эпизодов и свайпом вверх/вниз для перехода между эпизодами.
- Эпизодическая модель контента: сериал → сезон (опционально) → эпизод.
- Множественная монетизация: коины (IAP + локальные банки), VIP-подписка, rewarded ads, реферальная программа.
- **Локальные платежи** через банки Таджикистана: Алиф Банк, Эсхата Банк, Душанбе Сити Банк (для пользователей без международных карт).
- Мультиязычность: русский, английский, таджикский, узбекский, казахский, киргизский (расширяется через админку).
- Многоуровневая защита контента: DRM (Widevine/FairPlay), AES-128 HLS, signed URLs, запрет скриншотов и записи экрана, watermark.
- Кросс-платформенность: один Flutter-кодовая база на Android/iOS/Web.
- Полная админ-панель для контент-менеджмента, модерации, биллинга и аналитики.
- Поддержка облачных хранилищ: AWS S3, DigitalOcean Spaces, локальное хранилище.
- Push-уведомления для удержания.

---

## 2. Целевая аудитория и юз-кейсы

Аудитория: молодёжь 18–35 лет в Центральной Азии (Таджикистан, Узбекистан, Казахстан, Киргизия) и русскоязычная аудитория. Сценарии использования: разовый просмотр серии в перерыве, ежедневный «просмотр одного эпизода», запой по выходным с покупкой коинов.

Главные юз-кейсы:

- Открытие приложения → лента «Для тебя» → свайп по вертикали → автостарт следующего эпизода.
- Бесплатный просмотр первых 3–5 эпизодов сериала, затем экран разблокировки.
- Покупка пакета коинов через Google Play / Apple StoreKit (международная аудитория) или через локальный банк (Tajik audience).
- Оформление VIP-подписки.
- Просмотр рекламы для разблокировки одного эпизода.
- Приглашение друга по реферальной ссылке.

---

## 3. Технологический стек

**Мобильное приложение (Android, iOS, Web):**

- Flutter 3.22+, Dart 3.x
- Riverpod 2.x (state management)
- `better_player` / `video_player` для HLS + DRM
- `dio` + `retrofit` (HTTP)
- `hive` / `shared_preferences` (storage)
- `firebase_messaging` (push)
- `in_app_purchase` (Google Play Billing v6, StoreKit 2)
- `flutter_inappwebview` (для WebView с локальными платежами)
- `google_mobile_ads` (AdMob rewarded)
- `flutter_localizations` + `intl`, ARB-файлы (6 языков)
- Firebase Analytics
- `flutter_windowmanager` (FLAG_SECURE), нативные каналы для iOS UIScreen
- `dio_certificate_pinning`, `flutter_jailbreak_detection`

**Бэкенд (API + Admin Panel):**

- PHP 8.2+
- Laravel 11.x
- MySQL 8.0
- Redis (кэш, очереди, rate limiting)
- Laravel Sanctum (auth)
- Laravel Horizon (очереди)
- Filament 3.x (админка)
- Spatie Laravel Permission, Spatie Translatable
- FFmpeg (через `php-ffmpeg`) — транскодинг + AES-128
- HTTP-клиенты для банков: Guzzle с per-bank OAuth/HMAC

**Инфраструктура:**

- Хранилище: AWS S3 / DigitalOcean Spaces / локальное
- CDN: CloudFront / Cloudflare Stream / BunnyCDN
- Транскодинг: FFmpeg-воркер
- Docker + docker-compose
- nginx + php-fpm + supervisor
- Sentry, Laravel Pulse
- DRM: Widevine modular license proxy + FairPlay key server

---

## 4. Архитектурная схема

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

API маршруты разделены: `/api/v1/*` — мобильный API, `/admin/*` — Filament, `/license/*` — DRM, `/webhooks/bank/*` — callback от банков, `/payments/*` — платёжный orchestrator.

---

## 5. Модель данных (ER-схема)

### 5.1. users
```
id, name, email unique nullable, phone unique nullable, password nullable,
avatar_url, locale default 'ru', country_code, referral_code unique,
referred_by_user_id, status enum('active','blocked','deleted'),
last_seen_at, created_at, updated_at
```

### 5.2. user_social_accounts
```
id, user_id, provider enum('google','apple','facebook'), provider_uid, created_at
unique(provider, provider_uid)
```

### 5.3. wallets
```
id, user_id unique, coins_balance, bonus_coins_balance,
total_earned, total_spent, updated_at
```

### 5.4. wallet_transactions
```
id, wallet_id, user_id, type, direction, amount_coins, balance_after,
related_id, related_type, description, created_at
type: enum('purchase_iap','purchase_bank','reward_ad','referral_bonus',
           'signup_bonus','daily_checkin','unlock_episode','admin_adjust',
           'vip_grant','refund')
```

### 5.5. iap_products (Google/Apple SKU)
```
id, sku unique, platform enum('android','ios','web'),
type enum('coins','vip_subscription'),
coins_amount, bonus_coins, vip_plan_id nullable,
price_usd, position, is_active
```

### 5.6. iap_transactions
```
id, user_id, product_id, platform, purchase_token, order_id,
status enum('pending','verified','failed','refunded'),
amount_usd, coins_credited, verified_at, raw_payload(json),
created_at, updated_at
```

### 5.7. vip_plans
```
id, name, duration_days, price_usd, price_tjs (для локальных платежей),
sku_android, sku_ios, benefits(json), position, is_active
```

### 5.8. user_subscriptions
```
id, user_id, plan_id,
status enum('active','cancelled','expired','grace_period'),
started_at, expires_at, auto_renew,
platform enum('android','ios','web','bank','admin_grant'),
provider_subscription_id nullable, payment_provider nullable
```

### 5.9. genres / 5.10. series / 5.11. series_genres / 5.12. episodes / 5.13. episode_streams
*(Без изменений — см. v1.1)*

### 5.14. episode_keys (DRM-ключи)
```
id, episode_id, key_id (uuid), content_key (encrypted),
algorithm enum('aes-128-cbc','widevine','fairplay'),
created_at, rotated_at
```

### 5.15. user_episode_unlocks / 5.16. user_watch_history / 5.17. user_favorites / 5.18. user_likes / 5.19. comments
*(Без изменений)*

### 5.20. ads_config / 5.21. ad_views / 5.22. referrals / 5.23. daily_checkins
*(Без изменений)*

### 5.24. notifications / 5.25. device_tokens
*(Без изменений)*

### 5.26. stream_access_logs (логи аномалий)
```
id, user_id, device_id, episode_id, ip, user_agent, country,
action enum('manifest','segment','license'), created_at
```

### 5.27. bank_payment_providers (НОВАЯ — конфигурация банков)
```
id
code: enum('alif','eskhata','dcbank','korti_milli')
name (json translatable)              // {"ru":"Алиф Банк","en":"Alif Bank","tg":"Бонки Алиф"}
logo_url
country_code default 'TJ'
currency default 'TJS'                // сомони
api_base_url                          // боевой и тестовый URLs в config
merchant_id (encrypted)
api_key (encrypted)
secret_key (encrypted)                // для HMAC подписи
webhook_secret (encrypted)            // для проверки callback
supports_methods: json                // ["card","qr","wallet","mobile_money"]
min_amount_tjs decimal default 5
max_amount_tjs decimal default 5000
fee_percent decimal default 0
fee_fixed decimal default 0
position int
is_active boolean default false
is_test_mode boolean default true
created_at, updated_at
```

### 5.28. bank_products (НОВАЯ — пакеты коинов в TJS)
```
id, provider_id FK->bank_payment_providers
type enum('coins','vip_subscription')
coins_amount nullable
bonus_coins nullable
vip_plan_id nullable
price_tjs decimal
title (json translatable)             // например, "100 коинов + 20 бонус"
position
is_active
```

### 5.29. bank_transactions (НОВАЯ — транзакции банковских платежей)
```
id
user_id FK
provider_id FK->bank_payment_providers
provider_code: string                 // дублируем для удобства запросов
bank_product_id nullable FK->bank_products
amount_tjs decimal
amount_coins int                      // сколько коинов будет начислено
currency string default 'TJS'
method enum('card','qr','wallet','transfer')
status: enum('pending','redirected','authorized','succeeded',
             'failed','cancelled','expired','refunded')
external_id string nullable           // ID транзакции у банка
external_invoice_id string nullable
checkout_url string nullable          // URL для редиректа клиента
deep_link string nullable             // для Alif Mobi и т.д.
idempotency_key string unique         // UUID, генерируется клиентом
ip_address string
user_agent string
device_id string
return_url string
webhook_received_at timestamp nullable
authorized_at timestamp nullable
succeeded_at timestamp nullable
failed_at timestamp nullable
failure_reason string nullable
metadata json                         // payload банка
expires_at timestamp                  // обычно +30 минут
created_at, updated_at
index(user_id, status)
index(external_id, provider_id)
```

### 5.30. bank_webhook_logs (НОВАЯ — для аудита и отладки)
```
id
provider_id FK
provider_code string
ip string
headers json
payload json
signature string
signature_valid boolean
matched_transaction_id nullable FK->bank_transactions
processing_status enum('received','processed','rejected','duplicate')
processing_error text nullable
created_at
```

### 5.31. settings / 5.32. languages (6 языков) / 5.33. translations / 5.34. audit_logs
*(Без изменений)*

---

## 6. REST API (мобильный клиент)

Базовый URL: `https://api.example.com/api/v1`. Аутентификация: `Authorization: Bearer <sanctum_token>`.

### 6.1. Аутентификация и пользователь
*(Без изменений — см. v1.1)*

### 6.2. Контент
*(Без изменений)*

### 6.3. Разблокировка эпизодов
*(Без изменений)*

### 6.4. Кошелёк и платежи (универсальный)
```
GET    /wallet
GET    /wallet/transactions?page=
GET    /payments/methods?country=                // возвращает доступные методы:
                                                  // [{type:"google_play",...},
                                                  //  {type:"apple_iap",...},
                                                  //  {type:"bank",code:"alif",...}]
GET    /iap/products?platform=                   // SKU для Google/Apple
POST   /iap/verify                               { platform, product_id, purchase_token, order_id }
GET    /vip/plans
GET    /vip/status
POST   /vip/cancel
```

### 6.5. Локальные банковские платежи (НОВЫЕ эндпоинты)
```
GET    /payments/banks                           // список активных банков для страны юзера
                                                  // (с логотипом, минимум, фи, методами)
GET    /payments/banks/{code}/products           // пакеты коинов в TJS у конкретного банка

POST   /payments/bank/initiate
       Body: {
         provider_code: "alif",
         product_type: "coins",            // или "vip_subscription"
         bank_product_id: 5,                // либо vip_plan_id
         method: "card",                    // "card","qr","wallet"
         return_url: "storybox://payment/return",  // deep-link обратно в приложение
         idempotency_key: "uuid"
       }
       Response: {
         transaction_id: 123,
         status: "pending",
         checkout_url: "https://merchant.alif.tj/checkout/...",
         deep_link: "alifmobi://pay?token=...",   // если method=wallet
         expires_at: "2026-04-29T12:30:00Z"
       }

GET    /payments/bank/{transaction_id}           // получить актуальный статус (polling)
POST   /payments/bank/{transaction_id}/cancel    // отмена pending транзакции

GET    /me/payments/history?provider=&status=    // история всех платежей (IAP + банк)
```

### 6.6. Webhook эндпоинты для банков (server-to-server, без юзер-токена)
```
POST   /webhooks/bank/alif                       // Alif Bank merchant callback
POST   /webhooks/bank/eskhata                    // Eskhata Bank
POST   /webhooks/bank/dcbank                     // Dushanbe City Bank
POST   /webhooks/bank/korti-milli                // если будет
```

Все webhook-эндпоинты:
- Проверяют HMAC-подпись из заголовка (`X-Signature`, `X-Alif-Signature` и т.п.)
- Проверяют source IP против whitelist банка
- Идемпотентны по `external_id` транзакции
- Записывают каждый callback в `bank_webhook_logs`

### 6.7. Реклама и бонусы / 6.8. Комментарии / 6.9. Поиск / 6.10. Уведомления / 6.11. Системные / 6.12. DRM
*(Без изменений)*

Rate-limits: для `/payments/bank/initiate` — 5 rpm на юзера, 30 rpm на IP. Webhook-эндпоинты — 600 rpm на IP-источник.

---

## 7. Экраны мобильного приложения

### 7.1.–7.3.
*(Без изменений)*

### 7.4. Платежи и монетизация (ОБНОВЛЕНО)

- **Coins Store** — пакеты коинов. Сверху сегмент-контрол: «Google Play / Apple» (для международных карт) и «Локальные банки» (Алиф, Эсхата, ДС Банк) — переключение методов. Список пакетов с ценами в локальной валюте.
  - При выборе пакета через банк → показ списка банков → выбор метода (Card / QR / Wallet) → инициация платежа.
- **Bank Payment Sheet** — модалка с выбором банка, отображает логотипы, минимум, комиссию, поддерживаемые методы.
- **Bank Checkout WebView** — открывает `checkout_url` в `flutter_inappwebview`. После успеха или отмены — `return_url` (deep-link `storybox://payment/return?transaction_id=X`) возвращает в приложение, клиент опрашивает `/payments/bank/{id}` до получения финального статуса.
- **Alif Mobi Deep-link Flow** — для метода wallet: открытие `alifmobi://pay?...` через `url_launcher`, fallback на checkout_url если приложение не установлено.
- **VIP Subscription** — два набора планов в зависимости от выбора метода. Для банковских планов авто-продление обрабатывается через recurring tokenization (если банк поддерживает) или ручное продление с напоминанием.
- **Payment Result Screen** — итог: success (с анимацией зачисления коинов), pending (с кнопкой «Проверить статус»), failure (с причиной и retry).
- **Payment History** — список всех транзакций с типом (IAP/Bank), суммой, статусом.

### 7.5.–7.6.
*(Без изменений)*

---

## 8. Веб-версия

Flutter Web с PWA. Различия:

- Адаптивный layout, сайдбар на десктопе.
- Плеер 16:9 fullscreen.
- IAP: на вебе — два пути:
  - Stripe Checkout / PayPal — для международных карт.
  - **Локальные банки Таджикистана** через тот же `/payments/bank/initiate` API, redirect на страницу банка с возвратом на `https://example.com/payment/return`.
- DRM: Widevine через EME.
- Локальные платежи на вебе работают свободно (нет ограничений магазинов).

---

## 9. Админ-панель (Filament 3)

### 9.1. Дашборд (ОБНОВЛЕНО)
Виджеты:
- DAU/MAU
- Revenue today/week/month с разбивкой: Google / Apple / **Bank (Alif/Eskhata/DCBank)**
- Top series, Top spenders
- FFmpeg queue status
- Storage usage
- Anomaly alerts
- **Bank webhook health** (latency, error rate per provider)

### 9.2. Контент-менеджмент / 9.3. Пользователи / 9.4. Биллинг (ОБНОВЛЕНО)
- IAP Products
- VIP Plans (с двумя ценами: USD и TJS)
- IAP Transactions
- **Bank Transactions** — список с фильтрами по банку, статусу, юзеру; кнопка ручной reconciliation, возврат, ручное подтверждение pending.
- **Bank Webhook Logs** — журнал callback'ов с raw payload и валидностью подписи.
- Возвраты с авто-списанием коинов.

### 9.5. Монетизация / 9.6. Защита контента
*(Без изменений + добавлены счётчики аномальных платежей)*

### 9.7. Локальные банки (НОВЫЙ раздел админки)
Управление `bank_payment_providers`:
- Список банков с переключателем активности и тестового режима.
- Форма редактирования: API URL, merchant_id, ключи (зашифрованы при сохранении), HMAC secret, webhook secret, IP whitelist.
- Кнопка «Test connection» — отправляет ping на API банка с текущими credentials.
- Управление `bank_products` (пакетов в TJS) для каждого банка.
- Аналитика по банку: успешные / failed / cancelled / refunded, сумма за период.
- Reconciliation tool: загрузить файл выписки от банка → сверка с `bank_transactions` → отчёт о расхождениях.

### 9.8. Модерация / 9.9. Уведомления / 9.10. Настройки / 9.11. Роли и доступы
*(Без изменений)*

---

## 10. Монетизация: детали потоков

### 10.1. Покупка коинов через Google/Apple IAP
*(Без изменений — см. v1.1)*

### 10.2. VIP-подписка через Google/Apple
*(Без изменений)*

### 10.3. Покупка коинов через банк Таджикистана (НОВЫЙ поток)

**Сценарий A: Карточная оплата (Card via merchant gateway)**

1. Пользователь на экране Coins Store выбирает «Локальные банки» → банк (например, Алиф) → пакет.
2. Клиент → `POST /payments/bank/initiate` с `provider_code:"alif"`, `method:"card"`, `idempotency_key`.
3. Бэк создаёт `bank_transactions(status=pending)`, генерирует `external_invoice_id`, через `App\Services\Banks\AlifBankService` инициирует мерчант-сессию (POST на API банка с HMAC-подписью).
4. Банк возвращает `payment_session_id` + `checkout_url`.
5. Бэк сохраняет `external_id`, `checkout_url`, статус `redirected`. Отдаёт URL клиенту.
6. Клиент открывает `checkout_url` в `flutter_inappwebview` (либо в Custom Tabs / SafariViewController).
7. Юзер вводит данные карты, проходит 3DS на стороне банка.
8. После успеха банк делает webhook → `POST /webhooks/bank/alif` с подписью и payload `{external_id, status:"succeeded", amount, ...}`.
9. Бэк проверяет подпись (HMAC-SHA256 с `webhook_secret`), находит транзакцию по `external_id`, обновляет статус. Если впервые → начисляет коины через `WalletService::credit()`, пишет `wallet_transactions(type=purchase_bank)`.
10. Параллельно юзер возвращается через `return_url` в приложение, клиент опрашивает `/payments/bank/{id}` и получает `succeeded`. Показывает success-экран.
11. Reconciliation: ежедневный cron сверяет `pending`/`redirected` транзакции старше 1 часа со статусом у банка через API; если банк подтверждает успех — догоняет webhook; если timeout — переводит в `expired`.

**Сценарий B: QR-оплата**

1. Аналогично шагам 1–5, но `method:"qr"`. Банк возвращает QR-payload (строку для генерации QR на клиенте).
2. Клиент рендерит QR через пакет `qr_flutter`. Юзер сканирует его в приложении банка (Алиф Мобайл и т.п.) и подтверждает оплату.
3. Webhook от банка → как в шагах 8–10.

**Сценарий C: Wallet (Alif Mobi deep-link)**

1. Аналогично, но `method:"wallet"`. Бэк возвращает `deep_link: "alifmobi://pay?token=..."`.
2. Клиент через `url_launcher.launchUrl(deep_link, mode:LaunchMode.externalApplication)` открывает Alif Mobi.
3. Юзер видит готовую форму оплаты в приложении банка, подтверждает биометрией.
4. Alif Mobi делает callback на бэк банка, тот → webhook → бэк StoryBox.
5. Юзер возвращается через deep-link `storybox://payment/return?transaction_id=X` (либо переключает приложение вручную).

### 10.4. VIP-подписка через банк (recurring)

Не все банки Таджикистана поддерживают токенизацию для рекуррентных платежей. Стратегия:
- **Если банк поддерживает рекуррент:** при первой оплате сохраняем `card_token` в `user_subscriptions.provider_subscription_id`, дальше cron раз в сутки проверяет истекающие подписки и инициирует автосписание через API банка.
- **Если не поддерживает:** делаем подписку с напоминанием — за 3 дня до истечения push «Продлите VIP», юзер заходит в приложение и проходит платёж заново. UI показывает «Ручное продление».
- В админке у `vip_plans` флаг `bank_recurring_supported`.

### 10.5. Rewarded Ads / 10.6. Реферальная программа / 10.7. Daily Check-in
*(Без изменений)*

---

## 11. Безопасность

*(Существующие пункты v1.1 + добавлено:)*

- **Платёжные ключи банков** хранятся в `bank_payment_providers` зашифрованными через `Crypt::encryptString` (Laravel APP_KEY). На фронте никогда не отдаются.
- **HMAC-SHA256 подпись webhook** обязательна для всех `/webhooks/bank/*`. Невалидные подписи → 401 + лог в `bank_webhook_logs(processing_status='rejected')`.
- **IP whitelist** на webhook-маршрутах per-provider (настраивается через `bank_payment_providers.allowed_ips` json).
- **Idempotency keys** обязательны для `POST /payments/bank/initiate` — защита от дублей при повторной отправке клиентом.
- **TLS pinning** для исходящих запросов к банкам (если их CA нестабильны).
- **PCI DSS scope minimization:** мы НЕ принимаем CVV и номер карты в нашем backend. Карточные данные вводятся ТОЛЬКО на стороне банка (на их checkout-странице или в их WebView). Это вынесено в рекомендацию для архитектора.
- **Audit log:** все ручные действия админа (refund, ручное подтверждение, выдача коинов) с финансовым эффектом.

---

## 12. Защита контента и борьба с пиратством
*(Без изменений — см. v1.1; тот же раздел про DRM, FLAG_SECURE, watermark и т.д.)*

### 12.1. Стриминг и DRM

- Видео раздаётся **только через HLS с шифрованием AES-128** (минимум) и **DRM (Widevine L3 для Android, FairPlay для iOS, Widevine для Web/Chrome)**.
- Никаких прямых `.mp4` файлов.
- Сегменты — signed URLs с TTL 3–5 минут, привязанные к user_id+device_id.
- Лицензионный сервер `license_proxy` сверяет токены и эпизоды.
- Web — EME (Widevine).
- Root/jailbreak detect → отказ премиум-плеера.

### 12.2. Запрет скриншотов и записи экрана

**Android:** `WindowManager.FLAG_SECURE` на экранах плеера и платежей через `flutter_windowmanager`. MediaProjectionManager-детектор (Android 14+).

**iOS:** `UIScreen.capturedDidChangeNotification` — пауза при записи. `UIApplication.userDidTakeScreenshotNotification` — лог + предупреждение. AirPlay блокируется через `AVPlayer.allowsExternalPlayback=false`.

**Web:** Widevine EME, отключение правого клика, обнаружение DevTools, watermark.

### 12.3. Запрет скачивания
Нет offline режима, signed URLs с короткой TTL, rate-limit на manifest endpoints, эвристики аномального доступа.

### 12.4. Watermark
Полупрозрачный (alpha 0.08) user_id поверх плеера, позиция меняется каждые 8 секунд.

### 12.5. Защита от mirroring и кастинга
MediaRouter блокировка небезопасных Chromecast, AVPlayer.allowsExternalPlayback=false, HDCP 2.2 для HDMI.

### 12.6. Защита приложения
Обфускация, SSL pinning, Play Integrity, App Attest, anti-debugger.

### 12.7. Серверные меры
`stream_access_logs`, эвристики (>3 IP / >10 device_id), shadow-ban, honeypot-эпизоды, DMCA.

### 12.8. Реализационные требования

| Платформа | Минимум | Полная |
|-----------|---------|--------|
| Android | FLAG_SECURE + AES-128 + signed URLs | + Widevine L1 + Play Integrity |
| iOS | UIScreen наблюдатели + AES-128 + AirPlay блок | + FairPlay + App Attest |
| Web | Widevine EME + signed URLs + watermark | + анти-DevTools |

---

## 13. Локальные платежи: банки Таджикистана (НОВЫЙ РАЗДЕЛ)

### 13.1. Цели и контекст

Часть целевой аудитории (особенно в Таджикистане) не имеет международных карт VISA/Mastercard, привязанных к Google Play или Apple ID. Платежи через локальные банки решают эту проблему и снижают комиссии (Google/Apple удерживают 30%, банковский эквайринг — 1.5–2.5%).

Поддерживаемые провайдеры на старте:

| Код | Банк | Методы оплаты | Особенности |
|-----|------|---------------|-------------|
| `alif` | Алиф Банк (Alif Bank) | Карта, QR, Alif Mobi (wallet) | Современное API, QR через Korti Milli Pay, deep-link в Alif Mobi |
| `eskhata` | Эсхата Банк (Eskhata Bank) | Карта, QR | Один из крупнейших банков, классический эквайринг |
| `dcbank` | Душанбе Сити Банк (Dushanbe City Bank) | Карта, перевод | Локальный банк, мерчант-программа |
| `korti_milli` | Корти Милли (национальная платёжная система) | Карта, QR | Опционально на этапе 2 — общий шлюз для Korti Milli карт |

Точные API-эндпоинты, схемы запросов и SLA каждого банка предоставляются по NDA после подписания мерчант-договора. Архитектура на стороне приложения должна быть провайдеро-нейтральной (Strategy pattern) — новый банк добавляется через одну реализацию интерфейса.

### 13.2. Архитектура (Strategy pattern)

Backend-структура:

```
app/Services/Banks/
├── BankPaymentInterface.php
├── BankPaymentManager.php          // resolve по коду
├── Drivers/
│   ├── AlifBankDriver.php
│   ├── EskhataBankDriver.php
│   └── DushanbeCityBankDriver.php
├── DTOs/
│   ├── PaymentInitRequest.php
│   ├── PaymentInitResponse.php
│   ├── WebhookPayload.php
│   └── ReconciliationItem.php
└── Webhooks/
    ├── AlifWebhookController.php
    ├── EskhataWebhookController.php
    └── DcbankWebhookController.php
```

Интерфейс `BankPaymentInterface`:

```php
interface BankPaymentInterface {
    public function initiate(PaymentInitRequest $req): PaymentInitResponse;
    public function getStatus(string $externalId): PaymentStatus;
    public function cancel(string $externalId): bool;
    public function refund(string $externalId, ?int $amountTjsCents = null): bool;
    public function verifyWebhookSignature(array $headers, string $body): bool;
    public function parseWebhook(string $body): WebhookPayload;
    public function reconcile(\DateTime $from, \DateTime $to): array;
}
```

Каждый драйвер инкапсулирует особенности банка: эндпоинты, метод подписи (HMAC-SHA256 / RSA), формат payload (JSON / XML), маппинг статусов на наш `enum status`.

`BankPaymentManager` резолвит драйвер из настройки `bank_payment_providers.code` и кеширует учётные данные через Redis на 5 минут.

### 13.3. Поток инициации платежа (детально)

```
Client                Backend              Bank API           Webhook
  │                      │                    │                  │
  │── POST /payments/    │                    │                  │
  │   bank/initiate      │                    │                  │
  │   (idempotency_key)  │                    │                  │
  │─────────────────────►│                    │                  │
  │                      │ create bank_       │                  │
  │                      │ transactions       │                  │
  │                      │ (status=pending)   │                  │
  │                      │                    │                  │
  │                      │── HMAC-signed ────►│                  │
  │                      │   merchant init    │                  │
  │                      │                    │                  │
  │                      │◄── checkout_url ───│                  │
  │                      │   external_id      │                  │
  │                      │                    │                  │
  │                      │ update tx          │                  │
  │                      │ (status=redirected)│                  │
  │◄─ checkout_url ──────│                    │                  │
  │                      │                    │                  │
  │── opens WebView ────────────────────────►│                  │
  │                      │                    │                  │
  │   user pays / 3DS / QR scan / wallet     │                  │
  │                      │                    │                  │
  │                      │                    │── webhook ──────►│
  │                      │                    │   (HMAC signed)  │
  │                      │◄── verify sig ─────────────────────────│
  │                      │   match by external_id                │
  │                      │   credit wallet                       │
  │                      │   wallet_tx(type=purchase_bank)       │
  │                      │   tx.status=succeeded                 │
  │                      │                                       │
  │── return_url ───────►│                    │                  │
  │   (deep-link)        │                    │                  │
  │                      │                    │                  │
  │── poll /payments/    │                    │                  │
  │   bank/{id} ─────────►│                    │                  │
  │◄── succeeded ────────│                    │                  │
  │                      │                    │                  │
  │   show success +     │                    │                  │
  │   updated balance    │                    │                  │
```

### 13.4. Webhook handler (общий паттерн)

```php
class WebhookProcessor {
    public function handle(string $providerCode, Request $request): JsonResponse {
        $driver = $this->manager->driver($providerCode);
        $body = $request->getContent();

        // 1. Лог сырого payload
        $log = BankWebhookLog::create([
            'provider_code' => $providerCode,
            'ip' => $request->ip(),
            'headers' => $request->headers->all(),
            'payload' => json_decode($body, true),
            'processing_status' => 'received',
        ]);

        // 2. IP whitelist
        if (!$this->ipWhitelistOk($providerCode, $request->ip())) {
            $log->update(['processing_status' => 'rejected', 'processing_error' => 'IP not in whitelist']);
            return response()->json(['ok' => false], 403);
        }

        // 3. Подпись
        if (!$driver->verifyWebhookSignature($request->headers->all(), $body)) {
            $log->update(['processing_status' => 'rejected', 'processing_error' => 'Bad signature']);
            return response()->json(['ok' => false], 401);
        }

        // 4. Парсинг + идемпотентность
        $payload = $driver->parseWebhook($body);
        $tx = BankTransaction::where('external_id', $payload->externalId)
            ->where('provider_code', $providerCode)->first();
        if (!$tx) {
            $log->update(['processing_status' => 'rejected', 'processing_error' => 'Tx not found']);
            return response()->json(['ok' => false], 404);
        }
        if ($tx->status === 'succeeded' && $payload->status === 'succeeded') {
            $log->update(['processing_status' => 'duplicate', 'matched_transaction_id' => $tx->id]);
            return response()->json(['ok' => true]); // already credited
        }

        // 5. Обработка
        DB::transaction(function () use ($tx, $payload) {
            $tx->update([
                'status' => $payload->status,
                'webhook_received_at' => now(),
                'succeeded_at' => $payload->status === 'succeeded' ? now() : null,
                'metadata' => array_merge($tx->metadata ?? [], $payload->metadata),
            ]);

            if ($payload->status === 'succeeded' && $tx->amount_coins > 0) {
                app(WalletService::class)->credit(
                    userId: $tx->user_id,
                    coins: $tx->amount_coins,
                    type: 'purchase_bank',
                    relatedId: $tx->id,
                    relatedType: BankTransaction::class,
                );
            }
        });

        $log->update(['processing_status' => 'processed', 'matched_transaction_id' => $tx->id]);
        return response()->json(['ok' => true]);
    }
}
```

### 13.5. Reconciliation (сверка)

Ежедневный cron `php artisan banks:reconcile`:

1. Берёт все `bank_transactions` со статусом `pending` или `redirected` старше 1 часа.
2. Для каждой через `$driver->getStatus($externalId)` проверяет реальный статус у банка.
3. Если `succeeded` — догоняет webhook (если он не пришёл) и начисляет коины.
4. Если `failed`/`expired` — переводит локально в соответствующий статус.
5. Если `pending` дольше 24 часов — `expired`.
6. Раз в неделю запускается полный reconciliation через `$driver->reconcile($from, $to)` — выгружает все транзакции у банка за период и сверяет с локальной БД, отправляет отчёт о расхождениях админам в Slack/email.

### 13.6. UI на клиенте (Flutter)

`CoinsStoreScreen` показывает сегмент-контрол `Tab(international, local)`:

- **International** — `iap_products` через `in_app_purchase`. Видим только если у юзера регион/локаль не TJ или если он явно переключился.
- **Local** — `bank_products` через `/payments/banks/products`. По умолчанию для юзеров с `country_code=TJ` или с языком `tg`/`uz`.

После выбора пакета в local-режиме:

1. Боттомшит «Выберите банк» (`BankSelectorSheet`) — список с логотипами, минимум, фи.
2. Боттомшит «Способ оплаты» (`MethodSelectorSheet`) — карта, QR, кошелёк (доступные для выбранного банка).
3. `PaymentApi.initiate(...)` → получение `checkout_url` или `deep_link`.
4. Открытие WebView (`flutter_inappwebview` с whitelisted hosts) или deep-link.
5. По возврату через `return_url` (`storybox://payment/return?tx=X`) — клиент через `app_links` подхватывает диплинк, идёт в `PaymentResultScreen`.
6. `PaymentResultScreen` опрашивает `GET /payments/bank/{id}` каждые 2 секунды до получения финального статуса (max 60 секунд), затем показывает success / failure с CTA.

Стейт-машина клиента:
```
idle → select_bank → select_method → initiating → in_webview / in_wallet
                                                  ↓
                                          waiting_for_webhook
                                                  ↓
                                          succeeded / failed / expired
```

### 13.7. Соответствие политикам магазинов (важно)

Google Play и Apple App Store требуют использовать их billing для покупки in-app digital goods. Локальные банки разрешены при ограничениях:

**Apple App Store:**
- Прямое подключение local-bank checkout в iOS-приложении для покупки коинов **не разрешено** (нарушение Guideline 3.1.1).
- Допустимый паттерн — **«Reader app»**: приложение даёт доступ к контенту, купленному вне приложения. Реализация: на iOS показываем кнопку «Купить на сайте», открываем браузер с веб-страницей `https://example.com/store`, юзер платит через банк там, после возврата в приложение коины подгружаются с бэка.
- Допустимая альтернатива (с июня 2024) — External Link Entitlement в EU/Korea/USA: можно показывать ссылку на внешний платёж с предупреждением. Требует подачу заявки в Apple.

**Google Play:**
- В большинстве стран Google Play Billing обязателен.
- В EU/India/Brazil/Korea доступен User Choice Billing (одобрение нужно).
- Допустимый паттерн — **«Reader-style»**: ссылка на сайт без явной кнопки «купить» в приложении.
- В странах Центральной Азии (включая Таджикистан) Google Play Billing является обязательным для digital goods, но **ChromeOS-режим** и **PWA через TWA** могут обходить это (риск отзыва).

**Рекомендация:** на iOS и Android сборках для App Store / Play Store показывать локальные банки только через WebView с `https://example.com/pay` (Reader-app паттерн), не размещая «Купить» кнопку напрямую в приложении. Либо публиковать APK на стороннем сторе (Galaxy Store, Huawei AppGallery, RuStore) где требований к billing нет.

**Web-версия:** локальные банки работают свободно, без ограничений.

В `config/storybox.php` — флаг `local_payments_in_app_enabled` (по платформам), чтобы быстро переключать поведение в зависимости от региона публикации и решений магазинов.

### 13.8. Реализационные требования

- Каждый банк добавляется через 1 драйвер + 1 webhook controller + admin-resource.
- Полный набор тестов: unit (драйверы — моки HTTP), integration (webhook-обработка с фиктивными подписанными payload).
- Sandbox/test-mode у каждого банка должен быть прокинут через `is_test_mode` флаг в `bank_payment_providers`.
- В `.env` отдельные ключи для prod/sandbox.
- Логи (Sentry) на любую failed транзакцию — алерт в Slack #payments.
- Health-check эндпоинт `/internal/banks/health` — пинг каждого банка.

---

## 14. Локализация и интернационализация

Поддерживаемые языки на старте:

| Код | Язык | Локаль | Письменность |
|-----|------|--------|--------------|
| ru | Русский | `ru` | Кириллица |
| en | English | `en` | Латиница |
| tg | Тоҷикӣ (таджикский) | `tg` | Кириллица |
| uz | Oʻzbekcha (узбекский) | `uz` | Латиница (`uz-Cyrl` опционально) |
| kk | Қазақша (казахский) | `kk` | Кириллица |
| ky | Кыргызча (киргизский) | `ky` | Кириллица |

Технические требования:

- ARB-файлы Flutter (`app_ru.arb`, `app_en.arb`, `app_tg.arb`, `app_uz.arb`, `app_kk.arb`, `app_ky.arb`); `flutter gen-l10n`.
- Контентные поля — JSON-колонки через Spatie Translatable (6 языков).
- Горячее обновление через `/translations/{locale}` с кэшем по `etag`.
- Auto-detect локали при первом запуске, fallback на `ru`.
- Форматы дат, чисел и валют (TJS, RUB, USD) через `intl`.
- Отдельные строки локализации для платёжных экранов и названий банков (json в `bank_payment_providers.name`).

---

## 15. Push-уведомления

FCM. Сценарии:

- Новый эпизод в избранном.
- Промо.
- Реферал получил награду.
- VIP истекает через 3 дня.
- Возврат через 7 дней неактивности.
- Подозрительный доступ.
- **Платёжные:** `payment_succeeded` / `payment_failed` / `payment_pending_too_long` (если webhook не пришёл за 10 минут).
- **VIP recurring:** `vip_will_renew_in_3_days`, `vip_renewed`, `vip_renewal_failed_action_required` (для банков без рекуррента).

---

## 16. Аналитика

Firebase Analytics + кастомные события на бэк:

- `app_open`, `screen_view`
- `episode_play/complete/abandon`
- `unlock_attempt/success`
- `iap_initiated/completed/failed`
- **`bank_payment_initiated`** (с `provider_code`, `method`)
- **`bank_payment_succeeded/failed/cancelled`**
- `ad_shown`, `ad_rewarded`
- `share`, `favorite_added`, `comment_posted`
- `vip_subscribed/cancelled`
- `screenshot_attempt`, `screen_record_detected`
- `drm_license_failure`

Дашборд админки: воронка платежа (initiated → redirected → succeeded), conversion rate per provider, средний чек, drop-off на стадии 3DS.

---

## 17. Этапы разработки (Roadmap)

### Этап 0: подготовка (1 неделя)
Репозиторий, CI/CD, Docker, Laravel и Flutter, дизайн-система.

### Этап 1: бэкенд core (3 недели)
Миграции, аутентификация, профиль, кошелёк, CRUD контента через Filament, хранилища, FFmpeg-воркер, базовые эндпоинты.

### Этап 2: мобильный клиент MVP (4 недели)
Авторизация, онбординг, главный экран, каталог, Series Detail, Vertical Player, Profile, Settings, Language switcher (6 языков).

### Этап 3: монетизация — IAP (3 недели)
Google Play / Apple Store IAP + серверная верификация. Coins Store + Wallet UI. VIP. Rewarded Ads + SSV. Daily Check-in + Referrals. Unlock-флоу.

### Этап 4: монетизация — банки Таджикистана (3 недели, НОВЫЙ ЭТАП)
- Миграции `bank_payment_providers`, `bank_products`, `bank_transactions`, `bank_webhook_logs`.
- `BankPaymentInterface` + `BankPaymentManager`.
- Драйверы: `AlifBankDriver`, `EskhataBankDriver`, `DushanbeCityBankDriver` — каждый по 4–5 дней с тестированием в sandbox.
- Webhook-контроллеры с HMAC-проверкой и IP whitelist.
- Reconciliation cron.
- Admin-резерч ресурс «Local Banks».
- Flutter UI: `BankSelectorSheet`, `MethodSelectorSheet`, `BankCheckoutWebView`, `PaymentResultScreen`.
- Reader-app паттерн на iOS (отдельный билд-флавор для App Store).

### Этап 5: фичи удержания (2 недели)
Push-уведомления, комментарии, лайки, избранное, история, search, recommendations.

### Этап 6: веб-версия (2 недели)
Flutter Web + PWA, Stripe + локальные банки на вебе (без ограничений), SEO.

### Этап 7: админка финал (1 неделя)
Дашборды, audit log, переводы, broadcast, reconciliation tools.

### Этап 8: защита контента (2–3 недели)
DRM (Widevine/FairPlay), AES-128, signed URLs, FLAG_SECURE, watermark, SSL pinning, Play Integrity, App Attest.

### Этап 9: тестирование, оптимизация, релиз (2 недели)
Тесты IAP, банков, unlock, ad-reward, license proxy. integration_test Flutter с моками всех банков. Нагрузка. Подготовка магазинов и магазинов-альтернатив.

**Итого:** ~23–25 недель (~5.5 месяцев) для команды из 1 backend, 1 Flutter dev, 0.5 designer, 0.5 QA. Можно ужать до ~16–17 недель параллельной работой 2 backend + 2 Flutter.

---

## 18. Структура репозиториев

```
storybox-clone/
├── backend/                          # Laravel
│   ├── app/
│   │   ├── Http/Controllers/Api/V1/
│   │   ├── Http/Controllers/License/
│   │   ├── Http/Controllers/Webhooks/Banks/      # alif, eskhata, dcbank
│   │   ├── Http/Resources/
│   │   ├── Models/
│   │   ├── Services/
│   │   │   ├── IapVerifier/
│   │   │   ├── Banks/                            # драйверы, manager, DTO
│   │   │   ├── DrmKeyService.php
│   │   │   ├── SignedUrlService.php
│   │   │   └── WalletService.php
│   │   └── Jobs/                                 # TranscodeEpisode, EncryptHls,
│   │                                             # ReconcileBankTransactions, etc.
│   ├── app/Filament/Resources/                   # включая BankProviderResource
│   ├── database/migrations/
│   ├── routes/api.php
│   ├── routes/license.php
│   ├── routes/webhooks.php
│   └── ...
├── mobile/                           # Flutter
│   ├── lib/
│   │   ├── core/                                 # theme, network, storage, security
│   │   ├── data/
│   │   │   └── payments/
│   │   │       ├── iap_repository.dart
│   │   │       └── bank_payment_repository.dart
│   │   ├── domain/
│   │   ├── presentation/
│   │   │   ├── home/
│   │   │   ├── player/                           # SecurePlayerWidget с watermark
│   │   │   ├── auth/
│   │   │   ├── store/
│   │   │   │   ├── coins_store_screen.dart
│   │   │   │   ├── bank_selector_sheet.dart
│   │   │   │   ├── method_selector_sheet.dart
│   │   │   │   ├── bank_checkout_webview.dart
│   │   │   │   └── payment_result_screen.dart
│   │   │   └── ...
│   │   └── main.dart
│   ├── android/app/src/main/
│   ├── ios/Runner/
│   ├── pubspec.yaml
│   └── test/
├── docs/
└── docker-compose.yml
```

---

## 19. Промпты для Claude Code

### 19.1. Инициализация бэкенда
> Создай Laravel 11 в `backend/` с MySQL и Redis. Подключи Sanctum, Spatie Permission, Filament 3, Spatie Translatable, Horizon. Dockerfile + docker-compose.

### 19.2. Миграции БД
> На основе раздела 5 ТЗ сгенерируй все миграции и Eloquent-модели. JSON-translatable через Spatie Translatable. Factories и seeders (5 жанров, 20 сериалов, 30 эпизодов, 3 тестовых банка).

### 19.3. API: аутентификация
> Реализуй раздел 6.1. FormRequests, API Resources. Phone OTP заглушка с интерфейсом OtpSenderInterface. Social через socialite. Тесты в tests/Feature/Auth.

### 19.4. API: контент и плеер
> Реализуй разделы 6.2, 6.3. /home возвращает 5 секций. /episodes/{id} проверяет доступ. EpisodeUnlockService с транзакционным списанием.

### 19.5. Filament Admin
> Сгенерируй ресурсы для всех сущностей раздела 9. Episode-форма с загрузкой видео → TranscodeEpisode job. Series — мультиязычные поля (6 языков).

### 19.6. FFmpeg + AES-128
> Job TranscodeEpisode: HLS 240p/480p/720p, AES-128 шифрование, ключи в episode_keys. Заливка в активный диск.

### 19.7. Платежи: Google/Apple IAP
> IapVerifier с GoogleIapVerifier и AppleIapVerifier. /iap/verify идемпотентен. WalletService::credit. RTDN/Apple Server Notifications для refund.

### 19.8. Платежи: банки Таджикистана (КРИТИЧНЫЙ ПРОМПТ)
> Реализуй раздел 13 ТЗ. Создай:
> 1. Миграции `bank_payment_providers`, `bank_products`, `bank_transactions`, `bank_webhook_logs` — с моделями, factories, seeders (Alif/Eskhata/DCBank в test mode).
> 2. Интерфейс `App\Services\Banks\BankPaymentInterface` со всеми методами (initiate, getStatus, cancel, refund, verifyWebhookSignature, parseWebhook, reconcile).
> 3. `BankPaymentManager` для резолва драйвера по коду (как Laravel Manager pattern).
> 4. Скелеты драйверов `AlifBankDriver`, `EskhataBankDriver`, `DushanbeCityBankDriver` с TODO в местах boring API-вызовов (когда NDA-документация будет — заполним). Каждый драйвер использует Guzzle, кэширует токены через Redis, логирует в Sentry, проверяет HMAC.
> 5. Эндпоинты `/api/v1/payments/banks`, `/payments/banks/{code}/products`, `POST /payments/bank/initiate` (с idempotency), `GET /payments/bank/{id}`, `POST /payments/bank/{id}/cancel`. FormRequests + API Resources.
> 6. Webhook-контроллеры `/webhooks/bank/alif`, `/webhooks/bank/eskhata`, `/webhooks/bank/dcbank` через общий `WebhookProcessor` (паттерн из раздела 13.4).
> 7. Job `ReconcileBankTransactions` (раздел 13.5) — schedule раз в час.
> 8. Filament-ресурс `BankProviderResource` — управление, кнопка «Test connection», аналитика, reconciliation tool.
> 9. Feature-тесты на полный happy path (initiate → webhook → coins credited) и edge cases (duplicate webhook, bad signature, expired tx).

### 19.9. Реклама
> AdSsvController для AdMob SSV. ECDSA-проверка. Начисление коинов или прямая разблокировка эпизода.

### 19.10. Flutter инициализация
> Flutter 3.22 в mobile/. Clean architecture. Стандартные пакеты + flutter_inappwebview, app_links для deep-link.

### 19.11. Flutter: экраны core
> Splash, Onboarding, Auth, Home, Discover, Library, Profile (раздел 7). go_router, тёмная тема.

### 19.12. Flutter: вертикальный плеер
> VerticalPlayerScreen с PageView.builder (snap). better_player с HLS+DRM. Pre-buffering. Overlay UI как TikTok. Watermark с user_id.

### 19.13. Flutter: монетизация IAP
> CoinsStoreScreen (международная вкладка), VipScreen, DailyCheckin, Referrals. in_app_purchase + google_mobile_ads.

### 19.14. Flutter: монетизация банки (КРИТИЧНЫЙ)
> Реализуй UI раздела 13.6.
> 1. Repository `BankPaymentRepository` с методами listBanks, listProducts, initiate, getStatus.
> 2. Provider state-machine на Riverpod: `idle → selectingBank → selectingMethod → initiating → inWebView → polling → succeeded|failed|expired`.
> 3. На `CoinsStoreScreen` добавь сегмент-контрол International / Local. Local показывается по умолчанию для country=TJ или locale=tg.
> 4. `BankSelectorSheet` — карточки банков с логотипом, минимумом, фи.
> 5. `MethodSelectorSheet` — Card / QR / Wallet с иконками.
> 6. `BankCheckoutWebView` через flutter_inappwebview, whitelisted hosts, обработка return_url.
> 7. `PaymentResultScreen` с polling статуса каждые 2 секунды (max 60 сек) и анимацией zachisления коинов.
> 8. Deep-link обработка через app_links для возврата из Alif Mobi.
> 9. Платформенные различия: на iOS production-build (App Store flavor) скрывает «Local» вкладку и вместо этого показывает кнопку «Купить на сайте» которая открывает https://example.com/store в Safari (Reader-app паттерн).
> 10. Локализация всех строк на 6 языков, включая названия банков из API.

### 19.15. Локализация (6 языков)
> ARB-файлы для ru/en/tg/uz/kk/ky в lib/l10n/. flutter gen-l10n. /translations/{locale} с горячим обновлением. Тестирование всех экранов.

### 19.16. Веб
> Flutter Web + PWA. Stripe + локальные банки на вебе (раздел 13). Без ограничений магазинов.

### 19.17. Защита контента
> Реализуй раздел 12. DRM proxy, signed URLs, FLAG_SECURE, UIScreen наблюдатели, watermark, SSL pinning, Play Integrity / App Attest.

### 19.18. Тесты и релиз
> Feature-тесты Laravel: IAP, банки (моки HTTP всех банков, проверка идемпотентности webhook), unlock, ad-reward, license. integration_test Flutter полного happy-path. GitHub Actions: lint, тесты, build APK + IPA + APK для альтернативного стора (без скрытых local-payments).

---

## 20. Критерии приёмки (Acceptance Criteria)

- Все эндпоинты раздела 6 реализованы и покрыты тестами не менее 70% кода.
- Мобильное приложение собирается под Android (release AAB) и iOS (release IPA), проходит политики магазинов.
- Веб-версия — Lighthouse PWA score ≥ 90.
- Админ-панель позволяет полный цикл контента и биллинга.
- IAP-покупка коинов и VIP проходит на боевых аккаунтах с серверной верификацией.
- **Покупка коинов через Алиф Банк, Эсхата Банк и Душанбе Сити Банк проходит в test-mode полностью: инициация → checkout → webhook → начисление коинов.**
- **Webhook от каждого банка с правильной HMAC-подписью обрабатывается успешно; с неправильной — отклоняется (401).**
- **Idempotency на `/payments/bank/initiate` работает: повторный запрос с тем же `idempotency_key` не создаёт дубль транзакции.**
- **Reconciliation cron находит зависшие pending транзакции и приводит их в финальный статус.**
- **Reader-app паттерн на iOS App Store билде: вкладка «Local» скрыта, кнопка ведёт в Safari.**
- Rewarded ad даёт коины только после SSV-callback.
- Все 6 локалей (ru, en, tg, uz, kk, ky) корректно отображаются на всех экранах, включая платёжные.
- На Android попытка скриншота на экране плеера/платежа — чёрный кадр; на iOS включённая запись экрана — пауза плеера.
- Видеоконтент защищён DRM (минимум Widevine L3 / FairPlay) и AES-128.
- Watermark с user_id виден поверх воспроизведения.
- AirPlay/Chromecast блокируется для премиум-контента.
- SSL pinning работает: попытка проксировать трафик через MITM — приложение отказывает в работе.
- Push-уведомления доставляются в течение 30 секунд.
- API выдерживает нагрузку 500 RPS на эндпоинте `/home` (с кэшем).

---

## 21. Не входит в первую версию (out of scope)

- Загрузка контента пользователями (UGC).
- Подписки на каналы/авторов.
- Live-стриминг.
- Чат и личные сообщения.
- Скачивание для офлайн (через DRM offline keys) — фаза 2.
- iOS App Clips, Android Instant Apps.
- Apple TV / Android TV приложения.
- Donation/tip креаторам.
- Дополнительные банки (Spitamen Bank, Tojiksodirotbonk, Amonatbonk и т.п.) — добавляются в фазе 2 через расширение паттерна Strategy.
- Криптоплатежи (TRX, USDT) — фаза 2.

---

## 22. Открытые вопросы для согласования

- Точные мерчант-договоры с **Алиф Банк, Эсхата Банк, Душанбе Сити Банк** — сроки, комиссии, документация API под NDA.
- Курс TJS↔USD для динамической цены пакетов (фиксированный или раз в день из Нацбанка ТJ).
- Точные названия и цены пакетов коинов и VIP-планов (отдельно для USD и TJS).
- Список целевых стран помимо Таджикистана (Узбекистан → Click/Payme; Казахстан → Kaspi.kz; Киргизия → ElCart — фаза 2).
- Брендинг: название, логотип, цветовая палитра, дизайн-макеты.
- Юридические тексты (Terms, Privacy) на 6 языках с учётом локального законодательства о персональных данных.
- Контент-партнёры или собственное производство.
- Решение по Apple App Store: подавать на External Link Entitlement или ограничиться Reader-app паттерном.
- Решение по альтернативной публикации Android (RuStore, Galaxy Store) — для обхода Google Play Billing.
- Сертификат FairPlay от Apple — кто оформляет.
- Решение по Widevine L1 partnership с Google для премиум-уровня.

---

*Конец документа. Версия 1.2 — добавлена интеграция с банками Таджикистана: Алиф Банк, Эсхата Банк, Душанбе Сити Банк (новый раздел 13). Добавлены 4 новые таблицы БД, новые API-эндпоинты, новый этап разработки (этап 4), новая структура папок Laravel и Flutter, обновлены критерии приёмки и админка.*
