import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:storybox_app/flavors.dart';

/// Smoke-screen для Phase 0.3 — проверяет связь Flutter ↔ Laravel API.
///
/// При нажатии «Ping» делает GET на `/api/v1/ping` и показывает результат.
/// Это сидит в общем UI-дереве как стартовый экран до Phase 1 (Auth slice).

/// Provider Dio-клиента. В Phase 1+ переедет в `core/network/api_client.dart`
/// с interceptor'ами (auth, retry, logging).
final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: kAppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {'Accept': 'application/json'},
    ),
  );
});

/// Состояние ping-вызова.
sealed class PingState {
  const PingState();
}

final class PingIdle extends PingState {
  const PingIdle();
}

final class PingLoading extends PingState {
  const PingLoading();
}

final class PingSuccess extends PingState {
  const PingSuccess(this.payload);
  final Map<String, dynamic> payload;
}

final class PingFailure extends PingState {
  const PingFailure(this.message);
  final String message;
}

final pingStateProvider = NotifierProvider<PingController, PingState>(
  PingController.new,
);

class PingController extends Notifier<PingState> {
  @override
  PingState build() => const PingIdle();

  Future<void> ping() async {
    state = const PingLoading();
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get<Map<String, dynamic>>('/api/v1/ping');
      state = PingSuccess(res.data ?? const {});
    } on DioException catch (e) {
      state = PingFailure(_describe(e));
    } on Exception catch (e) {
      state = PingFailure(e.toString());
    }
  }

  String _describe(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Не удалось подключиться к ${kAppConfig.apiBaseUrl}\n'
          '${e.message ?? ''}';
    }
    if (e.response != null) {
      return 'HTTP ${e.response?.statusCode}: ${e.response?.data}';
    }
    return e.message ?? 'Unknown error';
  }
}

class PingScreen extends ConsumerWidget {
  const PingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pingStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(kAppConfig.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                kAppConfig.flavor.name.toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Phase 0.3 smoke check',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'API: ${kAppConfig.apiBaseUrl}/api/v1/ping',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 32),
            Expanded(child: _StateView(state: state)),
            FilledButton.icon(
              icon: const Icon(Icons.network_ping),
              label: const Text('Ping API'),
              onPressed: state is PingLoading
                  ? null
                  : () => ref.read(pingStateProvider.notifier).ping(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateView extends StatelessWidget {
  const _StateView({required this.state});

  final PingState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      PingIdle() => const Center(
        child: Text(
          'Нажми «Ping API» чтобы проверить связь.',
          textAlign: TextAlign.center,
        ),
      ),
      PingLoading() => const Center(child: CircularProgressIndicator()),
      PingSuccess(payload: final p) => Card(
        color: Colors.green.shade900,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.greenAccent),
                  SizedBox(width: 8),
                  Text(
                    'API ping = OK',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Divider(),
              ...p.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${e.key}: ${e.value}',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      PingFailure(message: final m) => Card(
        color: Colors.red.shade900,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.error, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text(
                    'Ping failed',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Divider(),
              Text(m, style: const TextStyle(fontFamily: 'monospace')),
            ],
          ),
        ),
      ),
    };
  }
}
