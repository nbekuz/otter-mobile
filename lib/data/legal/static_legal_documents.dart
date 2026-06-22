import 'package:flutter/services.dart';

enum StaticLegalSlug {
  termsOfUse('terms-of-use'),
  privacyPolicy('privacy-policy');

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
    required this.docxAssetPath,
  });

  final StaticLegalSlug slug;
  final String title;
  final String updatedAt;
  final String assetPath;
  final String docxAssetPath;
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
    updatedAt: '2026-06-17',
    assetPath: 'assets/legal/privacy-policy.md',
    docxAssetPath: 'assets/legal/Политика_конфиденциальности_17_06_26.docx',
  ),
];

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

List<LegalContentBlock> parseLegalMarkdown(String content) {
  final blocks = <LegalContentBlock>[];
  for (final rawLine in content.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('_')) continue;
    if (line.startsWith('# ')) {
      blocks.add(LegalContentBlock.heading(line.substring(2).trim()));
      continue;
    }
    if (line.startsWith('## ')) {
      blocks.add(LegalContentBlock.subheading(line.substring(3).trim()));
      continue;
    }
    blocks.add(LegalContentBlock.paragraph(line.replaceAll('**', '')));
  }
  return blocks;
}

class LegalContentBlock {
  const LegalContentBlock._(this.kind, this.text);

  const LegalContentBlock.heading(String text)
      : this._(LegalBlockKind.heading, text);

  const LegalContentBlock.subheading(String text)
      : this._(LegalBlockKind.subheading, text);

  const LegalContentBlock.paragraph(String text)
      : this._(LegalBlockKind.paragraph, text);

  final LegalBlockKind kind;
  final String text;
}

enum LegalBlockKind { heading, subheading, paragraph }
