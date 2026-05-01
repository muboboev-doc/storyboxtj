/// Корень UI-дерева. Phase 1.7: добавляет go_router с auth-aware redirect.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:storybox_app/flavors.dart';
import 'package:storybox_app/presentation/auth/auth_provider.dart';
import 'package:storybox_app/presentation/auth/auth_state.dart';
import 'package:storybox_app/presentation/auth/otp_input_screen.dart';
import 'package:storybox_app/presentation/auth/phone_otp_screen.dart';
import 'package:storybox_app/presentation/home/home_placeholder_screen.dart';

class StoryBoxApp extends ConsumerWidget {
  const StoryBoxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);

    return MaterialApp.router(
      title: kAppConfig.name,
      debugShowCheckedModeBanner: kAppConfig.isDev,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE63946),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      routerConfig: router,
    );
  }
}

// ─── Router ──────────────────────────────────────────────────────────────────

final _routerProvider = Provider<GoRouter>((ref) {
  // Слушаем authState для триггера redirect-логики на каждом изменении.
  ref.listen<AuthState>(authNotifierProvider, (_, _) {});

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final auth = ref.read(authNotifierProvider);
      final loc = state.matchedLocation;

      return switch (auth) {
        AuthUnknown() => loc == '/splash' ? null : '/splash',
        Unauthenticated() => loc == '/login' ? null : '/login',
        RequestingOtp() => loc == '/login' ? null : '/login',
        OtpSent() => loc == '/otp' ? null : '/otp',
        VerifyingOtp() => loc == '/otp' ? null : '/otp',
        AuthFailed(previous: OtpSent()) => loc == '/otp' ? null : '/otp',
        AuthFailed() => loc == '/login' ? null : '/login',
        Authenticated() => loc.startsWith('/home') ? null : '/home',
      };
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const PhoneOtpScreen()),
      GoRoute(path: '/otp', builder: (_, _) => const OtpInputScreen()),
      GoRoute(path: '/home', builder: (_, _) => const HomePlaceholderScreen()),
    ],
  );
});

/// Bridge между Riverpod state и GoRouter.refreshListenable.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _ref.listen<AuthState>(authNotifierProvider, (_, _) => notifyListeners());
  }
  final Ref _ref;
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('StoryBox'),
          ],
        ),
      ),
    );
  }
}
