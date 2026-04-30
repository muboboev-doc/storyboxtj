# Prompt: добавить локализованную строку

> **Когда использовать:** добавляешь UI-строку во Flutter (или API-message в Laravel) и нужно перевести её на 6 языков.
>
> **Какой агент:** `Haiku` для механической работы (вписать ключи в 6 ARB), `Sonnet` для проверки контекста / тонов перевода.
>
> **Связанная документация:** [`CLAUDE.md` §11](../CLAUDE.md#11-локализация-6-языков), [`docs/tz.md` §14](../docs/tz.md).

---

## 6 целевых языков

| Код | Язык | Письменность | Fallback |
|---|---|---|---|
| `ru` | Русский | Кириллица | (default — пишем сначала) |
| `en` | English | Латиница | ru |
| `tg` | Тоҷикӣ | Кириллица | ru |
| `uz` | Oʻzbekcha | Латиница (`uz-Cyrl` опционально) | ru |
| `kk` | Қазақша | Кириллица | ru |
| `ky` | Кыргызча | Кириллица | ru |

---

## Случай A: UI-строка во Flutter (ARB)

### Шаг 1: добавить ключ во все 6 ARB-файлов

`mobile/lib/l10n/app_<locale>.arb`:

**`app_ru.arb`** (источник — пишем сначала здесь):

```json
{
  "@@locale": "ru",
  "ping_button": "Проверить связь",
  "@ping_button": {
    "description": "Кнопка на PingScreen которая отправляет GET /api/v1/ping"
  }
}
```

**`app_en.arb`**:

```json
{
  "@@locale": "en",
  "ping_button": "Ping API"
}
```

**`app_tg.arb`** (Тоҷикӣ — таджикский):

```json
{
  "@@locale": "tg",
  "ping_button": "Санҷиши пайвастагӣ"
}
```

**`app_uz.arb`** (Oʻzbekcha — узбекский латиницей):

```json
{
  "@@locale": "uz",
  "ping_button": "Aloqani tekshirish"
}
```

**`app_kk.arb`** (Қазақша — казахский):

```json
{
  "@@locale": "kk",
  "ping_button": "Байланысты тексеру"
}
```

**`app_ky.arb`** (Кыргызча — киргизский):

```json
{
  "@@locale": "ky",
  "ping_button": "Байланышты текшерүү"
}
```

> **Замечание:** `@<key>` метаданные с `description` пишутся ТОЛЬКО в `ru` файле. Не дублируй в других — это шум.

### Шаг 2: codegen

```bash
cd mobile
flutter gen-l10n
```

Это создаст `mobile/lib/l10n/app_localizations.dart` с типизированным геттером:

```dart
class AppLocalizations {
  String get ping_button;
  // ...
}
```

### Шаг 3: использование в виджете

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;

  return FilledButton(
    onPressed: () { /* ... */ },
    child: Text(l10n.ping_button),  // ← вместо хардкода
  );
}
```

### Шаг 4: убедись что хардкод не остался

```bash
cd mobile
flutter analyze | grep -i "hard.coded.string"  # custom rule в analysis_options.yaml
```

CLAUDE.md §6.1 требует custom lint rule запрещающий хардкод-строки (включается в Phase 8 Localization).

---

## Случай B: ICU plural / parametric

Для строк с числом / параметром используй ICU MessageFormat:

`app_ru.arb`:

```json
{
  "@@locale": "ru",
  "coins_balance": "{count, plural, =0{Нет коинов} one{{count} коин} few{{count} коина} many{{count} коинов} other{{count} коинов}}",
  "@coins_balance": {
    "description": "Баланс коинов в кошельке",
    "placeholders": {
      "count": { "type": "int" }
    }
  }
}
```

`app_en.arb`:

```json
{
  "@@locale": "en",
  "coins_balance": "{count, plural, =0{No coins} one{1 coin} other{{count} coins}}"
}
```

После `flutter gen-l10n`:

```dart
Text(l10n.coins_balance(wallet.coinsBalance))
```

---

## Случай C: контентные поля в БД (Laravel + Spatie Translatable)

Для CMS-контента (`series.title`, `episodes.synopsis`, `bank_payment_providers.name`) используем JSON-колонки через Spatie Laravel-Translatable.

### Миграция

```php
$table->json('title');  // {"ru":"...","en":"...","tg":"...","uz":"...","kk":"...","ky":"..."}
```

### Модель

```php
use Spatie\Translatable\HasTranslations;

class Series extends Model
{
    use HasTranslations;

    public array $translatable = ['title', 'synopsis'];
}
```

### Использование

```php
$series->setTranslations('title', [
    'ru' => 'Любовь в Душанбе',
    'en' => 'Love in Dushanbe',
    'tg' => 'Муҳаббат дар Душанбе',
    // ...
]);
$series->save();

// Чтение в текущей локали:
$title = $series->title;  // вернёт по app()->getLocale()

// Конкретный перевод:
$titleEn = $series->getTranslation('title', 'en');
```

### Form в Filament (admin)

```php
use Spatie\TranslatableForm\Forms\Components\TranslatableTextInput;

TranslatableTextInput::make('title')
    ->locales(['ru', 'en', 'tg', 'uz', 'kk', 'ky'])
    ->required()
    ->maxLength(255);
```

---

## Случай D: API error messages (Laravel)

API-ошибки тоже на 6 языках. Источник — `lang/<locale>/messages.php`:

```php
// lang/ru/api.php
return [
    'episode_not_unlocked' => 'Этот эпизод нужно разблокировать',
    'insufficient_coins' => 'Недостаточно коинов: нужно :needed, у вас :have',
];

// lang/en/api.php
return [
    'episode_not_unlocked' => 'This episode is locked',
    'insufficient_coins' => 'Insufficient coins: need :needed, you have :have',
];
```

В коде:

```php
throw new AppException(
    code: 'INSUFFICIENT_COINS',
    message: __('api.insufficient_coins', ['needed' => 50, 'have' => 30]),
);
```

Локаль выбирается из:
1. `Accept-Language` header клиента
2. `User::locale` (если авторизован)
3. fallback `ru`

В `app/Http/Middleware/SetLocale.php`:

```php
public function handle($request, Closure $next)
{
    $locale = $request->user()?->locale
        ?? $request->getPreferredLanguage(['ru','en','tg','uz','kk','ky'])
        ?? 'ru';

    app()->setLocale($locale);
    return $next($request);
}
```

---

## Case E: hot-reload переводов (без релиза приложения)

CLAUDE.md §11.1 — перевод-fix без релиза через `/translations/{locale}` endpoint.

### Backend

`backend/routes/api.php`:

```php
Route::get('/translations/{locale}', function (string $locale) {
    return response()->json([
        'translations' => Translation::where('locale', $locale)
            ->pluck('value', 'key'),
    ])->setEtag(md5(Translation::max('updated_at')));
});
```

### Mobile (Hive cache)

```dart
class TranslationsRepository {
  Future<Map<String, String>> fetch(String locale) async {
    final cached = await _hive.box('translations').get(locale);
    if (cached?.etag == _etag) return cached.data;

    final response = await _dio.get('/translations/$locale',
      options: Options(headers: {'If-None-Match': cached?.etag ?? ''}));

    if (response.statusCode == 304) return cached!.data;

    final etag = response.headers.value('etag');
    final data = Map<String, String>.from(response.data['translations']);
    await _hive.box('translations').put(locale, _Cached(data, etag));
    return data;
  }
}
```

При запуске app: `await translationsRepo.fetch(currentLocale)` — обновит кэш если есть новая версия.

---

## Псевдо-локаль (для smoke забытых строк)

`mobile/lib/l10n/app_xx.arb`:

```json
{
  "@@locale": "xx",
  "ping_button": "[«Ping API»]"
}
```

Каждый ключ обёрнут в `[«...»]`. Если на UI видишь голый ключ (`ping_button`) или его английское значение — значит ARB не обновлён.

Запуск:

```bash
cd mobile
flutter run --dart-define=LOCALE=xx --target lib/main_dev.dart -d chrome
```

CLAUDE.md §17 Phase 8.6 — псевдо-локаль автоматически создаётся через скрипт.

---

## Чеклист DoD для нового перевода

- [ ] Ключ добавлен во все 6 ARB-файлов (`ru/en/tg/uz/kk/ky`)
- [ ] `@<key>` description написан в `app_ru.arb` (контекст для других переводчиков)
- [ ] `flutter gen-l10n` прогнан, нет ошибок
- [ ] Виджет использует `AppLocalizations.of(context)!.<key>`, нет хардкода
- [ ] `flutter analyze` зелёный
- [ ] (для контентных полей) миграция с JSON-колонкой + Spatie HasTranslations + Filament `TranslatableTextInput`
- [ ] (для API errors) ключи в `lang/<locale>/api.php` для всех 6 языков
- [ ] Smoke-проверка с псевдо-локалью `xx` — все строки в скобках
