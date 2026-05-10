/// Phase 2.10: providers для SeriesDetailScreen.
///
/// `seriesShowProvider` — `FutureProvider.family<SeriesShow, int>`. Параметризуем
/// id сериала. Riverpod кэширует по id, так что навигация back на тот же
/// сериал не перезапрашивает.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:storybox_app/api/storybox_api.dart';
import 'package:storybox_app/presentation/home/home_provider.dart';

// FutureProviderFamily-тип очень громоздкий и теряет inference внутри
// семейства; оставляем выводимый тип.
// ignore: specify_nonobvious_property_types
final seriesShowProvider = FutureProvider.family<SeriesShow, int>(
  (ref, id) async {
    return ref.watch(contentRepositoryProvider).fetchSeries(id);
  },
);
