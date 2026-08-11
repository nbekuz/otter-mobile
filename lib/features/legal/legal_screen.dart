import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/layout/responsive.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../core/theme/otter_theme.dart';
import '../../data/legal/static_legal_documents.dart';

/// Hub of static legal documents (same sources as web /legal/*).
/// Opens each doc via [StaticLegalScreen] — never the outdated API payload.
class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark =
        ref.watch(appSettingsProvider.select((s) => s.theme == 'dark'));
    final bg = OtterColors.pageBg(isDark);
    final surface = OtterColors.surface(isDark);
    final titleColor = OtterColors.text(isDark);

    return Theme(
      data: isDark ? OtterTheme.dark() : OtterTheme.light(),
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/app');
                        }
                      },
                      icon: Icon(LucideIcons.chevronLeft, color: titleColor),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? OtterColors.darkSurfaceAlt
                            : OtterColors.grayLight,
                        foregroundColor: titleColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Юридические документы',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _DocumentsHub(surface: surface)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentsHub extends StatelessWidget {
  const _DocumentsHub({required this.surface});

  final Color surface;

  @override
  Widget build(BuildContext context) {
    final wide = Responsive.isWide(context);
    final isDark = OtterColors.isDarkOf(context);
    final textColor = OtterColors.text(isDark);
    final muted = OtterColors.muted(isDark);

    return ResponsiveContent(
      maxWidth: wide ? 1400 : Responsive.pageMaxWidth(context),
      padding: EdgeInsets.symmetric(
        horizontal: wide ? 24 : 16,
        vertical: 16,
      ),
      child: ListView(
        children: [
          for (final doc in hubStaticLegalDocuments)
            Card(
              color: surface,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  LucideIcons.fileText,
                  color: muted,
                ),
                title: Text(
                  doc.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                subtitle: Text(
                  formatStaticLegalUpdatedAt(doc.updatedAt) ?? doc.updatedAt,
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                trailing: Icon(
                  LucideIcons.chevronRight,
                  color: muted,
                ),
                onTap: () => context.push('/legal/${doc.slug.id}'),
              ),
            ),
        ],
      ),
    );
  }
}
