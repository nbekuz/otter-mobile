import 'package:flutter/services.dart';

enum StaticLegalSlug {
  termsOfUse('terms-of-use'),
  privacyPolicy('privacy-policy'),
  publicOffer('public-offer');

  const StaticLegalSlug(this.id);
  final String id;

  static StaticLegalSlug? fromId(String id) {
    for (final slug in StaticLegalSlug.values) {
      if (slug.id == id) return slug;
    }
    return null;
  }
}

class StaticLegalDocument {
  const StaticLegalDocument({
    required this.slug,
    required this.title,
    required this.updatedAt,
    required this.assetPath,
    this.docxAssetPath,
    this.listedInHub = true,
  });

  final StaticLegalSlug slug;
  final String title;
  final String updatedAt;
  final String assetPath;
  final String? docxAssetPath;
  final bool listedInHub;
}

const staticLegalDocuments = <StaticLegalDocument>[
  StaticLegalDocument(
    slug: StaticLegalSlug.termsOfUse,
    title: 'Условия использования',
    updatedAt: '2026-06-17',
    assetPath: 'assets/legal/terms-of-use.md',
    docxAssetPath: 'assets/legal/Условия использования 17.06.26 .docx',
  ),
  StaticLegalDocument(
    slug: StaticLegalSlug.privacyPolicy,
    title: 'Политика конфиденциальности',
    updatedAt: '2026-07-08',
    assetPath: 'assets/legal/privacy-policy.md',
    docxAssetPath: 'assets/legal/Политика_конфиденциальности_17_06_26.docx',
  ),
  StaticLegalDocument(
    slug: StaticLegalSlug.publicOffer,
    title: 'Публичная оферта',
    updatedAt: '2026-07-08',
    assetPath: 'assets/legal/public-offer.md',
    listedInHub: false,
  ),
];

List<StaticLegalDocument> get hubStaticLegalDocuments =>
    staticLegalDocuments.where((doc) => doc.listedInHub).toList();

StaticLegalDocument? staticLegalDocumentById(String id) {
  for (final doc in staticLegalDocuments) {
    if (doc.slug.id == id) return doc;
  }
  return null;
}

Future<String> loadStaticLegalMarkdown(StaticLegalDocument doc) async {
  return rootBundle.loadString(doc.assetPath);
}

String? formatStaticLegalUpdatedAt(String value) {
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  const months = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];
  if (month < 1 || month > 12) return null;
  return '$day ${months[month - 1]} $year';
}

class LegalInlinePiece {
  const LegalInlinePiece({
    required this.text,
    this.bold = false,
    this.href,
  });

  final String text;
  final bool bold;
  final String? href;
}

sealed class LegalContentBlock {
  const LegalContentBlock();
}

class LegalHeadingBlock extends LegalContentBlock {
  const LegalHeadingBlock({required this.level, required this.pieces});

  final int level;
  final List<LegalInlinePiece> pieces;
}

class LegalParagraphBlock extends LegalContentBlock {
  const LegalParagraphBlock(this.pieces);

  final List<LegalInlinePiece> pieces;
}

class LegalListBlock extends LegalContentBlock {
  const LegalListBlock(this.items);

  final List<List<LegalInlinePiece>> items;
}

class LegalTableBlock extends LegalContentBlock {
  const LegalTableBlock({required this.headers, required this.rows});

  final List<List<LegalInlinePiece>> headers;
  final List<List<List<LegalInlinePiece>>> rows;
}

/// Parses legal markdown the same way as the web `LegalDocumentBody`.
List<LegalContentBlock> parseLegalMarkdown(String content) {
  final result = <LegalContentBlock>[];
  final lines = content.split('\n');
  var index = 0;

  while (index < lines.length) {
    final line = lines[index].trim();

    if (line.isEmpty || line.startsWith('_')) {
      index += 1;
      continue;
    }

    if (line.startsWith('|')) {
      final tableLines = <String>[];
      while (index < lines.length && lines[index].trim().startsWith('|')) {
        tableLines.add(lines[index].trim());
        index += 1;
      }
      final table = _parseTable(tableLines);
      if (table != null) result.add(table);
      continue;
    }

    if (line.startsWith('- ')) {
      final items = <List<LegalInlinePiece>>[];
      while (index < lines.length) {
        final listLine = lines[index].trim();
        if (!listLine.startsWith('- ')) break;
        items.add(parseInlineMarkdown(listLine.substring(2).trim()));
        index += 1;
      }
      result.add(LegalListBlock(items));
      continue;
    }

    if (line.startsWith('### ')) {
      result.add(
        LegalHeadingBlock(
          level: 3,
          pieces: parseInlineMarkdown(line.substring(4).trim()),
        ),
      );
      index += 1;
      continue;
    }

    if (line.startsWith('## ')) {
      result.add(
        LegalHeadingBlock(
          level: 2,
          pieces: parseInlineMarkdown(line.substring(3).trim()),
        ),
      );
      index += 1;
      continue;
    }

    if (line.startsWith('# ')) {
      result.add(
        LegalHeadingBlock(
          level: 1,
          pieces: parseInlineMarkdown(line.substring(2).trim()),
        ),
      );
      index += 1;
      continue;
    }

    result.add(LegalParagraphBlock(parseInlineMarkdown(line)));
    index += 1;
  }

  // Title is already shown in the screen header (same as web).
  if (result.isNotEmpty &&
      result.first is LegalHeadingBlock &&
      (result.first as LegalHeadingBlock).level == 1) {
    result.removeAt(0);
  }

  return result;
}

LegalTableBlock? _parseTable(List<String> lines) {
  if (lines.length < 2) return null;

  final rows = lines.map(_parseTableRow).toList();
  final headers = rows.first;
  final separator = rows[1];
  final body = rows.skip(2);

  final isSeparator = separator.every((cell) {
    final normalized = cell.replaceAll(RegExp(r'\s+'), '');
    return RegExp(r'^:?-{3,}:?$').hasMatch(normalized);
  });
  if (!isSeparator) return null;

  return LegalTableBlock(
    headers: headers.map(parseInlineMarkdown).toList(),
    rows: body
        .map((row) => row.map(parseInlineMarkdown).toList())
        .toList(),
  );
}

List<String> _parseTableRow(String line) {
  final parts = line.split('|');
  if (parts.length < 3) return const [];
  return parts
      .sublist(1, parts.length - 1)
      .map((cell) => cell.trim())
      .toList();
}

List<LegalInlinePiece> parseInlineMarkdown(String value) {
  final pieces = <LegalInlinePiece>[];
  final pattern = RegExp(
    r'\*\*(.+?)\*\*|\[(.+?)\]\((.+?)\)',
    dotAll: true,
  );
  var cursor = 0;

  for (final match in pattern.allMatches(value)) {
    if (match.start > cursor) {
      pieces.add(LegalInlinePiece(text: value.substring(cursor, match.start)));
    }

    if (match.group(1) != null) {
      pieces.add(LegalInlinePiece(text: match.group(1)!, bold: true));
    } else {
      pieces.add(
        LegalInlinePiece(text: match.group(2)!, href: match.group(3)),
      );
    }
    cursor = match.end;
  }

  if (cursor < value.length) {
    pieces.add(LegalInlinePiece(text: value.substring(cursor)));
  }

  if (pieces.isEmpty) {
    pieces.add(LegalInlinePiece(text: value));
  }

  return pieces;
}
