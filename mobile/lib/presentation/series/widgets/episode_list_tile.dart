/// Phase 2.10: ряд эпизода в списке на SeriesDetailScreen.
///
/// Отображает:
///  - Номер эпизода (slot для thumbnail в Phase 2.13)
///  - Заголовок (если задан) или fallback "Episode N"
///  - Длительность в формате `M:SS`
///  - Lock-иконка для платных + надпись `N coins` (или зелёная Free badge)
///
/// Тап → `context.push('/episodes/{id}')`. На Phase 2.11 это станет вертикальным
/// плеером.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:storybox_app/api/storybox_api.dart';

class EpisodeListTile extends StatelessWidget {
  const EpisodeListTile({required this.episode, super.key});

  final Episode episode;

  @override
  Widget build(BuildContext context) {
    final title = (episode.title != null && episode.title!.isNotEmpty)
        ? episode.title!
        : 'Episode ${episode.number}';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => context.push('/episodes/${episode.id}'),
      leading: _NumberBadge(number: episode.number),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        _formatDuration(episode.durationSec),
        style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
      ),
      trailing: _AccessBadge(episode: episode),
    );
  }

  static String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$number',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}

class _AccessBadge extends StatelessWidget {
  const _AccessBadge({required this.episode});

  final Episode episode;

  @override
  Widget build(BuildContext context) {
    if (episode.isFree) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade700,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Free',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock, size: 16, color: Colors.amber),
        const SizedBox(width: 4),
        Text(
          '${episode.unlockCostCoins}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.amber,
          ),
        ),
      ],
    );
  }
}
