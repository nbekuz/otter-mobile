import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers/legal_provider.dart';
import '../../core/theme/otter_colors.dart';
import '../../data/legal/static_legal_documents.dart';
import '../../data/models/api/api_models.dart';

class LegalScreen extends ConsumerStatefulWidget {
  const LegalScreen({super.key});

  @override
  ConsumerState<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends ConsumerState<LegalScreen> {
  @override
  Widget build(BuildContext context) {
    final legal = ref.watch(legalProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? OtterColors.darkBg : OtterColors.grayLight;
    final surface = isDark ? OtterColors.darkSurface : Colors.white;
    final selected = legal.selectedDocument;

    return Scaffold(
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
                      if (selected != null) {
                        ref.read(legalProvider.notifier).clearSelection();
                      } else if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/app');
                      }
                    },
                    icon: const Icon(LucideIcons.chevronLeft),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? OtterColors.darkSurfaceAlt
                          : OtterColors.grayLight,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selected?.title ?? 'Юридические документы',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? OtterColors.darkText
                            : OtterColors.sberBlack,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: selected != null
                  ? _DocumentDetail(doc: selected, surface: surface)
                  : _DocumentsHub(surface: surface),
            ),
          ],
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final doc in hubStaticLegalDocuments)
          Card(
            color: surface,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(
                LucideIcons.fileText,
                color: OtterColors.sberGray,
              ),
              title: Text(
                doc.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                formatStaticLegalUpdatedAt(doc.updatedAt) ?? doc.updatedAt,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(
                LucideIcons.chevronRight,
                color: OtterColors.sberGray,
              ),
              onTap: () => context.push('/legal/${doc.slug.id}'),
            ),
          ),
      ],
    );
  }
}

class _DocumentDetail extends StatelessWidget {
  const _DocumentDetail({required this.doc, required this.surface});

  final ApiLegalDocument doc;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    final updated = formatLegalUpdatedAt(doc.updatedAt);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (updated != null) ...[
                Text(
                  'Обновлено: $updated',
                  style: const TextStyle(
                    fontSize: 12,
                    color: OtterColors.sberGray,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                doc.content,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: OtterColors.sberGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
