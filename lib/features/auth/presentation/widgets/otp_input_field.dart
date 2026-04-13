import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';

/// A row of 6 individual digit input boxes for OTP entry.
///
/// Features:
/// - Auto-focus advances to the next box on input
/// - Backspace retreats to the previous box
/// - Full 6-digit paste support (clipboard)
/// - Calls [onCompleted] with the full OTP when all 6 digits are entered
class OtpInputField extends StatefulWidget {
  /// Called when all 6 digits have been entered.
  final ValueChanged<String> onCompleted;

  /// Called whenever the OTP value changes (partial or complete).
  final ValueChanged<String>? onChanged;

  const OtpInputField({
    super.key,
    required this.onCompleted,
    this.onChanged,
  });

  @override
  State<OtpInputField> createState() => _OtpInputFieldState();
}

class _OtpInputFieldState extends State<OtpInputField> {
  static const _length = 6;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_length, (_) => TextEditingController());
    _focusNodes = List.generate(_length, (_) => FocusNode());

    // Auto-focus the first field.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _currentOtp =>
      _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) {
    // Handle paste of full OTP.
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length >= _length) {
        _fillAll(digits.substring(0, _length));
        return;
      }
    }

    if (value.isNotEmpty) {
      // Take only the last character (handles paste of 2 chars into a field).
      final digit = value[value.length - 1];
      _controllers[index].text = digit;
      _controllers[index].selection =
          TextSelection.collapsed(offset: 1);

      widget.onChanged?.call(_currentOtp);

      if (index < _length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _submit();
      }
    }
  }

  void _fillAll(String otp) {
    for (int i = 0; i < _length && i < otp.length; i++) {
      _controllers[i].text = otp[i];
    }
    setState(() {});
    widget.onChanged?.call(_currentOtp);
    _focusNodes[_length - 1].unfocus();
    _submit();
  }

  void _submit() {
    final otp = _currentOtp;
    if (otp.length == _length) {
      widget.onCompleted(otp);
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _controllers[index - 1].clear();
        _focusNodes[index - 1].requestFocus();
        widget.onChanged?.call(_currentOtp);
      }
    }
  }

  /// Clears all fields and focuses the first one.
  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_length, (index) {
        return Container(
          width: 48,
          height: 56,
          margin: EdgeInsets.only(
            left: index == 0 ? 0 : 8,
          ),
          child: KeyboardListener(
            focusNode: FocusNode(),
            onKeyEvent: (event) => _onKeyEvent(index, event),
            child: TextFormField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 2, // allow 2 so paste detection works
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                counterText: '',
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: _controllers[index].text.isNotEmpty
                    ? AppColors.primary.withValues(alpha: 0.05)
                    : AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _controllers[index].text.isNotEmpty
                        ? AppColors.primary
                        : AppColors.cardBorder,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
              ),
              onChanged: (value) => _onChanged(index, value),
            ),
          ),
        );
      }),
    );
  }
}
