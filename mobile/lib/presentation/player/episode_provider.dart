/// Phase 2.11: providers для VerticalPlayerScreen.
///
/// `episodeShowProvider` — `FutureProvider.family<EpisodeShow, int>`.
/// Бэкенд может вернуть 403 `EPISODE_LOCKED` (Phase 2.5) — это **не** ошибка
/// провайдера, а ожидаемый бизнес-кейс. Тем не менее, FutureProvider обернёт
/// ApiError в AsyncError; экран сам отличает 403 и показывает LockSheet.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:storybox_app/api/storybox_api.dart';
import 'package:storybox_app/presentation/home/home_provider.dart';

// FutureProviderFamily-тип очень громоздкий и теряет inference внутри семейства.
// ignore: specify_nonobvious_property_types
final episodeShowProvider = FutureProvider.family<EpisodeShow, int>(
  (ref, id) async {
    return ref.watch(contentRepositoryProvider).fetchEpisode(id);
  },
);
