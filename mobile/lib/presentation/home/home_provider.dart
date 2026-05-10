/// Phase 2.9: providers для HomeScreen.
///
/// - [contentRepositoryProvider] — singleton ContentRepository поверх StoryboxApi
/// - [homeProvider] — `FutureProvider<HomePayload>`. Pull-to-refresh —
///   через `ref.invalidate(homeProvider)`.
///
/// Backend кэширует `/home` 5 минут (CLAUDE.md §5.13). Клиент дополнительно
/// держит in-memory state в Riverpod-кэше; FutureProvider пересчитывается
/// только при invalidate.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:storybox_app/api/storybox_api.dart';
import 'package:storybox_app/data/content/content_repository.dart';
import 'package:storybox_app/presentation/auth/auth_provider.dart';

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return ContentRepository(ref.watch(storyboxApiProvider));
});

final homeProvider = FutureProvider<HomePayload>((ref) async {
  return ref.watch(contentRepositoryProvider).fetchHome();
});
