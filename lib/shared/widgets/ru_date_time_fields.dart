import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/otter_colors.dart';
import 'keyboard_dismisser.dart';

/// Editable DD.MM.YYYY field with an optional calendar picker (web DateFieldRu).
class RuDateField extends StatefulWidget {
  const RuDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.onSubmitted,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String? label;
  final VoidCallback? onSubmitted;

  @override
  State<RuDateField> createState() => _RuDateFieldState();
}

class _RuDateFieldState extends State<RuDateField> {
  late final TextEditingController _controller;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _commit();
  }

  @override
  void didUpdateWidget(covariant RuDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focus.hasFocus) {
      final next = _format(widget.value);
      if (_controller.text != next) _controller.text = next;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  static String _format(DateTime? d) =>
      d == null ? '' : DateFormat('dd.MM.yyyy').format(d);

  DateTime? _parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    for (final pattern in ['dd.MM.yyyy', 'dd.MM.yy', 'yyyy-MM-dd']) {
      try {
        return DateFormat(pattern).parseStrict(trimmed);
      } catch (_) {}
    }
    return DateTime.tryParse(trimmed);
  }

  void _commit() {
    final raw = _controller.text;
    if (raw.trim().isEmpty) {
      _controller.text = '';
      widget.onChanged(null);
      return;
    }
    final parsed = _parse(raw);
    if (parsed != null) {
      _controller.text = _format(parsed);
      widget.onChanged(parsed);
    } else {
      // Restore last valid value on invalid input.
      _controller.text = _format(widget.value);
    }
  }

  Future<void> _openPicker() async {
    KeyboardDismisser.dismiss();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.value ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    _controller.text = _format(picked);
    widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return _LabeledField(
      label: widget.label,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        keyboardType: TextInputType.datetime,
        textInputAction: TextInputAction.next,
        onTapOutside: dismissKeyboardOnTapOutside,
        onEditingComplete: () {
          _commit();
          widget.onSubmitted?.call();
        },
        onChanged: (value) {
          if (value.trim().isEmpty) {
            widget.onChanged(null);
          }
        },
        decoration: _fieldDecoration(
          context,
          hint: 'ДД.ММ.ГГГГ',
          icon: LucideIcons.calendar,
          onIconTap: _openPicker,
        ),
      ),
    );
  }
}

/// Editable HH:MM field with an optional clock picker (web TimeFieldRu).
class RuTimeField extends StatefulWidget {
  const RuTimeField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.onSubmitted,
  });

  final TimeOfDay? value;
  final ValueChanged<TimeOfDay?> onChanged;
  final String? label;
  final VoidCallback? onSubmitted;

  @override
  State<RuTimeField> createState() => _RuTimeFieldState();
}

class _RuTimeFieldState extends State<RuTimeField> {
  late final TextEditingController _controller;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _commit();
  }

  @override
  void didUpdateWidget(covariant RuTimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focus.hasFocus) {
      final next = _format(widget.value);
      if (_controller.text != next) _controller.text = next;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  static String _format(TimeOfDay? t) => t == null
      ? ''
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Keep digits (max 4) and format as HH:MM — same rules as web TimeFieldRu.
  static String _maskAsHhMm(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits.length > 4) digits = digits.substring(0, 4);

    if (digits.isNotEmpty && digits[0].compareTo('3') >= 0) {
      digits = '0$digits';
      if (digits.length > 4) digits = digits.substring(0, 4);
    }

    var hh = digits.substring(0, digits.length.clamp(0, 2));
    var mm = digits.length > 2 ? digits.substring(2) : '';

    if (hh.length == 2) {
      final n = int.parse(hh).clamp(0, 23);
      hh = n.toString().padLeft(2, '0');
    }
    if (mm.isNotEmpty && mm[0].compareTo('6') >= 0) {
      mm = '5${mm.length > 1 ? mm.substring(1) : ''}';
      if (mm.length > 2) mm = mm.substring(0, 2);
    }
    if (mm.length == 2) {
      final n = int.parse(mm).clamp(0, 59);
      mm = n.toString().padLeft(2, '0');
    }

    return mm.isEmpty ? hh : '$hh:$mm';
  }

  /// Pad incomplete input to HH:MM on blur — same as web `toStrictHHMM`.
  static TimeOfDay? _parseLoose(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    if (digits.length > 4) digits = digits.substring(0, 4);
    if (digits[0].compareTo('3') >= 0) {
      digits = '0$digits';
      if (digits.length > 4) digits = digits.substring(0, 4);
    }
    var h = digits.substring(0, digits.length.clamp(0, 2)).padLeft(2, '0');
    var m = (digits.length > 2 ? digits.substring(2) : '').padRight(2, '0');
    if (m.length > 2) m = m.substring(0, 2);
    final hour = int.parse(h).clamp(0, 23);
    final minute = int.parse(m).clamp(0, 59);
    return TimeOfDay(hour: hour, minute: minute);
  }

  static TimeOfDay? _parseStrict(String raw) {
    final masked = _maskAsHhMm(raw);
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(masked);
    if (match == null) return null;
    final h = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    return TimeOfDay(hour: h, minute: m);
  }

  void _commit() {
    final raw = _controller.text;
    if (raw.trim().isEmpty) {
      _controller.text = '';
      widget.onChanged(null);
      return;
    }
    final parsed = _parseLoose(raw);
    if (parsed != null) {
      _controller.text = _format(parsed);
      widget.onChanged(parsed);
    } else {
      _controller.text = _format(widget.value);
    }
  }

  Future<void> _openPicker() async {
    KeyboardDismisser.dismiss();
    final picked = await showTimePicker(
      context: context,
      initialTime: widget.value ?? TimeOfDay.now(),
    );
    if (picked == null || !mounted) return;
    _controller.text = _format(picked);
    widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return _LabeledField(
      label: widget.label,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[\d:]')),
          LengthLimitingTextInputFormatter(5),
          TextInputFormatter.withFunction((oldValue, newValue) {
            final masked = _maskAsHhMm(newValue.text);
            return TextEditingValue(
              text: masked,
              selection: TextSelection.collapsed(offset: masked.length),
            );
          }),
        ],
        onTapOutside: dismissKeyboardOnTapOutside,
        onEditingComplete: () {
          _commit();
          widget.onSubmitted?.call();
        },
        onChanged: (value) {
          if (value.trim().isEmpty) {
            widget.onChanged(null);
            return;
          }
          final parsed = _parseStrict(value);
          if (parsed != null) widget.onChanged(parsed);
        },
        decoration: _fieldDecoration(
          context,
          hint: 'ЧЧ:ММ',
          icon: LucideIcons.clock,
          onIconTap: _openPicker,
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.child, this.label});

  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (label == null) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label!.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: OtterColors.sberGray,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

InputDecoration _fieldDecoration(
  BuildContext context, {
  required String hint,
  required IconData icon,
  required VoidCallback onIconTap,
}) {
  final isDark = OtterColors.isDarkOf(context);
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: OtterColors.muted(isDark),
    ),
    filled: true,
    fillColor: OtterColors.surfaceAlt(isDark),
    contentPadding: const EdgeInsets.fromLTRB(14, 16, 44, 16),
    suffixIcon: IconButton(
      onPressed: onIconTap,
      icon: Icon(icon, size: 20, color: OtterColors.sberGreen),
      tooltip: 'Выбрать',
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: OtterColors.sberGreen.withValues(alpha: 0.5),
        width: 2,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: OtterColors.sberGreen.withValues(alpha: 0.5),
        width: 2,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: OtterColors.sberGreen, width: 2),
    ),
  );
}
