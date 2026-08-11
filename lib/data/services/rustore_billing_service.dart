import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_rustore_billing/flutter_rustore_billing.dart';
import 'package:flutter_rustore_billing/pigeons/rustore.dart' as rustore;

import '../../core/billing/billing_exceptions.dart';
import '../../core/billing/billing_logger.dart';
import '../../core/billing/rustore_config.dart';
import '../../core/config/env.dart';
import '../models/billing/billing_purchase.dart';
import '../models/billing/subscription_product.dart';

/// Thin wrapper around the official RuStore Billing Flutter SDK.
class RuStoreBillingService {
  static bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (!Platform.isAndroid) {
      BillingLogger.info('initialize skipped (not Android)');
      return;
    }
    if (_initialized) {
      BillingLogger.info('initialize skipped (already done)');
      return;
    }

    final consoleId = Env.rustoreConsoleAppId.trim();
    if (consoleId.isEmpty) {
      BillingLogger.error('RUSTORE_CONSOLE_APP_ID is empty');
      throw const BillingUnavailableException(
        'RuStore Billing не настроен (нет RUSTORE_CONSOLE_APP_ID).',
      );
    }

    BillingLogger.info('Billing initialization started (consoleId=$consoleId)');
    try {
      await RustoreBillingClient.initialize(
        consoleId,
        RuStoreConfig.deeplinkUri,
        kDebugMode,
      );
      _initialized = true;
      BillingLogger.info('Billing initialization success');
    } catch (e, st) {
      BillingLogger.error('Billing initialization failed', e, st);
      throw BillingUnavailableException(
        'Не удалось инициализировать платежи RuStore.',
      );
    }
  }

  Future<void> _ensureReady() async {
    if (!Platform.isAndroid) {
      throw const BillingUnavailableException(
        'Платежи RuStore доступны только на Android.',
      );
    }
    if (!_initialized) {
      await initialize();
    }
  }

  Future<List<SubscriptionProduct>> getSubscriptions([
    List<String>? productIds,
  ]) async {
    await _ensureReady();
    final ids = (productIds == null || productIds.isEmpty)
        ? RuStoreConfig.productIds
        : productIds;
    BillingLogger.info('Loading products $ids');
    try {
      final response = await RustoreBillingClient.products(ids);
      if ((response.code ?? 0) != 0 && response.products.isEmpty) {
        final msg = response.errorMessage ??
            response.errorDescription ??
            'products error code=${response.code}';
        BillingLogger.error('Products load failed: $msg');
        throw ProductNotFoundException(msg);
      }

      final products = response.products
          .whereType<rustore.Product>()
          .map(_mapProduct)
          .toList();

      // Stable order matching requested product ids.
      products.sort((a, b) {
        final ai = ids.indexOf(a.productId);
        final bi = ids.indexOf(b.productId);
        return ai.compareTo(bi);
      });

      BillingLogger.info('Products loaded: ${products.length}');
      if (products.isEmpty) {
        throw const ProductNotFoundException();
      }
      return products;
    } on BillingException {
      rethrow;
    } catch (e, st) {
      BillingLogger.error('getSubscriptions failed', e, st);
      throw BillingNetworkException(billingErrorMessage(e));
    }
  }

  /// Starts RuStore Pay flow.
  ///
  /// [appUserId] must be the backend user id (string). Passed as
  /// `developerPayload` — flutter_rustore_billing has no separate appUserId.
  Future<PurchaseResult> purchase(
    String productId, {
    String? appUserId,
    String? orderId,
  }) async {
    await _ensureReady();
    BillingLogger.info(
      'Purchase started productId=$productId appUserId=$appUserId',
    );
    try {
      // Call pigeon API directly so orderId is forwarded (wrapper drops it).
      final result = await rustore.RustoreBilling().purchase(
            productId,
            developerPayload: appUserId,
            orderId: orderId,
          );

      final success = result.successPurchase;
      if (success != null) {
        final finish = (success.finishCode ?? '').toUpperCase();
        if (finish == 'CLOSED_BY_USER') {
          BillingLogger.info('Purchase cancelled by user');
          return PurchaseResult.cancelled();
        }
        if (finish.isNotEmpty &&
            finish != 'SUCCESSFUL_PAYMENT' &&
            finish != 'SUCCESS') {
          BillingLogger.error('Purchase finishCode=$finish');
          return PurchaseResult.failed(
            billingErrorMessage('purchase finishCode=$finish'),
          );
        }

        final purchaseId = success.purchaseId.trim();
        if (purchaseId.isEmpty) {
          BillingLogger.error('Purchase success without purchaseId');
          return PurchaseResult.failed(
            'RuStore не вернул purchaseId.',
          );
        }

        BillingLogger.info(
          'Purchase success purchaseId=$purchaseId '
          'orderId=${success.orderId}',
        );
        return PurchaseResult.success(
          productId: success.productId,
          purchaseId: purchaseId,
          orderId: success.orderId,
          subscriptionToken: success.subscriptionToken,
        );
      }

      final invoice = result.successInvoice;
      if (invoice != null) {
        final finish = invoice.finishCode.toUpperCase();
        if (finish == 'CLOSED_BY_USER') {
          return PurchaseResult.cancelled();
        }
        if (finish == 'SUCCESSFUL_PAYMENT' || finish == 'SUCCESS') {
          // Invoice-only success — resolve purchaseId from purchases list.
          final purchases = await getPurchases();
          final match = purchases.cast<BillingPurchase?>().firstWhere(
                (p) =>
                    p != null &&
                    p.productId == productId &&
                    p.isActive &&
                    (p.purchaseId ?? '').trim().isNotEmpty,
                orElse: () => null,
              );
          if (match != null) {
            return PurchaseResult.success(
              productId: productId,
              purchaseId: match.purchaseId!,
              orderId: match.orderId,
              subscriptionToken: match.subscriptionToken,
              purchase: match,
            );
          }
        }
        return PurchaseResult.failed(
          billingErrorMessage('invoice finishCode=${invoice.finishCode}'),
        );
      }

      final invalidPurchase = result.invalidPurchase;
      if (invalidPurchase != null) {
        BillingLogger.error(
          'InvalidPurchase errorCode=${invalidPurchase.errorCode}',
        );
        return PurchaseResult.failed(const BillingUnknownException().message);
      }

      if (result.invalidInvoice != null) {
        return PurchaseResult.failed(const BillingUnknownException().message);
      }

      return PurchaseResult.failed(const BillingUnknownException().message);
    } on BillingException {
      rethrow;
    } catch (e, st) {
      BillingLogger.error('Purchase failed', e, st);
      final msg = billingErrorMessage(e);
      if (msg == const PurchaseCancelledException().message) {
        return PurchaseResult.cancelled(msg);
      }
      return PurchaseResult.failed(msg);
    }
  }

  Future<List<BillingPurchase>> getPurchases() async {
    await _ensureReady();
    try {
      final response = await RustoreBillingClient.purchases();
      final list = response.purchases
          .whereType<rustore.Purchase>()
          .map(_mapPurchase)
          .toList();
      BillingLogger.info('Purchases loaded: ${list.length}');
      return list;
    } on BillingException {
      rethrow;
    } catch (e, st) {
      BillingLogger.error('getPurchases failed', e, st);
      throw BillingNetworkException(billingErrorMessage(e));
    }
  }

  /// Loads active subscription purchases (restore helper for the service API).
  /// Backend verify uses [BillingPurchase.purchaseId], not subscriptionToken.
  Future<List<BillingPurchase>> restorePurchases() async {
    BillingLogger.info('Restore purchases started');
    final purchases = await getPurchases();
    final active = purchases
        .where((p) => p.isSubscription && p.isActive && !p.isExpired)
        .where((p) => (p.purchaseId ?? '').trim().isNotEmpty)
        .toList();
    BillingLogger.info('Restore purchases found active=${active.length}');
    return active;
  }

  SubscriptionProduct _mapProduct(rustore.Product p) {
    return SubscriptionProduct(
      productId: p.productId,
      title: (p.title ?? '').trim().isEmpty
          ? _fallbackTitle(p.productId)
          : p.title!.trim(),
      description: (p.description ?? '').trim(),
      priceLabel: (p.priceLabel ?? '').trim().isEmpty
          ? _fallbackPrice(p)
          : p.priceLabel!.trim(),
      periodLabel: _periodLabel(p.subscription?.subscriptionPeriod, p.productId),
      currency: p.currency,
      rawPrice: p.price,
    );
  }

  BillingPurchase _mapPurchase(rustore.Purchase p) {
    return BillingPurchase(
      purchaseId: p.purchaseId,
      productId: p.productId,
      productType: p.productType,
      purchaseTime: p.purchaseTime,
      orderId: p.orderId,
      purchaseState: p.purchaseState,
      developerPayload: p.developerPayload,
      subscriptionToken: p.subscriptionToken,
      invoiceId: p.invoiceId,
    );
  }

  String _fallbackTitle(String productId) => switch (productId) {
        RuStoreConfig.yearlyProductId => 'Premium на год',
        _ => 'Premium на месяц',
      };

  String _fallbackPrice(rustore.Product p) {
    if (p.price == null) return '—';
    final major = (p.price! / 100).toStringAsFixed(0);
    return '$major ${p.currency ?? '₽'}';
  }

  String _periodLabel(rustore.SubscriptionPeriod? period, String productId) {
    if (period != null) {
      if (period.years > 0) {
        return period.years == 1 ? 'год' : '${period.years} г.';
      }
      if (period.months > 0) {
        return period.months == 1 ? 'месяц' : '${period.months} мес.';
      }
      if (period.days > 0) {
        return '${period.days} дн.';
      }
    }
    return productId == RuStoreConfig.yearlyProductId ? 'год' : 'месяц';
  }
}
