import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/billing/billing_exceptions.dart';
import '../../core/billing/premium_billing.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers/providers.dart';
import '../../core/utils/open_url.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../settings/windows_premium_payment_dialog.dart';
import 'premium_offer_panel.dart';

/// Opens Premium paywall in-place (keeps current screen — e.g. task editor).
Future<void> showPremiumOfferSheet(BuildContext context) {
  if (isAndroidPremiumPurchaseBlocked) {
    return Future.value();
  }
  return showAppBottomSheet<void>(
    context: context,
    dialogMaxWidth: 560,
    builder: (ctx) => const PremiumOfferSheet(),
  );
}

class PremiumOfferSheet extends ConsumerStatefulWidget {
  const PremiumOfferSheet({super.key});

  @override
  ConsumerState<PremiumOfferSheet> createState() => _PremiumOfferSheetState();
}

class _PremiumOfferSheetState extends ConsumerState<PremiumOfferSheet> {
  bool _recurringConsent = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(premiumStateProvider.notifier).loadAll(),
    );
  }

  Future<void> _startTrial() async {
    final tariff = ref.read(premiumStateProvider).selectedTariff;
    if (tariff?.isRecurring == true && !_recurringConsent) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Подтвердите согласие на автоматические списания'),
        ),
      );
      return;
    }
    try {
      await ref
          .read(premiumStateProvider.notifier)
          .startTrial(recurringConsent: _recurringConsent);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пробный период Premium активирован')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getApiErrorMessage(e))),
      );
    }
  }

  Future<void> _purchasePremium() async {
    if (isRustoreBillingActive) {
      await _purchaseRustore();
      return;
    }

    final tariff = ref.read(premiumStateProvider).selectedTariff;
    if (tariff?.isRecurring == true && !_recurringConsent) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Подтвердите согласие на автоматические списания'),
        ),
      );
      return;
    }
    try {
      final url = await ref
          .read(premiumStateProvider.notifier)
          .checkout(recurringConsent: _recurringConsent);
      if (!mounted || url.isEmpty) return;
      final opened = await openExternalUrl(url);
      if (!mounted) return;
      if (Platform.isWindows && opened) {
        final result = await showWindowsPremiumPaymentDialog(context: context);
        if (!mounted) return;
        switch (result) {
          case PremiumPaymentPollingResult.success:
            Navigator.pop(context);
            unawaited(ref.read(appSettingsProvider.notifier).load());
            unawaited(ref.read(authStateProvider.notifier).refreshProfile());
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Premium успешно активирован')),
            );
          case PremiumPaymentPollingResult.cancelled:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Платёж отменён')),
            );
          case PremiumPaymentPollingResult.timeout:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Время ожидания истекло. Статус можно обновить вручную.',
                ),
              ),
            );
          case PremiumPaymentPollingResult.fatalError:
            final error = ref.read(premiumStateProvider).error;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error ?? 'Не удалось проверить статус платежа'),
              ),
            );
          case PremiumPaymentPollingResult.stopped:
          case null:
            break;
        }
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            opened
                ? 'Откройте оплату. После оплаты нажмите «Обновить статус».'
                : 'Не удалось открыть ссылку. Скопируйте её вручную.',
          ),
          duration: const Duration(seconds: 5),
          action: opened
              ? null
              : SnackBarAction(
                  label: 'Копировать',
                  onPressed: () => Clipboard.setData(ClipboardData(text: url)),
                ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(getApiErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _purchaseRustore() async {
    try {
      await ref.read(premiumStateProvider.notifier).purchaseSelected();
      if (!mounted) return;
      unawaited(ref.read(appSettingsProvider.notifier).load());
      unawaited(ref.read(authStateProvider.notifier).refreshProfile());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Premium успешно активирован')),
      );
      Navigator.pop(context);
    } on PurchaseCancelledException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = ref.read(premiumStateProvider).purchaseError ??
          billingErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  Future<void> _restoreRustore() async {
    try {
      await ref.read(premiumStateProvider.notifier).restorePurchases();
      if (!mounted) return;
      unawaited(ref.read(appSettingsProvider.notifier).load());
      unawaited(ref.read(authStateProvider.notifier).refreshProfile());
      final isPremium = ref.read(premiumStateProvider).isPremium;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPremium
                ? 'Покупки восстановлены. Premium активен.'
                : 'Покупки проверены.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = ref.read(premiumStateProvider).purchaseError ??
          billingErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  Future<void> _refreshPremium() async {
    try {
      await ref.read(premiumStateProvider.notifier).loadAll();
      if (!mounted) return;
      final sub = ref.read(premiumStateProvider);
      final isPremium = sub.isPremium;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPremium
                ? 'Premium активен'
                : 'Статус обновлён. Premium пока не активен.',
          ),
        ),
      );
      if (isPremium) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getApiErrorMessage(e))),
      );
    }
  }

  Future<void> _cancelPremium() async {
    try {
      await ref.read(premiumStateProvider.notifier).cancel();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Автопродление отключено. Доступ сохранится до конца периода.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getApiErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final premium = ref.watch(premiumStateProvider);
    return PremiumOfferPanel(
      state: premium,
      embeddedInCard: false,
      useRustore: isRustoreBillingActive,
      recurringConsent: _recurringConsent,
      onConsentChanged: (v) => setState(() => _recurringConsent = v ?? false),
      onClose: () => Navigator.pop(context),
      onSelectTariff: (code) =>
          ref.read(premiumStateProvider.notifier).selectTariff(code),
      onSelectSubscription: (productId) => ref
          .read(premiumStateProvider.notifier)
          .selectSubscription(productId),
      onTrial: _startTrial,
      onCheckout: _purchasePremium,
      onPurchase: _purchaseRustore,
      onRestore: _restoreRustore,
      onRefresh: _refreshPremium,
      onCancel: _cancelPremium,
    );
  }
}
