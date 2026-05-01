/// Экран ввода 6-digit OTP. Шаг 2 OTP-флоу.
///
/// При наборе 6 цифр автоматически вызывает verifyOtp.
/// Resend и кнопка «Назад» обрабатываются через AuthNotifier.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:storybox_app/presentation/auth/auth_provider.dart';
import 'package:storybox_app/presentation/auth/auth_state.dart';

class OtpInputScreen extends ConsumerStatefulWidget {
  const OtpInputScreen({super.key});

  @override
  ConsumerState<OtpInputScreen> createState() => _OtpInputScreenState();
}

class _OtpInputScreenState extends ConsumerState<OtpInputScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);

    final phone = switch (auth) {
      OtpSent(phone: final p) => p,
      VerifyingOtp(phone: final p) => p,
      AuthFailed(previous: OtpSent(phone: final p)) => p,
      AuthFailed(previous: VerifyingOtp(phone: final p)) => p,
      _ => null,
    };

    if (phone == null) {
      // Состояние не подходит — отрисовываем placeholder. Router должен
      // редиректить на phone screen.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isBusy = auth is VerifyingOtp;
    final failed = auth is AuthFailed ? auth : null;
    final isInvalidOtp = failed?.errorCode == 'INVALID_OTP';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: isBusy
              ? null
              : () =>
                    ref.read(authNotifierProvider.notifier).backToPhoneInput(),
        ),
        title: const Text('Подтверждение'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              'Введите код',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Мы отправили 6-значный код на $phone',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: !isBusy,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, letterSpacing: 8),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '——————',
                border: const OutlineInputBorder(),
                counter: const SizedBox.shrink(),
                errorText: isInvalidOtp ? failed?.message : null,
              ),
              onChanged: _onChanged,
            ),
            const SizedBox(height: 24),
            if (isBusy)
              const Center(child: CircularProgressIndicator())
            else
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Подтвердить'),
                onPressed: _controller.text.length == 6 ? _onConfirm : null,
              ),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Отправить ещё раз'),
              onPressed: isBusy
                  ? null
                  : () => ref.read(authNotifierProvider.notifier).resendOtp(),
            ),
            if (failed != null && !isInvalidOtp)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _ErrorBanner(message: failed.message),
              ),
          ],
        ),
      ),
    );
  }

  void _onChanged(String value) {
    if (value.length == 6) {
      _onConfirm();
    } else {
      // Re-render для обновления `onPressed: ... ? _onConfirm : null`.
      setState(() {});
    }
  }

  void _onConfirm() {
    final auth = ref.read(authNotifierProvider);
    final phone = switch (auth) {
      OtpSent(phone: final p) => p,
      VerifyingOtp(phone: final p) => p,
      AuthFailed(previous: OtpSent(phone: final p)) => p,
      _ => null,
    };
    if (phone == null) return;

    unawaited(
      ref
          .read(authNotifierProvider.notifier)
          .verifyOtp(phone: phone, code: _controller.text),
    );
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
