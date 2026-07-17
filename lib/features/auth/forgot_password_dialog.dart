import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../core/utils/password_policy.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/keyboard_dismisser.dart';
import '../../shared/widgets/otp_code_input.dart';
import '../../shared/widgets/primary_button.dart';

enum _ForgotStep { email, code, newPassword }

const _resendCooldownSeconds = 120;

Future<String?> showForgotPasswordDialog(
  BuildContext context,
  WidgetRef ref, {
  String initialEmail = '',
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (_) => _ForgotPasswordDialog(initialEmail: initialEmail),
  );
}

class _ForgotPasswordDialog extends ConsumerStatefulWidget {
  const _ForgotPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  ConsumerState<_ForgotPasswordDialog> createState() =>
      _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends ConsumerState<_ForgotPasswordDialog> {
  _ForgotStep _step = _ForgotStep.email;
  final _email = TextEditingController();
  final _otpKey = GlobalKey<OtpCodeInputState>();
  String _code = '';
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  String? _resetToken;
  String? _error;
  String? _passwordError;
  bool _loading = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  Timer? _resendTimer;
  int _resendSecondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _email.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _email.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String get _submitLabel {
    if (_loading) return 'Подождите...';
    return switch (_step) {
      _ForgotStep.email => 'Отправить код',
      _ForgotStep.code => 'Подтвердить код',
      _ForgotStep.newPassword => 'Сохранить пароль',
    };
  }

  bool get _showSubmitButton => _step != _ForgotStep.code;

  String get _resendTimerLabel {
    final minutes = (_resendSecondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_resendSecondsLeft % 60).toString().padLeft(2, '0');
    return 'Отправить повторно через $minutes:$seconds';
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = _resendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _resendSecondsLeft = 0);
      } else {
        setState(() => _resendSecondsLeft--);
      }
    });
  }

  void _stopResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = null;
    _resendSecondsLeft = 0;
  }

  void _goBackToEmail() {
    _stopResendTimer();
    setState(() {
      _step = _ForgotStep.email;
      _code = '';
      _resetToken = null;
      _error = null;
    });
    _otpKey.currentState?.clear();
  }

  Future<void> _sendCode({bool isResend = false}) async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Введите корректный email');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authServiceProvider).forgotPassword(email);
      if (!mounted) return;
      setState(() {
        if (!isResend) _step = _ForgotStep.code;
        _code = '';
        _error = null;
      });
      _otpKey.currentState?.clear();
      _startResendTimer();
      if (isResend) {
        showAppToast(
          context,
          'Код отправлен повторно',
          type: AppToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = getApiErrorMessage(e, 'Не удалось отправить код'),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode([String? codeOverride]) async {
    final code = (codeOverride ?? _code).trim();
    if (code.length != 6 || _loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await ref
          .read(authServiceProvider)
          .forgotPasswordVerify(_email.text.trim(), code);
      if (mounted) {
        _stopResendTimer();
        setState(() {
          _resetToken = token;
          _step = _ForgotStep.newPassword;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = getApiErrorMessage(e, 'Неверный код или срок истёк'),
        );
        _otpKey.currentState?.clear();
        setState(() => _code = '');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveNewPassword() async {
    final passwordError = validateNewPassword(_newPassword.text);
    if (passwordError != null) {
      setState(() => _passwordError = passwordError);
      return;
    }
    if (_newPassword.text != _confirmPassword.text) {
      setState(() => _passwordError = 'Пароли не совпадают');
      return;
    }
    if (_resetToken == null || _resetToken!.isEmpty) {
      setState(() => _error = 'Сессия сброса устарела. Начните заново.');
      return;
    }

    setState(() {
      _loading = true;
      _passwordError = null;
      _error = null;
    });

    try {
      final message = await ref
          .read(authServiceProvider)
          .forgotPasswordConfirm(_resetToken!, _newPassword.text);
      if (mounted) Navigator.of(context).pop(message);
    } catch (e) {
      if (mounted) {
        setState(
          () => _passwordError =
              getApiFieldError(e, 'new_password') ??
              getApiErrorMessage(e, 'Не удалось сохранить пароль'),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    switch (_step) {
      case _ForgotStep.email:
        await _sendCode();
      case _ForgotStep.code:
        await _verifyCode();
      case _ForgotStep.newPassword:
        await _saveNewPassword();
    }
  }

  void _close() {
    KeyboardDismisser.dismiss();
    Navigator.of(context).pop();
  }

  Widget _buildContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: Text(
                'Восстановление пароля',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Material(
              color: OtterColors.grayLight,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: _close,
                borderRadius: BorderRadius.circular(20),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    LucideIcons.x,
                    size: 18,
                    color: OtterColors.sberGray,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_step == _ForgotStep.email) ...[
          const Text(
            'Введите email — мы отправим письмо с кодом '
            '(например: «ВАШ КОД 310696»).',
            style: TextStyle(color: OtterColors.sberGray, height: 1.4),
          ),
          const SizedBox(height: 16),
          InputField(
            controller: _email,
            label: 'Email',
            hint: 'example@mail.ru',
            icon: LucideIcons.mail,
            keyboardType: TextInputType.emailAddress,
            error: _error,
          ),
        ] else if (_step == _ForgotStep.code) ...[
          Text.rich(
            TextSpan(
              style: const TextStyle(color: OtterColors.sberGray, height: 1.4),
              children: [
                const TextSpan(text: 'Код отправлен на '),
                TextSpan(
                  text: _email.text.trim(),
                  style: const TextStyle(
                    color: OtterColors.sberBlack,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Введите 6 цифр из письма (только код).',
            style: TextStyle(color: OtterColors.sberGray, fontSize: 12),
          ),
          const SizedBox(height: 20),
          OtpCodeInput(
            key: _otpKey,
            autofocus: true,
            enabled: !_loading,
            errorText: _error,
            onChanged: (code) {
              setState(() {
                _code = code;
                if (_error != null) _error = null;
              });
            },
            onCompleted: _verifyCode,
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          const SizedBox(height: 20),
          _CodeStepActions(
            loading: _loading,
            resendSecondsLeft: _resendSecondsLeft,
            resendTimerLabel: _resendTimerLabel,
            onChangeEmail: _goBackToEmail,
            onResend: () => _sendCode(isResend: true),
          ),
        ] else ...[
          Text.rich(
            TextSpan(
              style: const TextStyle(color: OtterColors.sberGray, height: 1.4),
              children: [
                const TextSpan(text: 'Новый пароль для '),
                TextSpan(
                  text: _email.text.trim(),
                  style: const TextStyle(
                    color: OtterColors.sberBlack,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '8–20 символов: заглавная и строчная латинские буквы, '
            'цифра и один специальный символ.',
            style: TextStyle(color: OtterColors.sberGray, fontSize: 12),
          ),
          const SizedBox(height: 16),
          InputField(
            controller: _newPassword,
            label: 'Новый пароль',
            icon: LucideIcons.lock,
            obscure: true,
            obscureVisible: _showNewPassword,
            onToggleObscure: () =>
                setState(() => _showNewPassword = !_showNewPassword),
            error: _passwordError,
          ),
          const SizedBox(height: 12),
          InputField(
            controller: _confirmPassword,
            label: 'Повторите пароль',
            icon: LucideIcons.lock,
            obscure: true,
            obscureVisible: _showConfirmPassword,
            onToggleObscure: () =>
                setState(() => _showConfirmPassword = !_showConfirmPassword),
          ),
        ],
        if (_step == _ForgotStep.newPassword && _error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
        if (_showSubmitButton) ...[
          const SizedBox(height: 24),
          PrimaryButton(
            label: _submitLabel,
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final maxHeight =
        mq.size.height - mq.viewInsets.bottom - mq.padding.vertical - 32;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, mq.viewInsets.bottom),
      child: Center(
        child: Material(
          color: Colors.white,
          elevation: 16,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(OtterColors.radiusLg),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: maxHeight.clamp(200, mq.size.height),
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(24),
              child: _buildContent(),
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeStepActions extends StatelessWidget {
  const _CodeStepActions({
    required this.loading,
    required this.resendSecondsLeft,
    required this.resendTimerLabel,
    required this.onChangeEmail,
    required this.onResend,
  });

  final bool loading;
  final int resendSecondsLeft;
  final String resendTimerLabel;
  final VoidCallback onChangeEmail;
  final VoidCallback onResend;

  static ButtonStyle get _linkStyle => TextButton.styleFrom(
    foregroundColor: OtterColors.sberGreen,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: TextButton(
            onPressed: loading ? null : onChangeEmail,
            style: _linkStyle,
            child: const Text('Изменить email'),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: resendSecondsLeft > 0
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    resendTimerLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: OtterColors.sberGray,
                      fontSize: 14,
                    ),
                  ),
                )
              : TextButton(
                  onPressed: loading ? null : onResend,
                  style: _linkStyle,
                  child: const Text('Отправить код повторно'),
                ),
        ),
      ],
    );
  }
}
