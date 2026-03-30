import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/auth_state.dart';
import '../providers/auth_provider.dart';

enum _SelectedRole { farmer, vet, agent, admin }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  _SelectedRole _selectedRole = _SelectedRole.farmer;

  final _farmerFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _vetFormKey = GlobalKey<FormState>();
  final _agentIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSendingOtp = false;

  late final AnimationController _headerController;
  late final AnimationController _formController;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _formFade;
  late final Animation<Offset> _formSlide;

  @override
  void initState() {
    super.initState();

    _headerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _headerFade = CurvedAnimation(parent: _headerController, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic));

    _formController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _formFade = CurvedAnimation(parent: _formController, curve: Curves.easeOut);
    _formSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _formController, curve: Curves.easeOutCubic));

    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _formController.forward();
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _formController.dispose();
    _phoneController.dispose();
    _agentIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleFarmerLogin() async {
    if (!_farmerFormKey.currentState!.validate()) return;
    setState(() => _isSendingOtp = true);
    final phone = _phoneController.text.trim();
    final success = await ref.read(authProvider.notifier).loginWithOtp(phone);
    if (mounted) setState(() => _isSendingOtp = false);
    if (success && mounted) {
      context.goNamed('otp-verification', queryParameters: {'phone': phone});
    }
  }

  Future<void> _handleVetLogin() async {
    if (!_vetFormKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).login(
      _agentIdController.text.trim(),
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!), backgroundColor: AppColors.error),
        );
        ref.read(authProvider.notifier).clearError();
      }
    });

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
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Premium header with gradient
                SlideTransition(
                  position: _headerSlide,
                  child: FadeTransition(
                    opacity: _headerFade,
                    child: _buildHeader(),
                  ),
                ),

                // Form section
                SlideTransition(
                  position: _formSlide,
                  child: FadeTransition(
                    opacity: _formFade,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Role selector
                          Text(
                            'I am a',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildRoleSelector(),
                          const SizedBox(height: 28),

                          // Form card
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.05, 0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: _selectedRole == _SelectedRole.farmer
                                ? _buildFarmerForm(authState)
                                : _buildCredentialForm(authState),
                          ),

                          const SizedBox(height: 30),

                          // Bottom branding
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_user, size: 14, color: Colors.grey.shade400),
                                const SizedBox(width: 6),
                                Text(
                                  'Secured by UIIC',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    color: Colors.grey.shade400,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            left: -15,
            bottom: -15,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.03),
              ),
            ),
          ),
          Column(
            children: [
              // Logo
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/xora_logo.jpeg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.white.withValues(alpha: 0.15),
                    child: const Icon(Icons.shield, size: 36, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'CattleShield',
                style: GoogleFonts.manrope(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Digital Livestock Insurance',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    final roles = [
      (_SelectedRole.farmer, Icons.agriculture, 'Farmer'),
      (_SelectedRole.vet, Icons.medical_services, 'Vet Doctor'),
      (_SelectedRole.agent, Icons.assignment_ind, 'Agent'),
      (_SelectedRole.admin, Icons.admin_panel_settings, 'UIIC Admin'),
    ];

    return Row(
      children: roles.map((role) {
        final isSelected = _selectedRole == role.$1;
        final isLast = role == roles.last;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 10),
            child: GestureDetector(
              onTap: () {
                if (_selectedRole != role.$1) {
                  setState(() => _selectedRole = role.$1);
                  // Trigger form re-entrance animation
                  _formController.reset();
                  _formController.forward();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                padding: const EdgeInsets.symmetric(vertical: 14),
                transform: Matrix4.identity()..scale(isSelected ? 1.0 : 0.95),
                transformAlignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.shade200,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedScale(
                      scale: isSelected ? 1.2 : 0.9,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          role.$2,
                          size: 22,
                          color: isSelected ? AppColors.primary : Colors.grey.shade400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: GoogleFonts.manrope(
                        fontSize: isSelected ? 11.5 : 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppColors.primary : Colors.grey.shade500,
                      ),
                      child: Text(
                        role.$3,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Selection indicator dot
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      width: isSelected ? 20 : 0,
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFarmerForm(AuthState authState) {
    return Container(
      key: const ValueKey('farmer_form'),
      padding: const EdgeInsets.all(24),
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
      child: Form(
        key: _farmerFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.phone_android, color: AppColors.secondary, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Login with Mobile',
                      style: GoogleFonts.manrope(
                        fontSize: 17, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'We\'ll send you a verification code',
                      style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w600),
              decoration: _premiumInput(
                label: 'Mobile Number',
                hint: 'Enter 10-digit number',
                icon: Icons.phone_outlined,
                prefix: '+91 ',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter your mobile number';
                if (v.trim().length != 10) return 'Must be 10 digits';
                return null;
              },
            ),
            const SizedBox(height: 20),

            _PremiumButton(
              label: 'Send OTP',
              icon: Icons.arrow_forward,
              isLoading: _isSendingOtp,
              onPressed: _handleFarmerLogin,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialForm(AuthState authState) {
    final roleTitle = {
      _SelectedRole.vet: 'Vet Doctor Login',
      _SelectedRole.agent: 'Field Agent Login',
      _SelectedRole.admin: 'UIIC Admin Login',
    }[_selectedRole] ?? 'Login';

    final roleIdLabel = {
      _SelectedRole.vet: 'Doctor ID',
      _SelectedRole.agent: 'Agent ID',
      _SelectedRole.admin: 'Admin ID',
    }[_selectedRole] ?? 'User ID';

    final roleHint = {
      _SelectedRole.vet: 'e.g. VET001',
      _SelectedRole.agent: 'e.g. AGENT001',
      _SelectedRole.admin: 'e.g. ADMIN001',
    }[_selectedRole] ?? '';

    final roleIcon = {
      _SelectedRole.vet: Icons.medical_services,
      _SelectedRole.agent: Icons.assignment_ind,
      _SelectedRole.admin: Icons.admin_panel_settings,
    }[_selectedRole] ?? Icons.person;

    return Container(
      key: ValueKey('credential_form_${_selectedRole.name}'),
      padding: const EdgeInsets.all(24),
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
      child: Form(
        key: _vetFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3498DB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(roleIcon, color: const Color(0xFF3498DB), size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roleTitle,
                      style: GoogleFonts.manrope(
                        fontSize: 17, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Enter your credentials',
                      style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: _agentIdController,
              textCapitalization: TextCapitalization.characters,
              style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w600),
              decoration: _premiumInput(label: roleIdLabel, hint: roleHint, icon: Icons.badge_outlined),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w600),
              decoration: _premiumInput(
                label: 'Password',
                hint: 'Enter your password',
                icon: Icons.lock_outline,
              ).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.grey.shade400,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 4) return 'Min 4 characters';
                return null;
              },
            ),
            const SizedBox(height: 20),

            _PremiumButton(
              label: 'Login',
              icon: Icons.login,
              isLoading: authState.isLoading,
              onPressed: _handleVetLogin,
            ),

            if (_selectedRole == _SelectedRole.agent) ...[
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => context.push('/register/agent'),
                  child: RichText(
                    text: TextSpan(
                      text: "New here? ",
                      style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey.shade500),
                      children: [
                        TextSpan(
                          text: 'Register as Agent',
                          style: GoogleFonts.manrope(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _premiumInput({
    required String label,
    String? hint,
    required IconData icon,
    String? prefix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      counterText: '',
      prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
      prefixText: prefix,
      prefixStyle: GoogleFonts.manrope(
        fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
      ),
      labelStyle: GoogleFonts.manrope(fontSize: 14, color: Colors.grey.shade500),
      hintStyle: GoogleFonts.manrope(fontSize: 14, color: Colors.grey.shade300),
      filled: true,
      fillColor: AppColors.surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

class _PremiumButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onPressed;

  const _PremiumButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.manrope(
                      fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, color: Colors.white, size: 20),
                ],
              ),
      ),
    );
  }
}
