import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_exception.dart';
import '../../data/services/settings_service.dart';
import 'providers.dart';

class FaqItem {
  FaqItem({
    required this.id,
    required this.question,
    required this.answer,
    this.isOpen = false,
  });

  final String id;
  final String question;
  final String answer;
  bool isOpen;

  FaqItem copyWith({bool? isOpen}) => FaqItem(
        id: id,
        question: question,
        answer: answer,
        isOpen: isOpen ?? this.isOpen,
      );
}

class FaqState {
  const FaqState({
    this.items = const [],
    this.loading = false,
    this.error,
    this.searchQuery = '',
  });

  final List<FaqItem> items;
  final bool loading;
  final String? error;
  final String searchQuery;

  List<FaqItem> get filteredItems {
    if (searchQuery.trim().isEmpty) return items;
    final q = searchQuery.trim().toLowerCase();
    return items
        .where(
          (item) =>
              item.question.toLowerCase().contains(q) ||
              item.answer.toLowerCase().contains(q),
        )
        .toList();
  }

  FaqState copyWith({
    List<FaqItem>? items,
    bool? loading,
    String? error,
    String? searchQuery,
    bool clearError = false,
  }) =>
      FaqState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        searchQuery: searchQuery ?? this.searchQuery,
      );
}

class FaqNotifier extends StateNotifier<FaqState> {
  FaqNotifier(this._service) : super(const FaqState());

  final SettingsService _service;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final apiItems = await _service.fetchHelp();
      state = FaqState(
        items: apiItems.asMap().entries.map((entry) {
          final item = entry.value;
          return FaqItem(
            id: 'faq-${entry.key}',
            question: item.question,
            answer: item.answer,
          );
        }).toList(),
        searchQuery: state.searchQuery,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: getApiErrorMessage(e, 'Не удалось загрузить FAQ'),
      );
    }
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void toggle(String id) {
    state = FaqState(
      items: state.items
          .map((item) => item.id == id ? item.copyWith(isOpen: !item.isOpen) : item)
          .toList(),
      searchQuery: state.searchQuery,
      error: state.error,
    );
  }
}

final faqProvider = StateNotifierProvider<FaqNotifier, FaqState>((ref) {
  return FaqNotifier(ref.watch(settingsServiceProvider));
});
