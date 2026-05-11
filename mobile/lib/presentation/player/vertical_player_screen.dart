/// Phase 2.11: вертикальный плеер для эпизода. Маршрут `/episodes/{id}`.
///
/// Состояния:
///   - loading → CircularProgressIndicator на чёрном фоне
///   - EPISODE_LOCKED (403) → bottom sheet с unlock_cost_coins + pop screen
///   - другая ошибка → центрированный message + retry / back
///   - data → AppBar + PlayerSurface + footer (next episode hint)
///
/// Anti-piracy: FLAG_SECURE для Android, captureProtection для iOS — Phase 8
/// (anti-piracy slice). На Phase 2 — заглушка с TODO-комментом.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:storybox_app/api/storybox_api.dart';
import 'package:storybox_app/presentation/player/episode_provider.dart';
import 'package:storybox_app/presentation/player/widgets/locked_episode_sheet.dart';
import 'package:storybox_app/presentation/player/widgets/player_surface.dart';

class VerticalPlayerScreen extends ConsumerStatefulWidget {
  const VerticalPlayerScreen({required this.id, super.key});

  final int id;

  @override
  ConsumerState<VerticalPlayerScreen> createState() =>
      _VerticalPlayerScreenState();
}

class _VerticalPlayerScreenState extends ConsumerState<VerticalPlayerScreen> {
  // Один раз показали LockSheet — не показывать снова в этом маунте экрана
  // (иначе rebuild → повторный показ).
  bool _lockSheetShown = false;

  Future<void> _showLockSheet({
    required int coins,
    required bool isPremium,
  }) async {
    await LockedEpisodeSheet.show(
      context,
      unlockCostCoins: coins,
      isPremium: isPremium,
    );
    if (!mounted) return;
    await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(episodeShowProvider(widget.id));

    // EPISODE_LOCKED — особый случай: показываем bottom sheet и не рендерим
    // плеер. Делаем это после build (addPostFrameCallback), чтобы не нарушать
    // правило «no setState during build».
    if (async.hasError && !_lockSheetShown) {
      final err = async.error;
      if (err is ApiError && err.code == 'EPISODE_LOCKED') {
        _lockSheetShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final coins =
              (err.context?['unlock_cost_coins'] as num?)?.toInt() ?? 0;
          final isPremium = err.context?['is_premium'] as bool? ?? false;
          unawaited(_showLockSheet(coins: coins, isPremium: isPremium));
        });
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          // EPISODE_LOCKED — sheet показывается через postFrameCallback;
          // body должен быть пустым, чтобы не светить error UI под sheet'ом.
          if (err is ApiError && err.code == 'EPISODE_LOCKED') {
            return const SizedBox.shrink();
          }
          return _ErrorState(
            error: err,
            onRetry: () => ref.invalidate(episodeShowProvider(widget.id)),
          );
        },
        data: (episode) => _PlayerContent(episode: episode),
      ),
    );
  }
}

// ─── Data ─────────────────────────────────────────────────────────────────────

class _PlayerContent extends StatelessWidget {
  const _PlayerContent({required this.episode});

  final EpisodeShow episode;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: PlayerSurface(
            streams: episode.streams,
            posterUrl: episode.series.posterUrl,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: _BottomMeta(episode: episode),
        ),
      ],
    );
  }
}

class _BottomMeta extends StatelessWidget {
  const _BottomMeta({required this.episode});

  final EpisodeShow episode;

  @override
  Widget build(BuildContext context) {
    final title =
        (episode.episode.title != null && episode.episode.title!.isNotEmpty)
        ? episode.episode.title!
        : 'Episode ${episode.episode.number}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              episode.series.title,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (episode.episode.synopsis != null &&
                episode.episode.synopsis!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                episode.episode.synopsis!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Error ────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // EPISODE_LOCKED обрабатывается отдельным sheet и pop — этот widget сюда
    // не показывается. Здесь — только остальные ошибки.

    final isNotFound =
        error is ApiError && (error as ApiError).statusCode == 404;

    final message = isNotFound
        ? 'Эпизод недоступен или не существует.'
        : error is ApiError
        ? (error as ApiError).message
        : 'Не удалось загрузить эпизод.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isNotFound ? Icons.movie_filter : Icons.error_outline,
              size: 48,
              color: Colors.white54,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            if (isNotFound)
              FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Назад'),
              )
            else
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
          ],
        ),
      ),
    );
  }
}
