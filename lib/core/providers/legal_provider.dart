import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../network/api_exception.dart';
import '../../data/models/api/api_models.dart';
import '../../data/services/settings_service.dart';
import 'providers.dart';

const _docTypeLabels = <String, String>{
  'offer': 'Публичная оферта',
  'privacy': 'Политика конфиденциальности',
  'terms': 'Пользовательское соглашение',
  'license': 'Лицензия',
};

String legalDocTypeLabel(String type) => _docTypeLabels[type] ?? type;

String? formatLegalUpdatedAt(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  return DateFormat('d MMMM yyyy, HH:mm', 'ru').format(parsed.toLocal());
}

class LegalState {
  const LegalState({
    this.documents = const [],
    this.loading = false,
    this.error,
    this.selectedIndex,
  });

  final List<ApiLegalDocument> documents;
  final bool loading;
  final String? error;
  final int? selectedIndex;

  ApiLegalDocument? get selectedDocument {
    final index = selectedIndex;
    if (index == null || index < 0 || index >= documents.length) return null;
    return documents[index];
  }

  LegalState copyWith({
    List<ApiLegalDocument>? documents,
    bool? loading,
    String? error,
    int? selectedIndex,
    bool clearSelected = false,
    bool clearError = false,
  }) => LegalState(
    documents: documents ?? this.documents,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    selectedIndex: clearSelected ? null : (selectedIndex ?? this.selectedIndex),
  );
}

class LegalNotifier extends StateNotifier<LegalState> {
  LegalNotifier(this._service) : super(const LegalState());

  final SettingsService _service;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final documents = await _service.fetchLegalDocuments();
      state = LegalState(documents: documents);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: getApiErrorMessage(e, 'Не удалось загрузить документы'),
      );
    }
  }

  void selectDocument(int index) {
    state = state.copyWith(selectedIndex: index);
  }

  void clearSelection() {
    state = state.copyWith(clearSelected: true);
  }
}

final legalProvider = StateNotifierProvider<LegalNotifier, LegalState>((ref) {
  return LegalNotifier(ref.watch(settingsServiceProvider));
});
