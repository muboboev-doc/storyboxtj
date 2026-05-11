/// Phase 2.11: stub поверхность плеера.
///
/// Реальный HLS-плеер (video_player + хочет ExoPlayer/AVPlayer + DRM) появится
/// в Phase 4 после реального транскодинга. Пока — заглушка которая показывает:
///  - poster_url сериала на фоне (если есть)
///  - кнопка Play (которая просто переключает иконку — placeholder)
///  - manifest_url первого подходящего потока (для отладки)
///
/// Контракт сохранится: `PlayerSurface(streams, posterUrl)`.
library;

import 'package:flutter/material.dart';

import 'package:storybox_app/api/storybox_api.dart';

class PlayerSurface extends StatefulWidget {
  const PlayerSurface({
    required this.streams,
    super.key,
    this.posterUrl,
  });

  final List<EpisodeStream> streams;
  final String? posterUrl;

  @override
  State<PlayerSurface> createState() => _PlayerSurfaceState();
}

class _PlayerSurfaceState extends State<PlayerSurface> {
  bool _playing = false;

  /// Выбор приоритетного качества для baseline-видео.
  /// Phase 4 заменит на ABR (adaptive bitrate selection).
  EpisodeStream? get _preferredStream {
    if (widget.streams.isEmpty) return null;
    for (final q in [
      StreamQuality.hd720,
      StreamQuality.sd480,
      StreamQuality.hd1080,
      StreamQuality.sd240,
    ]) {
      for (final s in widget.streams) {
        if (s.quality == q) return s;
      }
    }
    return widget.streams.first;
  }

  @override
  Widget build(BuildContext context) {
    final stream = _preferredStream;

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.posterUrl != null && widget.posterUrl!.isNotEmpty)
              Opacity(
                opacity: 0.7,
                child: Image.network(
                  widget.posterUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            // Затемнение для контраста.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent, Colors.black87],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Center(
              child: IconButton(
                iconSize: 72,
                icon: Icon(
                  _playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  color: Colors.white,
                ),
                onPressed: () => setState(() => _playing = !_playing),
              ),
            ),
            // Debug-инфо для разработки. Phase 4 уберём.
            if (stream != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 24,
                child: _DebugBadge(stream: stream),
              ),
          ],
        ),
      ),
    );
  }
}

class _DebugBadge extends StatelessWidget {
  const _DebugBadge({required this.stream});

  final EpisodeStream stream;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Phase 2 stub • ${stream.quality.toJson()} • ${stream.manifestUrl}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white70, fontSize: 10),
      ),
    );
  }
}
