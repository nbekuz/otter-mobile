import 'package:flutter/material.dart';

import '../../core/premium/premium_trial.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../shared/widgets/otter_checkbox.dart';

class PremiumOfferPanel extends StatelessWidget {
  const PremiumOfferPanel({
    super.key,
    required this.state,
    required this.recurringConsent,
    required this.onConsentChanged,
    required this.onClose,
    required this.onSelectTariff,
    required this.onTrial,
    required this.onCheckout,
    required this.onRefresh,
    required this.onCancel,
    this.useRustore = false,
    this.onSelectSubscription,
    this.onPurchase,
    this.onRestore,
    this.embeddedInCard = true,
  });

  final PremiumState state;
  final bool useRustore;
  final bool recurringConsent;
  final ValueChanged<bool?> onConsentChanged;
  final VoidCallback onClose;
  final ValueChanged<String> onSelectTariff;
  final ValueChanged<String>? onSelectSubscription;
  final VoidCallback onTrial;
  final VoidCallback onCheckout;
  final VoidCallback? onPurchase;
  final VoidCallback? onRestore;
  final VoidCallback onRefresh;
  final VoidCallback onCancel;
  final bool embeddedInCard;

  String? _formatExpires(String? value) {
    if (value == null || value.isEmpty) return null;
    final date = DateTime.tryParse(value);
    if (date == null) return null;
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  Widget _trialPromoBanner(int promoDays) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: OtterColors.sberGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OtterColors.sberGreen.withValues(alpha: 0.35)),
      ),
      child: Text(
        'Попробуйте $promoDays дней бесплатно — один раз для каждого аккаунта',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: OtterColors.sberGreen,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _trialButton({required int promoDays, required bool busy}) {
    return OutlinedButton(
      onPressed: busy ? null : onTrial,
      style: OutlinedButton.styleFrom(
        foregroundColor: OtterColors.sberGreen,
        side: const BorderSide(color: OtterColors.sberGreen),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(
        busy ? 'Активация…' : 'Попробовать $promoDays дней бесплатно',
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedTariff;
    final selectedStore = state.selectedSubscription;
    final isPremium = state.isPremium;
    final expires = _formatExpires(state.subscription?.expiresAt);
    final needsConsent = !useRustore && selected?.isRecurring == true;
    final isDark = OtterColors.isDarkOf(context);
    final busy = state.actionLoading || state.purchaseInProgress;
    final canTrial = canStartPremiumTrial(state.subscription);
    final promoDays = effectivePromoDays(
      selected,
      subscription: state.subscription,
    );

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Оттер Premium',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (state.loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            ...state.features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check, color: Colors.amber, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f.title)),
                  ],
                ),
              ),
            ),
            if (isPremium) ...[
              const SizedBox(height: 8),
              Text(
                state.subscription?.status == 'trial'
                    ? 'Пробный период активен'
                    : 'Premium активен',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: OtterColors.sberGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (expires != null)
                Text(
                  'Срок до $expires',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: OtterColors.sberGray,
                  ),
                ),
              if (state.subscription?.recurringEnabled == true &&
                  state.subscription?.cancelledAt == null) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: busy ? null : onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: Text(
                    busy ? 'Отмена…' : 'Отменить автопродление',
                  ),
                ),
              ],
              TextButton(
                onPressed: busy ? null : onRefresh,
                child: Text(busy ? 'Обновление…' : 'Обновить статус'),
              ),
              if (useRustore && onRestore != null)
                TextButton(
                  onPressed: busy ? null : onRestore,
                  child: Text(
                    busy ? 'Восстановление…' : 'Восстановить покупки',
                  ),
                ),
            ] else ...[
              if (canTrial && promoDays > 0) _trialPromoBanner(promoDays),
              if (useRustore) ...[
                const SizedBox(height: 4),
                if (state.subscriptions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Не удалось загрузить тарифы из RuStore. '
                      'Проверьте интернет и попробуйте снова.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: OtterColors.sberGray,
                      ),
                    ),
                  )
                else
                  for (final product in state.subscriptions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: selectedStore?.productId == product.productId
                            ? (isDark
                                ? const Color(0x33FBBF24)
                                : Colors.amber.shade50)
                            : OtterColors.elevated(isDark),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () =>
                              onSelectSubscription?.call(product.productId),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (product.description.isNotEmpty)
                                        Text(
                                          product.description,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: OtterColors.sberGray,
                                          ),
                                        ),
                                      Text(
                                        'Период: ${product.periodLabel}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: OtterColors.sberGray,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  product.priceLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                if (canTrial && promoDays > 0) ...[
                  _trialButton(promoDays: promoDays, busy: busy),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: busy || state.subscriptions.isEmpty
                      ? null
                      : onPurchase,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber.shade600,
                  ),
                  child: Text(
                    busy
                        ? 'Покупка…'
                        : 'Купить ${selectedStore?.priceLabel ?? 'Premium'}',
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : onRestore,
                  child: Text(
                    busy ? 'Восстановление…' : 'Восстановить покупки',
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : onRefresh,
                  child: Text(
                    busy ? 'Проверяем…' : 'Обновить статус',
                  ),
                ),
                const Text(
                  'Premium активируется после подтверждения покупки на сервере.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: OtterColors.sberGray,
                  ),
                ),
              ] else ...[
                if (state.tariffs.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  for (final tariff in state.tariffs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: selected?.code == tariff.code
                            ? (isDark
                                ? const Color(0x33FBBF24)
                                : Colors.amber.shade50)
                            : OtterColors.elevated(isDark),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => onSelectTariff(tariff.code),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tariff.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (canTrial &&
                                          effectivePromoDays(
                                                tariff,
                                                subscription:
                                                    state.subscription,
                                              ) >
                                              0)
                                        Text(
                                          '${effectivePromoDays(tariff, subscription: state.subscription)} дней бесплатно',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: OtterColors.sberGreen,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  tariff.priceLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
                if (needsConsent) ...[
                  OtterCheckbox(
                    value: recurringConsent,
                    onChanged: onConsentChanged,
                    child: const Text(
                      'Я согласен на автоматические списания согласно условиям оферты',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (canTrial && promoDays > 0) ...[
                  _trialButton(promoDays: promoDays, busy: busy),
                  const SizedBox(height: 8),
                ],
                FilledButton(
                  onPressed: busy ? null : onCheckout,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber.shade600,
                  ),
                  child: Text(
                    busy
                        ? 'Открываем оплату…'
                        : 'Оплатить ${selected?.priceLabel ?? 'Premium'}',
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : onRefresh,
                  child: Text(
                    busy ? 'Проверяем…' : 'Я оплатил — обновить статус',
                  ),
                ),
                const Text(
                  'После оплаты Premium включается автоматически. '
                  'Если статус не обновился — нажмите «обновить статус».',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: OtterColors.sberGray,
                  ),
                ),
              ],
            ],
          ],
          if (state.purchaseError != null) ...[
            const SizedBox(height: 8),
            Text(
              state.purchaseError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
          if (state.error != null) ...[
            const SizedBox(height: 8),
            Text(
              state.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
          TextButton(onPressed: onClose, child: const Text('Закрыть')),
        ],
      ),
    );

    if (!embeddedInCard) {
      return SingleChildScrollView(child: content);
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: content,
    );
  }
}
