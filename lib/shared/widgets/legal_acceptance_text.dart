import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/otter_colors.dart';

class LegalAcceptanceText extends StatefulWidget {
  const LegalAcceptanceText({super.key, this.textAlign = TextAlign.center});

  final TextAlign textAlign;

  @override
  State<LegalAcceptanceText> createState() => _LegalAcceptanceTextState();
}

class _LegalAcceptanceTextState extends State<LegalAcceptanceText> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => context.push('/legal/terms-of-use');
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => context.push('/legal/privacy-policy');
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      fontSize: 12,
      height: 1.5,
      color: OtterColors.sberGray,
    );
    const linkStyle = TextStyle(
      fontSize: 12,
      height: 1.5,
      color: OtterColors.sberGreen,
      fontWeight: FontWeight.w500,
      decoration: TextDecoration.underline,
      decorationColor: OtterColors.sberGreen,
    );

    return RichText(
      textAlign: widget.textAlign,
      text: TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: 'Продолжая, вы принимаете '),
          TextSpan(
            text: 'условия использования',
            style: linkStyle,
            recognizer: _termsRecognizer,
          ),
          const TextSpan(text: ' и '),
          TextSpan(
            text: 'политику конфиденциальности',
            style: linkStyle,
            recognizer: _privacyRecognizer,
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}
