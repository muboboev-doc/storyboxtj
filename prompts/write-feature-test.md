# Prompt: написать Pest feature-тест

> **Когда использовать:** добавляешь новый API-эндпоинт или меняешь существующий — нужно покрыть happy path + критические edge cases.
>
> **Какой агент:** `Sonnet` достаточно. Для high-risk модулей (wallet, banks, IAP, DRM) — TDD режим: тест → реализация.
>
> **Связанная документация:** [`CLAUDE.md` §12](../CLAUDE.md#12-тестирование), [`CLAUDE.md` §16.3](../CLAUDE.md) (subagents для тестов).

---

## Структура (arrange-act-assert)

`backend/tests/Feature/Api/V<N>/<Feature>Test.php`:

```php
<?php
declare(strict_types=1);

use App\Models\User;
use App\Models\Wallet;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

describe('GET /api/v1/<resource>', function () {
    it('returns 200 with expected json structure', function () {
        // ARRANGE
        $user = User::factory()->create();
        $wallet = Wallet::factory()->forUser($user)->withBalance(500)->create();

        // ACT
        $response = $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/<resource>');

        // ASSERT
        $response
            ->assertOk()
            ->assertJsonStructure([
                'data' => ['id', 'name', 'balance'],
                'meta' => ['total'],
            ])
            ->assertJsonPath('data.balance', 500);
    });

    it('requires authentication', function () {
        $this->getJson('/api/v1/<resource>')
            ->assertStatus(401);
    });
});
```

---

## Чек-лист сценариев (минимум для merge)

Для каждого нового endpoint'а должны быть:

- [ ] **Happy path** — нормальный запрос → 200 + ожидаемый JSON
- [ ] **Auth required** (если защищён) — без токена → 401
- [ ] **Rate limit** — отдельный тест с превышением (если endpoint имеет limit)
- [ ] **Validation errors** — невалидный body / missing fields → 422 с правильными `errors` keys
- [ ] **Authorization** (если применимо) — другой user не может прочитать чужой ресурс → 403
- [ ] **Idempotency** (для платежей) — повторный запрос с тем же ключом не создаёт дубль

Для эндпоинтов изменяющих **финансовое состояние** (wallet, unlock, payments):

- [ ] **Property-based**: инварианты wallet после операции
- [ ] **Concurrency**: 2 параллельных запроса не приводят к double-spend
- [ ] **Error в середине транзакции** → rollback (баланс не изменился)

---

## Helper-методы (часто нужны)

### Создание авторизованного юзера с кошельком

`backend/tests/TestCase.php` — добавить:

```php
protected function createUserWithCoins(int $coins = 0): User
{
    $user = User::factory()->create();
    Wallet::factory()->forUser($user)->withBalance($coins)->create();
    return $user;
}

protected function actingAsUser(?User $user = null): User
{
    $user ??= $this->createUserWithCoins();
    Sanctum::actingAs($user);
    return $user;
}
```

Использование:

```php
it('debits wallet on unlock', function () {
    $user = $this->actingAsUser($this->createUserWithCoins(100));
    $episode = Episode::factory()->create(['unlock_cost_coins' => 30]);

    $this->postJson("/api/v1/episodes/{$episode->id}/unlock")
        ->assertOk();

    expect($user->wallet->fresh()->coins_balance)->toBe(70);
});
```

### Mock внешних API

```php
use Illuminate\Support\Facades\Http;

beforeEach(function () {
    Http::fake([
        'sandbox.alif.tj/*' => Http::response([
            'session_id' => 'sess_test',
            'checkout_url' => 'https://...',
        ], 200),
    ]);
});

it('hits Alif sandbox', function () {
    /* test */

    Http::assertSent(function ($request) {
        return $request->url() === 'sandbox.alif.tj/init'
            && $request->hasHeader('X-Signature');
    });
});
```

### Mock Sentry / события

```php
use Sentry\Laravel\Facade as Sentry;

it('reports failure to Sentry', function () {
    /* trigger failure */

    Sentry::shouldHaveReceived('captureException')->once();
});
```

---

## Database state

### Свежая БД на каждый тест

```php
uses(RefreshDatabase::class);  // в начале файла или в Pest.php
```

Тогда `RefreshDatabase` trait откатывает миграции после каждого теста.

### Seed данные перед тестом

```php
beforeEach(function () {
    $this->seed(BankProviderSeeder::class);  // только нужные банки
});
```

### Фикстуры из JSON-файлов

```php
function loadFixture(string $name): array
{
    return json_decode(
        file_get_contents(base_path("tests/fixtures/{$name}.json")),
        true,
    );
}

it('processes Alif webhook with real payload', function () {
    $payload = loadFixture('banks/alif/webhook_succeeded');

    $this->postJson('/webhooks/bank/alif', $payload, [
        'X-Alif-Signature' => 'valid_test_signature',
    ])->assertOk();
});
```

---

## Запуск тестов

```bash
# Все тесты
docker compose exec app composer test

# Только Feature (быстрее когда только что не правил Unit)
docker compose exec app composer test:feature

# Конкретный файл
docker compose exec app ./vendor/bin/pest tests/Feature/Api/V1/PingTest.php

# С фильтром по описанию (Pest --filter)
docker compose exec app ./vendor/bin/pest --filter="returns 200"

# С coverage
docker compose exec app composer coverage

# Параллельно (в 4 раза быстрее)
docker compose exec app ./vendor/bin/pest --parallel
```

---

## Property-based testing (для wallet)

Для `WalletService` — обязательно. Используй `pest-plugin-property-based` или manual loop:

```php
it('credit + debit returns balance unchanged', function () {
    $user = $this->createUserWithCoins(0);

    $iterations = 100;
    for ($i = 0; $i < $iterations; $i++) {
        $amount = fake()->numberBetween(1, 1000);
        app(WalletService::class)->credit($user->id, $amount, 'test', null);
        app(WalletService::class)->debit($user->id, $amount, 'test', null);
    }

    expect($user->wallet->fresh()->coins_balance)->toBe(0);
});

it('balance_after equals sum of all transactions', function () {
    $user = $this->createUserWithCoins(0);

    for ($i = 0; $i < 50; $i++) {
        $amount = fake()->numberBetween(1, 100);
        app(WalletService::class)->credit($user->id, $amount, 'test', null);
    }

    $sum = WalletTransaction::where('user_id', $user->id)
        ->sum(DB::raw('CASE WHEN direction="credit" THEN amount_coins ELSE -amount_coins END'));

    expect($user->wallet->fresh()->coins_balance)->toBe((int) $sum);
});
```

---

## Anti-patterns (что НЕ делать)

- ❌ **`->assertSee('text')`** для JSON-ответа (assertSee для HTML). Используй `assertJson()` или `assertJsonPath()`.
- ❌ **Жёсткие даты в ассертах** (`'2026-04-30T...')`. Используй `expect($timestamp)->toMatch('/\d{4}-\d{2}-\d{2}/')` или freezetime.
- ❌ **`Http::fake()` после первого реального запроса**. Ставь `Http::fake()` ДО действия.
- ❌ **Один тест проверяет несколько фич** (антипаттерн "god test"). Один `it(...)` — одна assertion-цель.
- ❌ **Использовать prod факт-данные** в тестах (реальные пользователи, реальные банк-кредиты). Только factories.
- ❌ **Игнорировать падающий тест** через `it->skip()` без issue-link. Если skip — то `it->skip('see #123')`.

---

## Шаблон промпта для Claude

```
Напиши Pest feature-тест для эндпоинта <METHOD> /api/v1/<path>.

Контекст:
- Контроллер: app/Http/Controllers/Api/V1/<Controller>.php (метод <method>)
- Модель: app/Models/<Model>.php
- FormRequest validation rules: <Request>::rules() — приклади на проверки

Покрой:
1. Happy path: <конкретный сценарий с ожидаемым JSON>
2. Auth required (если есть middleware auth:sanctum)
3. Validation errors: <конкретные кейсы>
4. Authorization (если только владелец может): другой user → 403
5. <если применимо>: rate limit / idempotency / concurrency

Используй:
- describe(...) -> it(...) структуру
- factory()->state() для setup
- Http::fake() для внешних API
- expect() chain для assertions
- helper'ы из tests/TestCase.php (createUserWithCoins, actingAsUser, и т.д.)

Перед коммитом — composer test должен быть зелёный.
```
