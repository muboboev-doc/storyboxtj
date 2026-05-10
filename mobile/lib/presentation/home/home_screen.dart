/// Phase 2.9: главный экран приложения. Заменяет HomePlaceholderScreen.
///
/// Состояния:
///   - AsyncLoading → skeleton lists (4 секции)
///   - AsyncError   → центрированный текст + retry-button
///   - AsyncData    → 5 секций (continue_watching пока пусто на Phase 2)
///
/// RefreshIndicator делает pull-to-refresh через `homeProvider.notifier.refresh()`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:storybox_app/api/storybox_api.dart';
import 'package:storybox_app/presentation/auth/auth_provider.dart';
import 'package:storybox_app/presentation/home/home_provider.dart';
import 'package:storybox_app/presentation/home/widgets/series_row_section.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('StoryBox'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeProvider);
          await ref.read(homeProvider.future);
        },
        child: home.when(
          loading: () => const _HomeSkeleton(),
          error: (err, _) => _HomeError(
            error: err,
            onRetry: () => ref.invalidate(homeProvider),
          ),
          data: (payload) => _HomeContent(payload: payload),
        ),
      ),
    );
  }
}

// ─── Loaded state ──────────────────────────────────────────────────────────────

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.payload});

  final HomePayload payload;

  @override
  Widget build(BuildContext context) {
    final hasAnyContent =
        payload.trending.isNotEmpty ||
        payload.newReleases.isNotEmpty ||
        payload.recommended.isNotEmpty ||
        payload.genres.isNotEmpty;

    if (!hasAnyContent) {
      return const _HomeEmpty();
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        if (payload.continueWatching.isNotEmpty)
          SeriesRowSection(
            title: 'Continue Watching',
            series: payload.continueWatching,
          ),
        SeriesRowSection(title: 'Trending', series: payload.trending),
        SeriesRowSection(
          title: 'New',
          subtitle: 'Last 30 days',
          series: payload.newReleases,
        ),
        SeriesRowSection(
          title: 'Recommended',
          series: payload.recommended,
        ),
        for (final section in payload.genres)
          SeriesRowSection(
            title: section.genre.name,
            series: section.series,
          ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ─── Skeleton (loading) ────────────────────────────────────────────────────────

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: List.generate(4, (i) => const _SkeletonRow()),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  static const double _itemWidth = 140;
  static const double _itemHeight = _itemWidth / (9 / 16);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 18,
              width: 120,
              color: Colors.white12,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _itemHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, _) => Container(
                width: _itemWidth,
                height: _itemHeight,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error state ───────────────────────────────────────────────────────────────

class _HomeError extends StatelessWidget {
  const _HomeError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiError
        ? (error as ApiError).message
        : 'Не удалось загрузить ленту.';

    return ListView(
      // ListView чтобы pull-to-refresh работал даже на ошибке.
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
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
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Empty state ───────────────────────────────────────────────────────────────

class _HomeEmpty extends StatelessWidget {
  const _HomeEmpty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.movie_outlined, size: 48, color: Colors.white54),
                  SizedBox(height: 12),
                  Text(
                    'Здесь пока пусто.\nКонтент скоро появится.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
