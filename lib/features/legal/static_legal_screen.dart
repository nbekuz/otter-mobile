import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/layout/responsive.dart';
import '../../core/theme/otter_colors.dart';
import '../../data/legal/static_legal_documents.dart';

class StaticLegalScreen extends StatefulWidget {
  const StaticLegalScreen({super.key, required this.slug});

  final String slug;

  @override
  State<StaticLegalScreen> createState() => _StaticLegalScreenState();
}

class _StaticLegalScreenState extends State<StaticLegalScreen> {
  String? _content;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = staticLegalDocumentById(widget.slug);
    if (doc == null) {
      setState(() => _error = 'Документ не найден');
      return;
    }
    try {
      final content = await loadStaticLegalMarkdown(doc);
      if (mounted) setState(() => _content = content);
    } catch (e) {
      if (mounted) setState(() => _error = 'Не удалось загрузить документ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = staticLegalDocumentById(widget.slug);
    final updated = doc == null
        ? null
        : formatStaticLegalUpdatedAt(doc.updatedAt);
    final blocks = _content == null
        ? const <LegalContentBlock>[]
        : parseLegalMarkdown(_content!);

    return Scaffold(
      backgroundColor: OtterColors.grayLight,
      body: SafeArea(
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
                        context.go('/');
                      }
                    },
                    icon: const Icon(LucideIcons.chevronLeft),
                    style: IconButton.styleFrom(
                      backgroundColor: OtterColors.grayLight,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      doc?.title ?? 'Документ',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ResponsiveContent(
                maxWidth: 800,
                child: _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : _content == null
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          if (updated != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Обновлено: $updated',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: OtterColors.sberGray,
                                ),
                              ),
                            ),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: blocks.map((block) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Text(
                                      block.text,
                                      style: TextStyle(
                                        fontSize:
                                            block.kind == LegalBlockKind.heading
                                            ? 18
                                            : block.kind ==
                                                  LegalBlockKind.subheading
                                            ? 16
                                            : 14,
                                        height: 1.55,
                                        fontWeight:
                                            block.kind ==
                                                LegalBlockKind.paragraph
                                            ? FontWeight.normal
                                            : FontWeight.w600,
                                        color:
                                            block.kind ==
                                                LegalBlockKind.paragraph
                                            ? OtterColors.sberGray
                                            : OtterColors.sberBlack,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
