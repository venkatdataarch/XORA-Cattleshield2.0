import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/auth_state.dart';
import '../providers/auth_provider.dart';
import '../widgets/otp_input_field.dart';

/// OTP verification screen.
///
/// Displays 6 individual digit input boxes and a countdown timer for
/// resending the OTP. Auto-submits when all 6 digits are entered.
class OtpVerificationScreen extends ConsumerStatefulWidget {
  /// The phone number the OTP was sent to.
  final String phone;

  const OtpVerificationScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState
    extends ConsumerState<OtpVerificationScreen> {
  static const _resendDuration = 60;

  int _secondsRemaining = _resendDuration;
  Timer? _timer;
  bool _isVerifying = false;
  String _currentOtp = '';

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _secondsRemaining = _resendDuration;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 0) {
        timer.cancel();
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _verifyOtp(String otp) async {
    if (_isVerifying) return;

    setState(() => _isVerifying = true);

    final success =
        await ref.read(authProvider.notifier).verifyOtp(widget.phone, otp);

    if (!mounted) return;

    setState(() => _isVerifying = false);

    if (success) {
      final authState = ref.read(authProvider);
      if (authState.user != null && authState.user!.name.isEmpty) {
        // User needs to complete registration.
        context.goNamed(
          'farmer-registration',
          queryParameters: {'phone': widget.phone},
        );
      } else {
        context.go('/farmer');
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_secondsRemaining > 0) return;

    await ref.read(authProvider.notifier).loginWithOtp(widget.phone);
    _startCountdown();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP resent successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for auth errors.
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(authProvider.notifier).clearError();
      }
    });

    final maskedPhone = widget.phone.length >= 10
        ? '${widget.phone.substring(0, 2)}****${widget.phone.substring(widget.phone.length - 4)}'
        : widget.phone;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // Title
              const Text(
                'Verify OTP',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle with phone and edit button
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Enter the 6-digit code sent to +91 $maskedPhone',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // OTP input
              OtpInputField(
                onCompleted: _verifyOtp,
                onChanged: (value) {
                  _currentOtp = value;
                },
              ),

              const SizedBox(height: 32),

              // Verifying indicator
              if (_isVerifying)
                const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              // Resend timer / button
              Center(
                child: _secondsRemaining > 0
                    ? Text.rich(
                        TextSpan(
                          text: 'Resend OTP in ',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  '00:${_secondsRemaining.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : TextButton(
                        onPressed: _resendOtp,
                        child: const Text(
                          'Resend OTP',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
              ),

              const Spacer(),

              // Verify button (manual fallback)
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isVerifying
                      ? null
                      : () {
                          if (_currentOtp.length == 6) {
                            _verifyOtp(_currentOtp);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Please enter the complete 6-digit OTP'),
                                backgroundColor: AppColors.warning,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Verify & Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
