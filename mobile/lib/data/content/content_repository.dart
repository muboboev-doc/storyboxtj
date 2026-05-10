/// Phase 2.9: тонкая обёртка над StoryboxApi для content-эндпоинтов.
///
/// Зачем repository поверх api клиента:
///  - изоляция UI/Notifier'ов от Dio-исключений (мы их уже маппим в ApiError)
///  - единая точка для будущих кэш-стратегий (offline-first, ETag, и т.д.)
///  - удобство для override'а в widget-тестах через ProviderScope.overrides
library;

import 'package:storybox_app/api/storybox_api.dart';

class ContentRepository {
  const ContentRepository(this._api);

  final StoryboxApi _api;

  /// `GET /api/v1/home` — публичный эндпоинт (auth опциональна).
  ///
  /// `locale` опционален. Если null — backend определит по `Accept-Language`
  /// (ru/en/tg/uz/kk/ky, default ru).
  Future<HomePayload> fetchHome({String? locale}) =>
      _api.getHome(locale: locale);

  Future<SeriesShow> fetchSeries(int id) => _api.getSeriesShow(id);

  Future<EpisodeShow> fetchEpisode(int id) => _api.getEpisodeShow(id);
}
