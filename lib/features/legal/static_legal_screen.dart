import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

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
    } catch (_) {
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
                                children: [
                                  for (final block in blocks)
                                    _LegalBlockView(block: block),
                                ],
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

class _LegalBlockView extends StatelessWidget {
  const _LegalBlockView({required this.block});

  final LegalContentBlock block;

  @override
  Widget build(BuildContext context) {
    if (block is LegalHeadingBlock) {
      final heading = block as LegalHeadingBlock;
      final fontSize = switch (heading.level) {
        1 => 18.0,
        2 => 16.0,
        _ => 14.0,
      };
      return Padding(
        padding: EdgeInsets.only(top: heading.level == 2 ? 8 : 4, bottom: 10),
        child: _LegalRichText(
          pieces: heading.pieces,
          style: TextStyle(
            fontSize: fontSize,
            height: 1.55,
            fontWeight: FontWeight.w600,
            color: OtterColors.sberBlack,
          ),
        ),
      );
    }

    if (block is LegalParagraphBlock) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _LegalRichText(
          pieces: (block as LegalParagraphBlock).pieces,
          style: const TextStyle(
            fontSize: 14,
            height: 1.55,
            color: OtterColors.sberGray,
          ),
        ),
      );
    }

    if (block is LegalListBlock) {
      final list = block as LegalListBlock;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in list.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '•  ',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.55,
                        color: OtterColors.sberGray,
                      ),
                    ),
                    Expanded(
                      child: _LegalRichText(
                        pieces: item,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.55,
                          color: OtterColors.sberGray,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    if (block is LegalTableBlock) {
      final table = block as LegalTableBlock;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            border: TableBorder.all(color: OtterColors.grayMid),
            defaultColumnWidth: const IntrinsicColumnWidth(),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: OtterColors.grayLight),
                children: [
                  for (final header in table.headers)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: _LegalRichText(
                        pieces: header,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: OtterColors.sberBlack,
                        ),
                      ),
                    ),
                ],
              ),
              for (final row in table.rows)
                TableRow(
                  children: [
                    for (final cell in row)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: _LegalRichText(
                          pieces: cell,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: OtterColors.sberGray,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _LegalRichText extends StatefulWidget {
  const _LegalRichText({required this.pieces, required this.style});

  final List<LegalInlinePiece> pieces;
  final TextStyle style;

  @override
  State<_LegalRichText> createState() => _LegalRichTextState();
}

class _LegalRichTextState extends State<_LegalRichText> {
  late final List<TapGestureRecognizer?> _recognizers;

  @override
  void initState() {
    super.initState();
    _recognizers = [
      for (final piece in widget.pieces)
        piece.href == null
            ? null
            : (TapGestureRecognizer()..onTap = () => _openLink(piece.href!)),
    ];
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer?.dispose();
    }
    super.dispose();
  }

  Future<void> _openLink(String href) async {
    if (href.startsWith('/legal/')) {
      if (!mounted) return;
      context.push(href);
      return;
    }

    final uri = Uri.tryParse(href);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < widget.pieces.length; i++)
            TextSpan(
              text: widget.pieces[i].text,
              style: widget.style.copyWith(
                fontWeight: widget.pieces[i].bold || widget.pieces[i].href != null
                    ? FontWeight.w600
                    : widget.style.fontWeight,
                color: widget.pieces[i].href != null
                    ? OtterColors.sberGreen
                    : widget.style.color,
                decoration: widget.pieces[i].href != null
                    ? TextDecoration.underline
                    : null,
                decorationColor: widget.pieces[i].href != null
                    ? OtterColors.sberGreen
                    : null,
              ),
              recognizer: _recognizers[i],
            ),
        ],
      ),
    );
  }
}
