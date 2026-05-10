/// Phase 2.10: экран `/series/{id}` — карточка сериала + список эпизодов.
///
/// Состояния:
///   - loading → CircularProgressIndicator (минималистично — это второй экран)
///   - error 404 → специальная заглушка с back-кнопкой
///   - error other → fallback message + retry
///   - data → CustomScrollView с hero-баннером и SliverList эпизодов
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:storybox_app/api/storybox_api.dart';
import 'package:storybox_app/presentation/series/series_provider.dart';
import 'package:storybox_app/presentation/series/widgets/episode_list_tile.dart';

class SeriesDetailScreen extends ConsumerWidget {
  const SeriesDetailScreen({required this.id, super.key});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(seriesShowProvider(id));

    return Scaffold(
      body: async.when(
        loading: () => const _LoadingState(),
        error: (err, _) => _ErrorState(
          error: err,
          onRetry: () => ref.invalidate(seriesShowProvider(id)),
        ),
        data: (series) => _SeriesContent(series: series),
      ),
    );
  }
}

// ─── Data ─────────────────────────────────────────────────────────────────────

class _SeriesContent extends StatelessWidget {
  const _SeriesContent({required this.series});

  final SeriesShow series;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              series.summary.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            background: _Banner(summary: series.summary),
          ),
        ),
        SliverToBoxAdapter(child: _Header(series: series)),
        if (series.episodes.isEmpty)
          const SliverToBoxAdapter(child: _NoEpisodesPlaceholder())
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => EpisodeListTile(episode: series.episodes[i]),
              childCount: series.episodes.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.summary});

  final SeriesSummary summary;

  @override
  Widget build(BuildContext context) {
    final url = summary.bannerUrl ?? summary.posterUrl;
    final image = url == null
        ? const ColoredBox(color: Color(0xFF2A2A2A), child: SizedBox.expand())
        : Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(0xFF2A2A2A)),
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black87],
              stops: [0.5, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.series});

  final SeriesShow series;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (series.summary.isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'VIP',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              if (series.summary.isPremium) const SizedBox(width: 8),
              Text(
                '${series.summary.totalEpisodes} серий',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(width: 12),
              Text(
                'Бесплатно: ${series.summary.freeEpisodesCount}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ],
          ),
          if (series.genres.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in series.genres)
                  Chip(
                    label: Text(g.name),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ],
          if (series.summary.synopsis != null &&
              series.summary.synopsis!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(series.summary.synopsis!, style: const TextStyle(height: 1.4)),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _NoEpisodesPlaceholder extends StatelessWidget {
  const _NoEpisodesPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Center(
        child: Text(
          'Эпизоды появятся после транскода.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        ),
      ),
    );
  }
}

// ─── Loading / Error ──────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ),
        const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isNotFound =
        error is ApiError && (error as ApiError).statusCode == 404;

    final message = isNotFound
        ? 'Сериал не найден или ещё не опубликован.'
        : error is ApiError
        ? (error as ApiError).message
        : 'Не удалось загрузить сериал.';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            const Spacer(),
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
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
