import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/layout/responsive.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../core/theme/otter_theme.dart';
import '../../data/legal/static_legal_documents.dart';

class StaticLegalScreen extends ConsumerStatefulWidget {
  const StaticLegalScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<StaticLegalScreen> createState() => _StaticLegalScreenState();
}

class _StaticLegalScreenState extends ConsumerState<StaticLegalScreen> {
  String? _content;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StaticLegalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug) {
      _content = null;
      _error = null;
      _load();
    }
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
    final wide = Responsive.isWide(context);
    final isDark = ref.watch(appSettingsProvider).theme == 'dark';
    final bg = OtterColors.pageBg(isDark);
    final surface = OtterColors.surface(isDark);
    final titleColor = OtterColors.text(isDark);
    final muted = OtterColors.muted(isDark);

    return Theme(
      data: isDark ? OtterTheme.dark() : OtterTheme.light(),
      child: Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(8, 8, wide ? 24 : 16, 8),
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
                    icon: Icon(
                      LucideIcons.chevronLeft,
                      color: titleColor,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? OtterColors.darkElevated
                          : OtterColors.grayLight,
                      foregroundColor: titleColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      doc?.title ?? 'Документ',
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
            Expanded(
              child: ResponsiveContent(
                // Web-like wide reading column so privacy tables fit on Windows.
                maxWidth: wide ? 1400 : Responsive.pageMaxWidth(context),
                padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 16),
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
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          if (updated != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Обновлено: $updated',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: muted,
                                ),
                              ),
                            ),
                          Card(
                            color: surface,
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: EdgeInsets.all(wide ? 24 : 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final block in blocks)
                                    _LegalBlockView(
                                      block: block,
                                      isDark: isDark,
                                    ),
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
    ),
    );
  }
}

class _LegalBlockView extends StatelessWidget {
  const _LegalBlockView({required this.block, required this.isDark});

  final LegalContentBlock block;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final headingColor = OtterColors.text(isDark);
    final bodyColor = OtterColors.muted(isDark);
    final tableHeaderBg =
        isDark ? OtterColors.darkElevated : OtterColors.grayLight;
    final tableBorder =
        isDark ? OtterColors.darkBorder : OtterColors.grayMid;

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
            color: headingColor,
          ),
        ),
      );
    }

    if (block is LegalParagraphBlock) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _LegalRichText(
          pieces: (block as LegalParagraphBlock).pieces,
          style: TextStyle(
            fontSize: 14,
            height: 1.55,
            color: bodyColor,
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
                    Text(
                      '•  ',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.55,
                        color: bodyColor,
                      ),
                    ),
                    Expanded(
                      child: _LegalRichText(
                        pieces: item,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.55,
                          color: bodyColor,
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
      final columnCount = table.headers.length;
      final columnWidths = <int, TableColumnWidth>{
        for (var i = 0; i < columnCount; i++)
          i: i == 0 && columnCount >= 3
              ? const FlexColumnWidth(0.55)
              : const FlexColumnWidth(1.6),
      };

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tableWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Table(
                  border: TableBorder.all(color: tableBorder),
                  columnWidths: columnWidths,
                  defaultVerticalAlignment: TableCellVerticalAlignment.top,
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: tableHeaderBg),
                      children: [
                        for (final header in table.headers)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: _LegalRichText(
                              pieces: header,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                color: headingColor,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              child: _LegalRichText(
                                pieces: cell,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: bodyColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
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
  late List<TapGestureRecognizer?> _recognizers;

  @override
  void initState() {
    super.initState();
    _rebuildRecognizers();
  }

  @override
  void didUpdateWidget(covariant _LegalRichText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pieces != widget.pieces) {
      for (final recognizer in _recognizers) {
        recognizer?.dispose();
      }
      _rebuildRecognizers();
    }
  }

  void _rebuildRecognizers() {
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
                fontWeight:
                    widget.pieces[i].bold || widget.pieces[i].href != null
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
