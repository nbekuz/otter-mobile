import 'package:flutter/material.dart';

import '../../data/models/ui/ui_models.dart';

const priorityColorMap = <Priority, Color>{
  Priority.high: Color(0xFFFF3B30),
  Priority.medium: Color(0xFFFF9500),
  Priority.low: Color(0xFF34C759),
  Priority.none: Color(0xFF8E8E93),
};

Color priorityColor(Priority priority) =>
    priorityColorMap[priority] ?? priorityColorMap[Priority.none]!;
