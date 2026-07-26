import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/faq/local_faq.dart';
import '../../data/services/settings_service.dart';
import '../network/api_exception.dart';
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

  List<FaqItem> get filteredItems => items;

  FaqState copyWith({
    List<FaqItem>? items,
    bool? loading,
    String? error,
    String? searchQuery,
    bool clearError = false,
  }) => FaqState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    searchQuery: searchQuery ?? this.searchQuery,
  );
}

List<FaqItem> _localFaqFallback() => localFaqItems
    .map(
      (item) => FaqItem(
        id: item.id,
        question: item.question,
        answer: item.answer,
      ),
    )
    .toList();

class FaqNotifier extends StateNotifier<FaqState> {
  FaqNotifier(this._service) : super(const FaqState());

  final SettingsService _service;
  Timer? _searchDebounce;

  Future<void> load({String? search}) async {
    state = state.copyWith(loading: true, clearError: true);
    final query = search ?? state.searchQuery;
    try {
      final apiItems = await _service.fetchHelp(search: query);
      final items = apiItems.isNotEmpty
          ? apiItems.asMap().entries.map((entry) {
              final item = entry.value;
              return FaqItem(
                id: 'faq-${entry.key}',
                question: item.question,
                answer: item.answer,
              );
            }).toList()
          : (query.trim().isEmpty ? _localFaqFallback() : <FaqItem>[]);
      state = FaqState(
        items: items,
        searchQuery: query,
      );
    } catch (e) {
      final fallback = query.trim().isEmpty ? _localFaqFallback() : <FaqItem>[];
      state = FaqState(
        items: fallback,
        searchQuery: query,
        error: fallback.isEmpty
            ? getApiErrorMessage(e, 'Не удалось загрузить FAQ')
            : null,
      );
    }
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      // ignore: discarded_futures
      load(search: query);
    });
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

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}

final faqProvider = StateNotifierProvider<FaqNotifier, FaqState>((ref) {
  return FaqNotifier(ref.watch(settingsServiceProvider));
});
