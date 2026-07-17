import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';

Future<PremiumPaymentPollingResult?> showWindowsPremiumPaymentDialog({
  required BuildContext context,
}) {
  return showDialog<PremiumPaymentPollingResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _WindowsPremiumPaymentDialog(),
  );
}

class _WindowsPremiumPaymentDialog extends ConsumerStatefulWidget {
  const _WindowsPremiumPaymentDialog();

  @override
  ConsumerState<_WindowsPremiumPaymentDialog> createState() =>
      _WindowsPremiumPaymentDialogState();
}

class _WindowsPremiumPaymentDialogState
    extends ConsumerState<_WindowsPremiumPaymentDialog>
    with WidgetsBindingObserver {
  var _closed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future<void>.microtask(_waitForPayment);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(premiumStateProvider.notifier).wakePaymentPolling();
    }
  }

  Future<void> _waitForPayment() async {
    final result = await ref
        .read(premiumStateProvider.notifier)
        .pollForPayment();
    if (!_closed && mounted) {
      _closed = true;
      Navigator.of(context).pop(result);
    }
  }

  void _stopWaiting() {
    if (_closed) return;
    _closed = true;
    ref.read(premiumStateProvider.notifier).cancelPaymentPolling();
    Navigator.of(context).pop(PremiumPaymentPollingResult.stopped);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_closed) {
      ref.read(premiumStateProvider.notifier).cancelPaymentPolling();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final premium = ref.watch(premiumStateProvider);

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Ожидаем оплату'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: OtterColors.sberGreen),
              const SizedBox(height: 20),
              Text(
                premium.paymentPollingMessage ?? 'Завершите оплату в браузере.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Это окно закроется автоматически после подтверждения платежа.',
                textAlign: TextAlign.center,
                style: TextStyle(color: OtterColors.sberGray, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _stopWaiting,
            child: const Text('Прекратить ожидание'),
          ),
        ],
      ),
    );
  }
}
