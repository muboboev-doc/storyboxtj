# Prompt: добавить новый банк-драйвер

> **Когда использовать:** появилась мерчант-документация (NDA подписан) на новый локальный банк, и его нужно интегрировать через Strategy pattern.
>
> **Какой агент:** `Plan mode + Opus` для spike, потом `Sonnet` для имплементации с TDD.
>
> **Связанная документация:** [`CLAUDE.md` §10](../CLAUDE.md#10-локальные-банки-таджикистана), [`docs/tz.md` §13](../docs/tz.md), [Phase 6 в roadmap](../CLAUDE.md#фаза-6-banks--one-first-потом-шаблон-3-недели).

---

## Входные данные (заполнить перед запуском)

| Параметр | Пример | Зачем |
|---|---|---|
| `<bank_code>` | `spitamen` | snake_case, идёт в `BankCode` enum, в URL `/webhooks/bank/<code>`, в config |
| `<BankName>` | `SpitamenBankDriver` | PascalCase для класса драйвера |
| Display name (translatable) | `{"ru":"Спитамен Банк","en":"Spitamen Bank","tg":"Бонки Спитамен"}` | в seeder для `bank_payment_providers.name` |
| Поддерживаемые методы | `["card","qr"]` | в `bank_payment_providers.supports_methods` |
| Sandbox base URL | `https://sandbox.spitamen.tj/api/v1` | в `config/banks.php` |
| Prod base URL | `https://merchant.spitamen.tj/api/v1` | в `config/banks.php` |
| HMAC algorithm | `HMAC-SHA256` или `HMAC-SHA512` или `RSA` | в `verifyWebhookSignature()` |
| Signature header name | `X-Spitamen-Signature` | какой header читать |
| Status field в callback | `payload.status` или `payload.event` | как маппить статусы |

---

## Шаг 0: Spike (1-2 дня, ~3 сессии)

**Цель:** до того как писать код — понять как работает sandbox.

### 0.1. Подписать NDA, скачать API доку (PDF/Confluence)

### 0.2. Запустить `Plan mode + Opus` с инструкцией:

```
Прочитай прикреплённую API-доку <bank_code>. Вытащи и сведи в таблицу:
- Полный список endpoint'ов (init, status, cancel, refund, reconciliation)
- Authentication scheme (OAuth2 client credentials? API key? Mutual TLS?)
- Формат запроса/ответа (JSON? XML? form-encoded?)
- HMAC-алгоритм для подписи webhook + какие поля участвуют в подписи
- Список всех статусов транзакции у банка → маппинг на наш BankTransactionStatus enum
  (pending|redirected|authorized|succeeded|failed|cancelled|expired|refunded)
- IP-диапазоны откуда они посылают webhook (для allowed_ips)
- SLA: timeout инициации, таймаут callback, окно reconciliation
- Особенности: deep-link для wallet (если есть), QR payload формат, recurring токенизация

Нарисуй sequence-diagram (Mermaid) для card / qr / wallet flows.
Запиши вопросы которые нужно уточнить у банка.
```

### 0.3. Postman-коллекция

В sandbox-режиме вручную:
1. Получить access token (если OAuth)
2. Init payment session — записать checkout_url
3. Симулировать оплату через банк-UI
4. Дождаться webhook на наш ngrok URL → сохранить raw payload + headers как фикстуру
5. Получить статус через get-status endpoint

Сохранить коллекцию в `docs/postman/<bank_code>.postman_collection.json`.

### 0.4. ADR `docs/decisions/000X-<bank_code>-integration.md`

Шаблон:

```markdown
# ADR 000X: интеграция <BankName>

**Статус:** принят
**Дата:** YYYY-MM-DD

## Контекст
Зачем интегрируем (рост audience? gap в покрытии?)

## Архитектурные особенности банка
- Authentication: ...
- Webhook signature: ...
- Format: JSON/XML
- Маппинг статусов: см. таблицу
- Recurring (для VIP): поддерживается / нет

## Решения
1. Какой driver-pattern (стандартный по интерфейсу или нужны костыли)
2. Где специфика (custom serializer, особый retry, и т.д.)
3. Test mode vs prod — как переключаем

## Открытые вопросы
- ...
```

---

## Шаг 1: Backend implementation (4-5 дней, ~8 сессий) — TDD

### 1.1. Расширить enum `BankCode`

`backend/app/Enums/BankCode.php`:

```php
enum BankCode: string {
    case Alif = 'alif';
    case Eskhata = 'eskhata';
    case Dcbank = 'dcbank';
    case <CodeName> = '<bank_code>';   // ← добавить
}
```

### 1.2. Сидер для `bank_payment_providers`

`backend/database/seeders/Banks/<CodeName>SeederData.php`:

```php
return [
    'code' => '<bank_code>',
    'name' => [
        'ru' => '<Имя Банк>',
        'en' => '<Name> Bank',
        'tg' => '<Тоҷ. имя>',
    ],
    'logo_url' => '/storage/banks/<bank_code>.svg',
    'country_code' => 'TJ',
    'currency' => 'TJS',
    'api_base_url' => env('<CODE>_API_BASE_URL', 'https://sandbox.<bank>.tj/api/v1'),
    'merchant_id' => env('<CODE>_MERCHANT_ID', ''),
    'api_key' => env('<CODE>_API_KEY', ''),
    'secret_key' => env('<CODE>_SECRET_KEY', ''),
    'webhook_secret' => env('<CODE>_WEBHOOK_SECRET', ''),
    'allowed_ips' => json_encode(['<sandbox-ip-1>', '<sandbox-ip-2>']),
    'supports_methods' => json_encode(['card', 'qr']),
    'min_amount_tjs' => 5,
    'max_amount_tjs' => 5000,
    'fee_percent' => 0,
    'fee_fixed' => 0,
    'is_active' => true,
    'is_test_mode' => true,
];
```

Добавить в `DatabaseSeeder` или отдельный `BankProviderSeeder`.

### 1.3. **Сначала Pest unit-тест** (TDD red)

`backend/tests/Unit/Banks/<CodeName>BankDriverTest.php`:

```php
<?php
declare(strict_types=1);

use App\Services\Banks\Drivers\<CodeName>BankDriver;
use App\Services\Banks\DTOs\PaymentInitRequest;
use App\Models\BankPaymentProvider;
use Illuminate\Support\Facades\Http;

beforeEach(function () {
    $this->provider = BankPaymentProvider::factory()-><bank_code>()->create();
    $this->driver = new <CodeName>BankDriver($this->provider);
});

describe('initiate()', function () {
    it('sends correctly signed request to bank API', function () {
        Http::fake([
            $this->provider->api_base_url . '/<init-endpoint>' => Http::response([
                'session_id' => 'sess_123',
                'checkout_url' => 'https://merchant.<bank>.tj/pay/sess_123',
            ], 200),
        ]);

        $req = new PaymentInitRequest(
            amountTjsCents: 10000,
            externalInvoiceId: 'inv_001',
            method: 'card',
            returnUrl: 'storybox://payment/return',
        );

        $response = $this->driver->initiate($req);

        expect($response->checkoutUrl)->toBe('https://merchant.<bank>.tj/pay/sess_123');
        expect($response->externalId)->toBe('sess_123');

        Http::assertSent(function ($request) {
            // Проверяем HMAC-подпись в headers
            return $request->hasHeader('X-<Bank>-Signature')
                && /* hash_equals signature check */;
        });
    });

    it('throws on bank 5xx with descriptive error', function () { /* ... */ });
    it('handles rate-limit (429) by retrying with exp backoff', function () { /* ... */ });
});

describe('verifyWebhookSignature()', function () {
    it('returns true for valid HMAC-<algo> signature', function () { /* ... */ });
    it('returns false for tampered body', function () { /* ... */ });
    it('returns false for replay (timestamp out of ±5 min)', function () { /* ... */ });
});

describe('parseWebhook()', function () {
    it('maps bank statuses to our BankTransactionStatus enum', function () {
        $cases = [
            '<bank-success-status>' => BankTransactionStatus::Succeeded,
            '<bank-fail-status>' => BankTransactionStatus::Failed,
            // ...
        ];
        foreach ($cases as $bankStatus => $ourStatus) {
            $payload = '...'; // фейковый callback от банка
            $parsed = $this->driver->parseWebhook($payload);
            expect($parsed->status)->toBe($ourStatus);
        }
    });
});

describe('getStatus()', function () { /* ... */ });
describe('cancel()', function () { /* ... */ });
describe('refund()', function () { /* ... */ });
describe('reconcile()', function () { /* ... */ });
```

Coverage target: **100%** для `app/Services/Banks/Drivers/<CodeName>BankDriver.php`.

### 1.4. Реализация драйвера (TDD green)

`backend/app/Services/Banks/Drivers/<CodeName>BankDriver.php`:

```php
<?php
declare(strict_types=1);

namespace App\Services\Banks\Drivers;

use App\Services\Banks\BankPaymentInterface;
use App\Services\Banks\DTOs\{PaymentInitRequest, PaymentInitResponse, WebhookPayload, ReconciliationItem};
use App\Models\BankPaymentProvider;
use App\Enums\BankTransactionStatus;
use Illuminate\Support\Facades\{Http, Cache, Log};
use Sentry\State\Scope;

final class <CodeName>BankDriver implements BankPaymentInterface
{
    public function __construct(
        private readonly BankPaymentProvider $provider,
    ) {}

    public function initiate(PaymentInitRequest $req): PaymentInitResponse
    {
        // 1. Получить access token (кэш в Redis на TTL_token-1min)
        // 2. Подписать payload HMAC
        // 3. POST /init с retry (3 попытки exp backoff)
        // 4. Распарсить ответ → PaymentInitResponse
    }

    public function getStatus(string $externalId): /*PaymentStatus enum*/
    {
        // GET /status/{externalId}, маппинг статуса
    }

    public function cancel(string $externalId): bool { /* ... */ }
    public function refund(string $externalId, ?int $amountTjsCents = null): bool { /* ... */ }

    public function verifyWebhookSignature(array $headers, string $body): bool
    {
        $signature = $headers['x-<bank>-signature'][0] ?? null;
        if (!$signature) return false;

        $expected = hash_hmac('sha256', $body, decrypt($this->provider->webhook_secret));
        return hash_equals($expected, $signature);
    }

    public function parseWebhook(string $body): WebhookPayload
    {
        $data = json_decode($body, true, flags: JSON_THROW_ON_ERROR);
        return new WebhookPayload(
            externalId: $data['session_id'],
            status: $this->mapStatus($data['status']),
            amountTjsCents: (int) ($data['amount'] * 100),
            metadata: $data,
        );
    }

    public function reconcile(\DateTime $from, \DateTime $to): array
    {
        // GET /transactions?from=...&to=... → array of ReconciliationItem
    }

    private function mapStatus(string $bankStatus): BankTransactionStatus
    {
        return match ($bankStatus) {
            '<bank-pending>' => BankTransactionStatus::Pending,
            '<bank-success>' => BankTransactionStatus::Succeeded,
            '<bank-fail>' => BankTransactionStatus::Failed,
            // ...
            default => BankTransactionStatus::Failed,
        };
    }

    private function authToken(): string
    {
        return Cache::remember(
            "<bank>:auth_token:{$this->provider->id}",
            now()->addMinutes(50), // TTL_от_банка минус 10 мин запас
            fn() => $this->fetchAuthToken(),
        );
    }
}
```

**Каждый запрос логируем в Sentry breadcrumbs** через `Sentry::addBreadcrumb()`.

### 1.5. Зарегистрировать драйвер в `BankServiceProvider`

`backend/app/Providers/BankServiceProvider.php`:

```php
$this->app->bind(<CodeName>BankDriver::class, function () {
    $provider = BankPaymentProvider::where('code', '<bank_code>')->firstOrFail();
    return new <CodeName>BankDriver($provider);
});

// В BankPaymentManager::resolve():
'<bank_code>' => app(<CodeName>BankDriver::class),
```

### 1.6. Webhook-контроллер

`backend/app/Http/Controllers/Webhooks/Banks/<CodeName>WebhookController.php`:

```php
<?php
declare(strict_types=1);

namespace App\Http\Controllers\Webhooks\Banks;

use App\Services\Banks\WebhookProcessor;
use Illuminate\Http\Request;

final class <CodeName>WebhookController
{
    public function __invoke(Request $request, WebhookProcessor $processor)
    {
        return $processor->handle('<bank_code>', $request);
    }
}
```

### 1.7. Маршрут

`backend/routes/webhooks.php`:

```php
Route::post('/bank/<bank_code>', \App\Http\Controllers\Webhooks\Banks\<CodeName>WebhookController::class)
    ->middleware('bank-webhook-ip-whitelist')
    ->name('webhooks.bank.<bank_code>');
```

### 1.8. Feature-тесты на webhook (TDD)

`backend/tests/Feature/Banks/<CodeName>WebhookTest.php`:

Минимальный набор сценариев:
- ✅ Happy path: signed valid → 200 + coins credited
- ✅ Bad signature → 401 + лог `processing_status='rejected'`
- ✅ IP not in whitelist → 403
- ✅ Tx not found → 404
- ✅ Replay (timestamp > +5 min) → 401
- ✅ Duplicate (status уже succeeded) → 200 + не списывает повторно
- ✅ Cancel pending → tx.status=cancelled

---

## Шаг 2: Filament admin (1 день, ~2 сессии)

В `BankProviderResource` ничего менять не нужно — он уже generic. Просто новый банк появится в списке после seeder.

В `BankProviderResource` action `Test connection`:

```php
Action::make('test_connection')
    ->action(function (BankPaymentProvider $record) {
        $driver = app(BankPaymentManager::class)->driver($record->code);
        try {
            $driver->getStatus('test_external_id_xxx');
            Notification::make()->success()->title('Connection OK')->send();
        } catch (\Throwable $e) {
            Notification::make()->danger()->title('Failed: '.$e->getMessage())->send();
        }
    });
```

---

## Шаг 3: Mobile UI (1 день, ~2 сессии)

`mobile/lib/data/payments/bank_payment_repository.dart` сам берёт список банков из `/api/v1/payments/banks` — новый банк появится автоматически после `is_active=true`.

В `BankSelectorSheet` положить логотип:
- `mobile/assets/banks/<bank_code>.svg` или `.png`
- регистрируется автоматически если backend отдаёт `logo_url`

---

## Шаг 4: DoD (acceptance)

- [ ] Spike + ADR commit'нуты
- [ ] `composer test` зелёный, coverage `app/Services/Banks/Drivers/<CodeName>BankDriver.php` = 100%
- [ ] Polный happy-path в sandbox: client → initiate → checkout → webhook → coins credited
- [ ] Bad signature → 401, IP не из whitelist → 403, replay → 401
- [ ] Duplicate webhook идемпотентен (не дублирует начисление)
- [ ] Reconciliation cron для нового банка работает (тест с зависшей tx)
- [ ] В Filament action «Test connection» отвечает OK
- [ ] В Flutter `BankSelectorSheet` показывает новый банк с логотипом
- [ ] PR в main с описанием sequence-flow

---

## Чеклист безопасности (CLAUDE.md §7)

Перед открытием PR:

- [ ] **Не коммитим** API ключи / merchant_id / webhook_secret в репо. Только в `bank_payment_providers` (encrypted) + GitHub Secrets для CI.
- [ ] **Не принимаем CVV / номер карты** в наш backend. Карта вводится ТОЛЬКО на checkout-странице банка.
- [ ] **HMAC-SHA256 минимум** для webhook. Никаких MD5/SHA1.
- [ ] **IP whitelist** обязателен (даже если банк не указывает IP — попроси, или добавь NULL allowed_ips и логируй).
- [ ] **Idempotency** на initiate ([X-Idempotency-Key]) — обязательно.
- [ ] **TLS pinning** для исходящих запросов — если CA нестабильны (флаг `tls_pin` в provider).
- [ ] **Audit log** ручных действий (refund, manual mark as succeeded) в `audit_logs`.
