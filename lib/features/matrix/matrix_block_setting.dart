import '../../data/models/api/api_models.dart';
import '../../data/models/ui/ui_models.dart';
import 'matrix_constants.dart';

class MatrixBlockUiSetting {
  const MatrixBlockUiSetting({
    required this.id,
    required this.block,
    required this.title,
    required this.dateFilters,
    required this.priorityFilters,
  });

  final int id;
  final MatrixBlock block;
  final String title;
  final List<String> dateFilters;
  final List<String> priorityFilters;

  MatrixBlockUiSetting copyWith({
    int? id,
    MatrixBlock? block,
    String? title,
    List<String>? dateFilters,
    List<String>? priorityFilters,
  }) => MatrixBlockUiSetting(
    id: id ?? this.id,
    block: block ?? this.block,
    title: title ?? this.title,
    dateFilters: dateFilters ?? this.dateFilters,
    priorityFilters: priorityFilters ?? this.priorityFilters,
  );

  static Map<MatrixBlock, MatrixBlockUiSetting> defaults() => {
    MatrixBlock.urgentImportant: MatrixBlockUiSetting(
      id: 0,
      block: MatrixBlock.urgentImportant,
      title: themeForBlock(MatrixBlock.urgentImportant).defaultTitle,
      dateFilters: const ['overdue', 'today'],
      priorityFilters: const ['high'],
    ),
    MatrixBlock.notUrgentImportant: MatrixBlockUiSetting(
      id: 0,
      block: MatrixBlock.notUrgentImportant,
      title: themeForBlock(MatrixBlock.notUrgentImportant).defaultTitle,
      dateFilters: const ['tomorrow', 'later'],
      priorityFilters: const ['high', 'medium'],
    ),
    MatrixBlock.urgentNotImportant: MatrixBlockUiSetting(
      id: 0,
      block: MatrixBlock.urgentNotImportant,
      title: themeForBlock(MatrixBlock.urgentNotImportant).defaultTitle,
      dateFilters: const ['overdue', 'today', 'tomorrow'],
      priorityFilters: const ['medium', 'low'],
    ),
    MatrixBlock.notUrgentNotImportant: MatrixBlockUiSetting(
      id: 0,
      block: MatrixBlock.notUrgentNotImportant,
      title: themeForBlock(MatrixBlock.notUrgentNotImportant).defaultTitle,
      dateFilters: const ['later', 'nodate'],
      priorityFilters: const ['low', 'none'],
    ),
  };

  factory MatrixBlockUiSetting.fromApi(ApiMatrixSetting api) {
    final block = MatrixBlockX.fromApi(api.block);
    final fallback = defaults()[block]!;
    final dateFilters = api.dateFilter.isEmpty || api.dateFilter == 'all'
        ? fallback.dateFilters
        : api.dateFilter.split(',').where((s) => s.trim().isNotEmpty).toList();
    final priorityFilters = api.allowedPriorities.isEmpty
        ? fallback.priorityFilters
        : api.allowedPriorities
              .map((p) => p == 'critical' ? 'high' : p)
              .toList();

    return MatrixBlockUiSetting(
      id: api.id,
      block: block,
      title: api.title.isNotEmpty ? api.title : fallback.title,
      dateFilters: dateFilters,
      priorityFilters: priorityFilters,
    );
  }

  List<String> toApiPriorities() => priorityFilters;

  String toApiDateFilter() => dateFilters.join(',');

  static Priority defaultPriorityFor(
    MatrixBlock block, [
    MatrixBlockUiSetting? setting,
  ]) {
    final filters =
        setting?.priorityFilters ?? defaults()[block]!.priorityFilters;
    if (filters.isEmpty) return Priority.medium;
    return priorityFromFilter(filters.first);
  }

  static Priority priorityFromFilter(String filter) => switch (filter) {
    'high' => Priority.high,
    'medium' => Priority.medium,
    'low' => Priority.low,
    'none' => Priority.none,
    _ => Priority.medium,
  };
}
