/// Phase 2.9: горизонтальная секция с заголовком и список SeriesPosterCard.
///
/// Используется для:
///  - Trending / New Releases / Recommended
///  - Каждого жанра в `genres` секции `/api/v1/home`
///
/// При пустом списке секция не рендерится (HomeScreen фильтрует).
library;

import 'package:flutter/material.dart';

import 'package:storybox_app/api/storybox_api.dart';
import 'package:storybox_app/presentation/home/widgets/series_poster_card.dart';

class SeriesRowSection extends StatelessWidget {
  const SeriesRowSection({
    required this.title,
    required this.series,
    super.key,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<SeriesSummary> series;

  static const double _itemWidth = 140;
  static const double _itemHeight = _itemWidth / (9 / 16); // 9:16 → height

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _itemHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: series.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => SeriesPosterCard(series: series[i]),
            ),
          ),
        ],
      ),
    );
  }
}
