/// Phase 2.11: bottom sheet «Этот эпизод заблокирован».
///
/// Триггерится при HTTP 403 `EPISODE_LOCKED` (`ApiError.context.unlock_cost_coins`).
///
/// Phase 2 baseline: показываем стоимость в коинах + кнопка «OK» (закрыть и
/// вернуться). Phase 3 добавит реальный unlock через wallet API.
library;

import 'package:flutter/material.dart';

class LockedEpisodeSheet extends StatelessWidget {
  const LockedEpisodeSheet({
    required this.unlockCostCoins,
    super.key,
    this.isPremium = false,
  });

  final int unlockCostCoins;
  final bool isPremium;

  /// Показывает sheet и возвращает `true` если юзер тапнул «Unlock»
  /// (Phase 3 — после реализации wallet-spend). На Phase 2 всегда `false`.
  static Future<bool?> show(
    BuildContext context, {
    required int unlockCostCoins,
    bool isPremium = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      builder: (_) => LockedEpisodeSheet(
        unlockCostCoins: unlockCostCoins,
        isPremium: isPremium,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              isPremium ? Icons.workspace_premium : Icons.lock,
              size: 48,
              color: isPremium ? Colors.amber : Colors.white70,
            ),
            const SizedBox(height: 12),
            Text(
              isPremium
                  ? 'Этот эпизод — VIP-контент'
                  : 'Этот эпизод заблокирован',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              isPremium
                  ? 'Оформите подписку, чтобы открыть все VIP-эпизоды.'
                  : 'Разблокируйте за $unlockCostCoins коинов.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              // Phase 3: реальный unlock через wallet-spend.
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                isPremium
                    ? 'Подписка (Phase 7)'
                    : 'Разблокировать ($unlockCostCoins) — Phase 3',
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      ),
    );
  }
}
