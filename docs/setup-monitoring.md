# Setup: Sentry + Firebase Monitoring

Phase 0.6 of [roadmap v2](../CLAUDE.md#17-подробный-план-разработки-roadmap-vibe-coding-оптимизированный) ставит SDK + интеграцию. Этот документ — **что нужно сделать руками** для подключения реальных credentials.

> **Без credentials всё работает.** SDK обоих сервисов в no-op режиме. Этот документ — на момент когда команда готова получать реальные events.

---

## 1. Sentry

### 1.1. Создать организацию и проекты

1. Зарегистрироваться на [sentry.io](https://sentry.io) (бесплатный тариф — 5K events/месяц).
2. Создать организацию `storybox` (или другую).
3. Создать **3 проекта**:
   - `storybox-backend` — platform: **PHP / Laravel**
   - `storybox-mobile` — platform: **Flutter**
   - `storybox-web` — platform: **Flutter / Web**

### 1.2. Получить DSN

Для каждого проекта: *Settings → Client Keys (DSN) → Copy DSN*.

Формат: `https://<public_key>@o<org_id>.ingest.sentry.io/<project_id>`.

### 1.3. Прописать в backend

`backend/.env`:

```env
SENTRY_LARAVEL_DSN=https://...@...ingest.sentry.io/...
SENTRY_ENVIRONMENT=local           # local / staging / production
SENTRY_TRACES_SAMPLE_RATE=1.0      # 1.0 на dev, 0.2 на prod
SENTRY_PROFILES_SAMPLE_RATE=0.0    # выключено по умолчанию
```

Проверка:

```bash
docker compose exec app php artisan sentry:test
# ✓ Event sent to Sentry: <event-id>
```

После этого в Sentry UI должно появиться `Test exception from artisan sentry:test`.

### 1.4. Прописать в Flutter

Sentry DSN передаётся через `--dart-define` при запуске / билде:

```bash
# Локально
flutter run --target lib/main_dev.dart -d chrome \
  --dart-define=SENTRY_DSN=https://...@...ingest.sentry.io/...

# Билд для CI
flutter build apk --flavor prod \
  --dart-define=SENTRY_DSN=https://... \
  --dart-define=SENTRY_RELEASE=v1.2.3
```

Без `--dart-define=SENTRY_DSN=...` приложение работает в no-op режиме.

### 1.5. Sentry release tracking (для CI/CD)

В `.github/workflows/deploy-prod.yml` (Phase 0.10):

```yaml
- name: Create Sentry release
  uses: getsentry/action-release@v1
  env:
    SENTRY_AUTH_TOKEN: ${{ secrets.SENTRY_AUTH_TOKEN }}
    SENTRY_ORG: storybox
    SENTRY_PROJECT: storybox-backend
  with:
    environment: production
    version: ${{ github.ref_name }}  # tag = release version
```

`SENTRY_AUTH_TOKEN` — из Sentry *Settings → Account → API → Auth Tokens* со scopes: `project:releases`, `org:read`.

---

## 2. Firebase

### 2.1. Создать Firebase проект

1. Открыть [Firebase Console](https://console.firebase.google.com).
2. *Add project* → `storybox-tj` (или другой).
3. Включить Analytics, Cloud Messaging.

### 2.2. Установить FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

Убедиться что `~/.pub-cache/bin` (Linux/Mac) или `%LOCALAPPDATA%\Pub\Cache\bin` (Windows) в PATH.

### 2.3. Настроить Flutter

```bash
cd mobile
flutterfire configure --project=storybox-tj
```

Это создаст:
- `lib/firebase_options.dart` (конфиг для всех платформ)
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `web/firebase-config.js` (если включишь Web)

**Эти файлы коммитим в репо** — они не секреты, а публичные API keys (с restrictions в Firebase Console).

### 2.4. Подключить в `main_*.dart`

После `flutterfire configure` заменить инициализацию в `lib/main_dev.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:storybox_app/firebase_options.dart';
import 'package:storybox_app/core/monitoring/firebase_monitoring_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase init
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Wire MonitoringService через Firebase Analytics
  monitoring = FirebaseMonitoringService();
  await monitoring.initialize();

  runApp(...);
}
```

`FirebaseMonitoringService` (нужно будет создать в Phase 1+) делегирует `trackEvent` → `FirebaseAnalytics.instance.logEvent`.

### 2.5. Cloud Messaging (push)

Phase 5 (retention features) — там подключаем push-токены, обработку foreground/background, и `firebase_messaging` через `PushService`.

---

## 3. Локальный workflow без credentials

Если ты только присоединился и **ещё не получил доступ** к Sentry/Firebase:

```bash
# Backend — пустой DSN, sentry SDK no-op
cp backend/.env.example backend/.env
# (SENTRY_LARAVEL_DSN не заполнен — это OK)

# Mobile — без --dart-define=SENTRY_DSN, никаких Firebase configure
flutter run --target lib/main_dev.dart -d chrome
```

Приложение работает на 100%. Все events в `MonitoringService` идут в `debugPrint` console — для разработки этого достаточно.

---

## 4. Verification checklist

После настройки credentials:

- [ ] `php artisan sentry:test` → событие появляется в Sentry UI (storybox-backend)
- [ ] Запуск Flutter приложения с `--dart-define=SENTRY_DSN=...` и кид-throw'ом exception → событие в Sentry UI (storybox-mobile)
- [ ] Firebase Analytics: открыть приложение → в Firebase Console *Analytics → DebugView* видны события `screen_view`, `app_open`
- [ ] Push (Phase 5): отправить test-сообщение через Firebase Console *Cloud Messaging* → пришло на устройство

---

## 5. Безопасность

- ❌ **Не коммить** `SENTRY_LARAVEL_DSN` или `SENTRY_AUTH_TOKEN` в репо. Только в `.env` (gitignored) или GitHub Secrets.
- ✅ **Можно коммитить** `firebase_options.dart` / `google-services.json` / `GoogleService-Info.plist` — это публичные конфиги. Защита Firebase — через App Check + Restrictions в console (запрет от других bundle IDs / SHA fingerprints).
- ✅ Sentry `send_default_pii: false` — мы не шлём email/phone в события (CLAUDE.md §11). Если нужен user-context для debugging — используем хеш user_id.

---

## 6. Что не покрывает этот doc

- **App Check** для Firebase (anti-abuse) — Phase 9 anti-piracy
- **Crashlytics** — пока используем Sentry для crashes; Crashlytics можно добавить параллельно если нужно
- **Performance monitoring** для Web/Mobile — Sentry Performance включается через `tracesSampleRate > 0`
- **A/B testing / Remote Config** — out of scope для MVP (Phase 1-12)
