import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/premium/premium_offer_sheet.dart';
import '../network/api_exception.dart';
import '../providers/providers.dart';

/// User-facing copy when API returns `PREMIUM_REQUIRED`.
abstract final class PremiumRequiredMessages {
  static const pomodoro = 'Таймер Помодоро доступен с подключенным Premium';
  static const calendar = 'Календарь доступен с подключенным Premium';
  static const matrix = 'Матрица Эйзенхауэра доступна с подключенным Premium';
  static const generic = 'Доступно только с Premium';
}

const _premiumNavPaths = {
  '/app/calendar',
  '/app/matrix',
  '/app/pomodoro',
};

bool isPremiumRequiredError(Object error) =>
    error is ApiException && error.code == 'PREMIUM_REQUIRED';

bool isPremiumNavPath(String path) {
  final normalized = path.endsWith('/') && path.length > 1
      ? path.substring(0, path.length - 1)
      : path;
  if (_premiumNavPaths.contains(normalized)) return true;
  return normalized.startsWith('/app/calendar/') ||
      normalized.startsWith('/app/matrix/') ||
      normalized.startsWith('/app/pomodoro/');
}

bool isPremiumActive(WidgetRef ref) {
  final settings = ref.read(appSettingsProvider);
  final premium = ref.read(premiumStateProvider);
  return premium.isPremium || settings.isPremium;
}

void openPremiumSubscription(BuildContext context) {
  showPremiumOfferSheet(context);
}

/// Returns `true` when the user may mutate premium-gated content.
bool requirePremiumSubscription(BuildContext context, WidgetRef ref) {
  if (isPremiumActive(ref)) return true;
  openPremiumSubscription(context);
  return false;
}

Future<void> navigateAppTab(
  BuildContext context,
  WidgetRef ref,
  String path,
) async {
  if (!isPremiumNavPath(path)) {
    context.go(path);
    return;
  }

  if (!isPremiumActive(ref)) {
    await ref.read(premiumStateProvider.notifier).ensureSubscription();
  }

  if (!context.mounted) return;

  if (isPremiumActive(ref)) {
    context.go(path);
    return;
  }

  openPremiumSubscription(context);
}

void showPremiumRequiredModal(BuildContext context, String feature) {
  openPremiumSubscription(context);
}

String premiumRequiredMessageFor(Object error, String featureMessage) {
  if (isPremiumRequiredError(error)) return featureMessage;
  return getApiErrorMessage(error);
}
