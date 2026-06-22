import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/otter_colors.dart';

class OtpCodeInput extends StatefulWidget {
  const OtpCodeInput({
    super.key,
    required this.onChanged,
    this.onCompleted,
    this.errorText,
    this.length = 6,
    this.autofocus = false,
    this.enabled = true,
  });

  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final String? errorText;
  final int length;
  final bool autofocus;
  final bool enabled;

  @override
  State<OtpCodeInput> createState() => OtpCodeInputState();
}

class OtpCodeInputState extends State<OtpCodeInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get value => _controller.text;

  void clear() {
    _controller.clear();
    widget.onChanged('');
    _focusNode.requestFocus();
    setState(() {});
  }

  void _onChanged(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final trimmed = digits.length > widget.length
        ? digits.substring(0, widget.length)
        : digits;

    if (trimmed != _controller.text) {
      _controller.value = TextEditingValue(
        text: trimmed,
        selection: TextSelection.collapsed(offset: trimmed.length),
      );
    }

    widget.onChanged(trimmed);
    if (trimmed.length == widget.length) {
      _focusNode.unfocus();
      widget.onCompleted?.call(trimmed);
    }
    setState(() {});
  }

  int get _activeIndex {
    final len = _controller.text.length;
    if (!_focusNode.hasFocus) {
      return len == 0 ? 0 : len.clamp(0, widget.length - 1);
    }
    return len.clamp(0, widget.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final code = _controller.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: widget.enabled ? () => _focusNode.requestFocus() : null,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: List.generate(widget.length, (index) {
              final filled = index < code.length;
              final active = _focusNode.hasFocus && index == _activeIndex;
              final char = filled ? code[index] : '';

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 0 : 4,
                    right: index == widget.length - 1 ? 0 : 4,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: OtterColors.grayLight,
                      borderRadius:
                          BorderRadius.circular(OtterColors.radiusMd),
                      border: Border.all(
                        color: hasError
                            ? Colors.red.shade300
                            : active
                                ? OtterColors.sberGreen
                                : OtterColors.grayMid,
                        width: active ? 2 : 1,
                      ),
                    ),
                    child: active && !filled
                        ? _BlinkingCursor(color: OtterColors.sberGreen)
                        : Text(
                            char,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              );
            }),
          ),
        ),
        SizedBox(
          height: 0,
          child: Opacity(
            opacity: 0,
            child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            enableSuggestions: false,
            autocorrect: false,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(widget.length),
            ],
            onChanged: _onChanged,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 8),
          Text(
            widget.errorText!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor({required this.color});

  final Color color;

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2,
        height: 24,
        color: widget.color,
      ),
    );
  }
}
