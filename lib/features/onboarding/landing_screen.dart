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
      OtterColors.sberGreen,
      OtterColors.sberGreenLight,
    ),
    (
      LucideIcons.calendar,
      'Календарь',
      'День, неделя, месяц и год',
      OtterColors.sberBlue,
      OtterColors.sberBlueLight,
    ),
    (
      LucideIcons.grid,
      'Матрица',
      'Приоритеты по Эйзенхауэру',
      Color(0xFF9333EA),
      Color(0xFFF3E8FF),
    ),
    (
      LucideIcons.timer,
      'Помодоро',
      'Фокус и таймер',
      OtterColors.priorityHigh,
      Color(0xFFFEE2E2),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = Responsive.isWide(context);
    final isDark = OtterColors.isDarkOf(context);

    return ResponsivePage(
      maxWidth: wide ? 960 : null,
      child: wide
          ? _WideLayout(features: _features, isDark: isDark)
          : _MobileLayout(features: _features, isDark: isDark),
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({required this.features, required this.isDark});

  final List<(IconData, String, String, Color, Color)> features;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: BrandLogo(size: LogoSize.lg, showName: true)),
        const SizedBox(height: 16),
        Text(
          'Планировщик задач для тех, кто ценит время',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            height: 1.4,
            color: OtterColors.muted(isDark),
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
              accent: f.$4,
              lightIconBg: f.$5,
              isDark: isDark,
            ),
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Войти', onPressed: () => context.push('/login')),
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
  const _WideLayout({required this.features, required this.isDark});

  final List<(IconData, String, String, Color, Color)> features;
  final bool isDark;

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
              Text(
                'Планировщик задач для тех, кто ценит время',
                style: TextStyle(
                  fontSize: 28,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: OtterColors.text(isDark),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Задачи, календарь, матрица Эйзенхауэра и помодоро — в одном приложении для Windows и Android.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: OtterColors.muted(isDark),
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
                  accent: f.$4,
                  lightIconBg: f.$5,
                  isDark: isDark,
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
    required this.accent,
    required this.lightIconBg,
    required this.isDark,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Color lightIconBg;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final iconBg = OtterColors.softTint(isDark, accent, light: lightIconBg);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OtterColors.elevated(isDark),
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
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: OtterColors.text(isDark),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: OtterColors.muted(isDark),
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
