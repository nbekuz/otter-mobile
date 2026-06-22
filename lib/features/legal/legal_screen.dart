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
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(legalProvider.notifier).load());
  }

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
                      } else {
                        context.pop();
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
                  : _DocumentsHub(
                      apiDocuments: legal.documents,
                      apiLoading: legal.loading,
                      apiError: legal.error,
                      surface: surface,
                      onSelectApi: (index) => ref
                          .read(legalProvider.notifier)
                          .selectDocument(index),
                      onRetryApi: () => ref.read(legalProvider.notifier).load(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentsHub extends StatelessWidget {
  const _DocumentsHub({
    required this.apiDocuments,
    required this.apiLoading,
    required this.apiError,
    required this.surface,
    required this.onSelectApi,
    required this.onRetryApi,
  });

  final List<ApiLegalDocument> apiDocuments;
  final bool apiLoading;
  final String? apiError;
  final Color surface;
  final void Function(int index) onSelectApi;
  final VoidCallback onRetryApi;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final doc in staticLegalDocuments) ...[
          Card(
            color: surface,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(LucideIcons.fileText, color: OtterColors.sberGray),
              title: Text(
                doc.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('17.06.2026', style: TextStyle(fontSize: 12)),
              trailing: const Icon(
                LucideIcons.chevronRight,
                color: OtterColors.sberGray,
              ),
              onTap: () => context.push('/legal/${doc.slug.id}'),
            ),
          ),
        ],
        if (apiLoading && apiDocuments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (apiError != null && apiDocuments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Text(apiError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                TextButton(onPressed: onRetryApi, child: const Text('Повторить')),
              ],
            ),
          ),
        if (apiDocuments.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text(
              'С сервера',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: OtterColors.sberGray,
              ),
            ),
          ),
          ...List.generate(apiDocuments.length, (index) {
            final doc = apiDocuments[index];
            final subtitle = legalDocTypeLabel(doc.docType);
            return Card(
              color: surface,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(LucideIcons.fileText, color: OtterColors.sberGray),
                title: Text(
                  doc.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: subtitle != doc.docType
                    ? Text(subtitle, style: const TextStyle(fontSize: 12))
                    : null,
                trailing: const Icon(
                  LucideIcons.chevronRight,
                  color: OtterColors.sberGray,
                ),
                onTap: () => onSelectApi(index),
              ),
            );
          }),
        ],
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
