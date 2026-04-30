import 'package:flutter/material.dart';

import 'package:storybox_app/flavors.dart';
import 'package:storybox_app/screens/ping_screen.dart';

/// Корень UI-дерева. Темы / роутер / Riverpod scope подключаются здесь.
///
/// На Phase 0.3 — минимальная реализация: один экран `PingScreen` для
/// проверки связи с backend. В Phase 1+ заменим на `go_router` с реальными
/// экранами (splash → onboarding → auth → home).
class StoryBoxApp extends StatelessWidget {
  const StoryBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: const PingScreen(),
    );
  }
}
