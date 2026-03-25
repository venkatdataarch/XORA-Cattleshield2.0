import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/auth_state.dart';
import '../../domain/user_model.dart';
import '../providers/auth_provider.dart';

/// Branded splash screen shown on app launch.
///
/// Checks persistent auth state and redirects to the appropriate
/// dashboard or the login screen after a brief branded delay.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();

    // Kick off auth check.
    Future.microtask(() {
      ref.read(authProvider.notifier).checkAuth();
    });

    // Navigate after a minimum splash duration of 2 seconds.
    Future.delayed(const Duration(seconds: 2), _navigate);
  }

  void _navigate() {
    if (!mounted) return;

    final state = ref.read(authProvider);

    switch (state.status) {
      case AuthStatus.authenticated:
        final role = state.user?.role;
        if (role == UserRole.vet) {
          context.go('/vet');
        } else {
          context.go('/farmer');
        }
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        context.go('/login');
      case AuthStatus.initial:
      case AuthStatus.loading:
        // Auth check hasn't completed yet; fallback to login after 3 more seconds.
        Future.delayed(const Duration(seconds: 3), () {
          if (!mounted) return;
          context.go('/login');
        });
        break;
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for auth state changes so we can navigate once check completes.
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status != AuthStatus.initial &&
          next.status != AuthStatus.loading) {
        _navigate();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.shield,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // App name
                  Text(
                    'XORA',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 6,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'CattleShield',
                    style: GoogleFonts.manrope(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Digital Livestock Insurance',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.75),
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Loading indicator
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
