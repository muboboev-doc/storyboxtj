/// Экран ввода телефона. Шаг 1 OTP-флоу.
///
/// На submit вызывает `AuthNotifier.requestOtp`. Если успех — Riverpod-state
/// меняется на OtpSent, Router редиректит на `OtpInputScreen`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:storybox_app/flavors.dart';
import 'package:storybox_app/presentation/auth/auth_provider.dart';
import 'package:storybox_app/presentation/auth/auth_state.dart';

class PhoneOtpScreen extends ConsumerStatefulWidget {
  const PhoneOtpScreen({super.key});

  @override
  ConsumerState<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends ConsumerState<PhoneOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController(text: '+992');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final isBusy = auth is RequestingOtp;
    final failed = auth is AuthFailed ? auth : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(kAppConfig.name),
        actions: [
          if (kAppConfig.isDev)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  'DEV',
                  style: TextStyle(
                    color: Colors.amberAccent,
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Войти',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Мы отправим код на ваш номер.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _controller,
                enabled: !isBusy,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[+\d]')),
                  LengthLimitingTextInputFormatter(16),
                ],
                decoration: InputDecoration(
                  labelText: 'Номер телефона',
                  hintText: '+992901234567',
                  prefixIcon: const Icon(Icons.phone),
                  border: const OutlineInputBorder(),
                  errorText: failed?.errorCode == 'USER_BLOCKED'
                      ? failed?.message
                      : null,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Введите номер';
                  if (!RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(value)) {
                    return 'Формат: +992901234567';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(isBusy ? 'Отправляем...' : 'Получить код'),
                onPressed: isBusy ? null : _onSubmit,
              ),
              const SizedBox(height: 16),
              if (failed != null && failed.errorCode != 'USER_BLOCKED')
                _ErrorBanner(message: failed.message),
              const Spacer(),
              Text(
                'Нажимая «Получить код», вы соглашаетесь с условиями использования.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _onSubmit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final phone = _controller.text.trim();
    unawaited(ref.read(authNotifierProvider.notifier).requestOtp(phone));
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade900,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
