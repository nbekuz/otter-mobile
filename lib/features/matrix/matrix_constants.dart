import 'package:flutter/material.dart';

import '../../core/theme/otter_colors.dart';
import '../../data/models/ui/ui_models.dart';

typedef MatrixBlockTheme = ({
  MatrixBlock block,
  String defaultTitle,
  Color bgColor,
  Color accent,
});

const kMatrixBlockThemes = <MatrixBlockTheme>[
  (
    block: MatrixBlock.urgentImportant,
    defaultTitle: 'Срочно и важно',
    bgColor: Color(0xFFFFF0EF),
    accent: OtterColors.priorityHigh,
  ),
  (
    block: MatrixBlock.notUrgentImportant,
    defaultTitle: 'Не срочно, но важно',
    bgColor: Color(0xFFEFF5FF),
    accent: OtterColors.sberBlue,
  ),
  (
    block: MatrixBlock.urgentNotImportant,
    defaultTitle: 'Срочно, не важно',
    bgColor: Color(0xFFFFF8EF),
    accent: OtterColors.priorityMedium,
  ),
  (
    block: MatrixBlock.notUrgentNotImportant,
    defaultTitle: 'Не срочно, не важно',
    bgColor: Color(0xFFF5F5F5),
    accent: OtterColors.sberGray,
  ),
];

MatrixBlockTheme themeForBlock(MatrixBlock block) =>
    kMatrixBlockThemes.firstWhere((t) => t.block == block);

const kMatrixDateFilters = [
  (id: 'overdue', label: 'Просроч.'),
  (id: 'today', label: 'Сегодня'),
  (id: 'tomorrow', label: 'Завтра'),
  (id: 'later', label: 'Позже'),
  (id: 'nodate', label: 'Без даты'),
];

const kMatrixPriorityFilters = [
  (id: 'high', label: 'Высок.', color: OtterColors.priorityHigh),
  (id: 'medium', label: 'Средн.', color: OtterColors.priorityMedium),
  (id: 'low', label: 'Низкий', color: OtterColors.priorityLow),
  (id: 'none', label: 'Без', color: OtterColors.sberGray),
];
