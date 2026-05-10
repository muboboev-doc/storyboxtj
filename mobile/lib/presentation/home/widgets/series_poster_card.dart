/// Phase 2.9: карточка сериала в feed-секциях главной (9:16 вертикальный постер).
///
/// Поведение:
///  - Тап → navigate в `/series/{id}` (Phase 2.10 — реализация SeriesDetailScreen)
///  - Network image с fallback'ом (если poster_url null)
///  - Premium-бэйдж в правом верхнем углу
///  - Subtle gradient overlay снизу для читаемости title
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:storybox_app/api/storybox_api.dart';

class SeriesPosterCard extends StatelessWidget {
  const SeriesPosterCard({required this.series, super.key, this.width = 140});

  final SeriesSummary series;
  final double width;

  static const double _aspectRatio = 9 / 16;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: _aspectRatio,
        child: Material(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/series/${series.id}'),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _PosterImage(posterUrl: series.posterUrl),
                _BottomGradientOverlay(),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      series.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (series.isPremium)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: _PremiumBadge(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PosterImage extends StatelessWidget {
  const _PosterImage({required this.posterUrl});

  final String? posterUrl;

  @override
  Widget build(BuildContext context) {
    if (posterUrl == null || posterUrl!.isEmpty) {
      return const _PosterFallback(initial: 'S');
    }
    return Image.network(
      posterUrl!,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return ColoredBox(
          color: Colors.grey.shade800,
          child: const SizedBox.expand(),
        );
      },
      errorBuilder: (context, error, stackTrace) =>
          const _PosterFallback(initial: '!'),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.grey.shade800,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 32,
            color: Colors.white24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _BottomGradientOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.7),
          ],
          stops: const [0.5, 1.0],
        ),
      ),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.shade700,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'VIP',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }
}
