/// Build flavors для разных целевых дистрибуций.
///
/// Используется в `main_<flavor>.dart` точках входа — переключает поведение
/// (например, Reader-app pattern на App Store билде).
///
/// CLAUDE.md §6.3, §10.5 — Reader-app pattern на iOS.
library;

enum Flavor {
  /// Локальная разработка: staging API, debug-меню, fake-данные допустимы.
  dev,

  /// Боевой релиз для Google Play / RuStore / Galaxy Store / Web — все банки видимы.
  prod,

  /// Apple App Store билд — локальные банки скрыты (Reader-app pattern,
  /// Guideline 3.1.1). Кнопка «Купить на сайте» вместо местных вкладок.
  appstore,
}

/// Глобальная конфигурация приложения, заполняется в `main_<flavor>.dart`.
final class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.apiBaseUrl,
    required this.localPaymentsEnabled,
  });

  final Flavor flavor;
  final String apiBaseUrl;

  /// Если false — вкладки «Local» в `CoinsStoreScreen` скрыты, показывается
  /// кнопка-ссылка на `https://example.com/store` (Reader-app pattern).
  final bool localPaymentsEnabled;

  String get name => switch (flavor) {
    Flavor.dev => 'StoryBox (dev)',
    Flavor.prod => 'StoryBox',
    Flavor.appstore => 'StoryBox',
  };

  bool get isDev => flavor == Flavor.dev;
  bool get isAppStore => flavor == Flavor.appstore;
}

/// Поздно-инициализируемый синглтон. Заполняется в `main_<flavor>.dart` ДО
/// `runApp()`. Доступ через `kAppConfig` где не подключён Riverpod
/// (например, в `main()` или статических утилитах).
late AppConfig kAppConfig;
