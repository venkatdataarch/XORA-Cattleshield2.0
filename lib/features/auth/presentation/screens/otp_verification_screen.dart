import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/auth_state.dart';
import '../providers/auth_provider.dart';
import '../widgets/otp_input_field.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpVerificationScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen>
    with TickerProviderStateMixin {
  static const _resendDuration = 60;

  int _secondsRemaining = _resendDuration;
  Timer? _timer;
  bool _isVerifying = false;
  String _currentOtp = '';

  late final AnimationController _headerController;
  late final AnimationController _contentController;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;
  late final AnimationController _shieldPulse;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _startCountdown();

    _headerController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _headerFade = CurvedAnimation(parent: _headerController, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic));

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _contentFade = CurvedAnimation(parent: _contentController, curve: Curves.easeOut);
    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _contentController, curve: Curves.easeOutCubic));

    _shieldPulse = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _shieldPulse, curve: Curves.easeInOut),
    );

    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _contentController.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _headerController.dispose();
    _contentController.dispose();
    _shieldPulse.dispose();
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
    final success = await ref.read(authProvider.notifier).verifyOtp(widget.phone, otp);
    if (!mounted) return;
    setState(() => _isVerifying = false);
    if (success) {
      final authState = ref.read(authProvider);
      if (authState.user != null && authState.user!.name.isEmpty) {
        context.goNamed('farmer-registration', queryParameters: {'phone': widget.phone});
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
        const SnackBar(content: Text('OTP resent successfully'), backgroundColor: AppColors.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!), backgroundColor: AppColors.error),
        );
        ref.read(authProvider.notifier).clearError();
      }
    });

    final maskedPhone = widget.phone.length >= 10
        ? '${widget.phone.substring(0, 2)}****${widget.phone.substring(widget.phone.length - 4)}'
        : widget.phone;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.background, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.arrow_back, size: 20, color: AppColors.textPrimary),
                      ),
                      onPressed: () => context.go('/login'),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),

                      // Shield animation
                      SlideTransition(
                        position: _headerSlide,
                        child: FadeTransition(
                          opacity: _headerFade,
                          child: Column(
                            children: [
                              ScaleTransition(
                                scale: _pulseAnim,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [AppColors.primary, AppColors.primaryLight],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.sms_outlined, color: Colors.white, size: 36),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Verify OTP',
                                style: GoogleFonts.manrope(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Code sent to +91 $maskedPhone',
                                    style: GoogleFonts.manrope(
                                      fontSize: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => context.go('/login'),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Edit',
                                      style: GoogleFonts.manrope(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 36),

                      // OTP card
                      SlideTransition(
                        position: _contentSlide,
                        child: FadeTransition(
                          opacity: _contentFade,
                          child: Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Enter 6-digit code',
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 24),

                                OtpInputField(
                                  onCompleted: _verifyOtp,
                                  onChanged: (value) => _currentOtp = value,
                                ),

                                const SizedBox(height: 24),

                                // Verifying state
                                if (_isVerifying)
                                  Column(
                                    children: [
                                      const SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Verifying...',
                                        style: GoogleFonts.manrope(
                                          fontSize: 13,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),

                                if (!_isVerifying) ...[
                                  const SizedBox(height: 8),

                                  // Timer / resend
                                  _secondsRemaining > 0
                                      ? Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.timer_outlined,
                                                size: 16, color: Colors.grey.shade400),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Resend in ',
                                              style: GoogleFonts.manrope(
                                                fontSize: 13,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '00:${_secondsRemaining.toString().padLeft(2, '0')}',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : TextButton.icon(
                                          onPressed: _resendOtp,
                                          icon: const Icon(Icons.refresh,
                                              size: 18, color: AppColors.primary),
                                          label: Text(
                                            'Resend OTP',
                                            style: GoogleFonts.manrope(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Verify button
                      SlideTransition(
                        position: _contentSlide,
                        child: FadeTransition(
                          opacity: _contentFade,
                          child: Container(
                            width: double.infinity,
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryLight],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isVerifying
                                  ? null
                                  : () {
                                      if (_currentOtp.length == 6) {
                                        _verifyOtp(_currentOtp);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Enter the complete 6-digit OTP'),
                                            backgroundColor: AppColors.warning,
                                          ),
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Verify & Continue',
                                    style: GoogleFonts.manrope(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.verified_user, color: Colors.white, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Security badge
                      FadeTransition(
                        opacity: _contentFade,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock, size: 14, color: AppColors.secondary),
                              const SizedBox(width: 8),
                              Text(
                                'End-to-end encrypted verification',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
