import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/layout/responsive.dart';
import '../../core/theme/otter_colors.dart';
import '../../shared/widgets/brand_logo.dart';
import '../../shared/widgets/legal_acceptance_text.dart';
import '../../shared/widgets/primary_button.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  static const _features = [
    (
      LucideIcons.checkSquare,
      'Задачи',
      'Группировка и быстрые действия',
      Color(0xFFE8F7EB),
      OtterColors.sberGreen,
    ),
    (
      LucideIcons.calendar,
      'Календарь',
      'День, неделя, месяц и год',
      Color(0xFFE5F1FF),
      OtterColors.sberBlue,
    ),
    (
      LucideIcons.grid,
      'Матрица',
      'Приоритеты по Эйзенхауэру',
      Color(0xFFF3E8FF),
      Color(0xFF9333EA),
    ),
    (
      LucideIcons.timer,
      'Помодоро',
      'Фокус и таймер',
      Color(0xFFFEE2E2),
      OtterColors.priorityHigh,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = Responsive.isWide(context);

    return ResponsivePage(
      maxWidth: wide ? 960 : null,
      child: wide ? _WideLayout(features: _features) : _MobileLayout(features: _features),
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({required this.features});

  final List<(IconData, String, String, Color, Color)> features;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: BrandLogo(size: LogoSize.lg, showName: true)),
        const SizedBox(height: 16),
        const Text(
          'Планировщик задач для тех, кто ценит время',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            height: 1.4,
            color: OtterColors.sberGray,
          ),
        ),
        const SizedBox(height: 32),
        ...features.map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _FeatureTile(
              icon: f.$1,
              title: f.$2,
              subtitle: f.$3,
              iconBg: f.$4,
              iconColor: f.$5,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'FAQ и документы — после входа в «Настройки»',
          textAlign: TextAlign.center,
          style: TextStyle(color: OtterColors.sberGray, fontSize: 12),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Войти',
          onPressed: () => context.push('/login'),
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Регистрация',
          outline: true,
          onPressed: () => context.push('/register'),
        ),
        const SizedBox(height: 16),
        const LegalAcceptanceText(),
      ],
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.features});

  final List<(IconData, String, String, Color, Color)> features;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandLogo(size: LogoSize.lg, showName: true),
              const SizedBox(height: 24),
              const Text(
                'Планировщик задач для тех, кто ценит время',
                style: TextStyle(
                  fontSize: 28,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: OtterColors.sberBlack,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Задачи, календарь, матрица Эйзенхауэра и помодоро — в одном приложении для Windows и Android.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: OtterColors.sberGray,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: 'Войти',
                      onPressed: () => context.push('/login'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Регистрация',
                      outline: true,
                      onPressed: () => context.push('/register'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const LegalAcceptanceText(textAlign: TextAlign.start),
            ],
          ),
        ),
        const SizedBox(width: 48),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              for (final f in features)
                _FeatureTile(
                  icon: f.$1,
                  title: f.$2,
                  subtitle: f.$3,
                  iconBg: f.$4,
                  iconColor: f.$5,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconBg,
    required this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconBg;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OtterColors.grayLight,
        borderRadius: BorderRadius.circular(OtterColors.radiusLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: OtterColors.sberBlack,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: OtterColors.sberGray,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
