import 'package:flutter/material.dart';

/// Supported app languages — keep in sync with otter-app Settings → Язык.
const kSupportedAppLanguages = <({String id, String label})>[
  (id: 'ru', label: 'Русский'),
];

const kDefaultAppLanguage = 'ru';

String appLanguageLabel(String code) {
  for (final lang in kSupportedAppLanguages) {
    if (lang.id == code) return lang.label;
  }
  return kSupportedAppLanguages.first.label;
}

String normalizeAppLanguage(String? code) {
  final value = (code ?? '').trim().toLowerCase();
  for (final lang in kSupportedAppLanguages) {
    if (lang.id == value) return lang.id;
  }
  return kDefaultAppLanguage;
}

Locale localeFromAppLanguage(String? code) {
  final normalized = normalizeAppLanguage(code);
  return Locale(normalized);
}

List<Locale> get kSupportedAppLocales => [
      for (final lang in kSupportedAppLanguages) Locale(lang.id),
    ];
