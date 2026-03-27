import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/auth_state.dart';
import '../../domain/user_model.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  bool _hasNavigated = false;

  // Animation controllers
  late final AnimationController _logoController;
  late final AnimationController _textController;
  late final AnimationController _shimmerController;
  late final AnimationController _pulseController;
  late final AnimationController _particleController;

  // Animations
  late final Animation<double> _logoScale;
  late final Animation<double> _logoRotate;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _xoraSlide;
  late final Animation<double> _xoraFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<double> _taglineFade;
  late final Animation<double> _loaderFade;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Logo animation — scale + rotate entrance
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );
    _logoRotate = Tween<double>(begin: -0.15, end: 0.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // Text animations — staggered slide-up entrance
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _xoraSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
    ));
    _xoraFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.15, 0.55, curve: Curves.easeOutCubic),
    ));
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.15, 0.45, curve: Curves.easeIn),
      ),
    );
    _subtitleSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic),
    ));
    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.3, 0.6, curve: Curves.easeIn),
      ),
    );
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.5, 0.8, curve: Curves.easeIn),
      ),
    );
    _loaderFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );

    // Shimmer effect for the logo glow
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    // Pulse animation for logo
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Particle animation
    _particleController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    // Start animation sequence
    _startAnimations();
  }

  Future<void> _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    _textController.forward();

    // Auth check + navigate
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    await ref.read(authProvider.notifier).checkAuth();
    if (!mounted) return;

    _navigate();
  }

  void _navigate() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    final state = ref.read(authProvider);

    if (state.isAuthenticated) {
      final role = state.user?.role;
      if (role == UserRole.vet) {
        context.go('/vet');
      } else if (role == UserRole.admin) {
        context.go('/admin');
      } else {
        context.go('/farmer');
      }
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary, // Deep forest green
              AppColors.primaryLight, // Rich green
              Color(0xFF0F4434), // Dark emerald
              Color(0xFF0A2E22), // Near-black green
            ],
            stops: [0.0, 0.35, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Animated background particles
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _particleController,
                builder: (context, _) => CustomPaint(
                  painter: _ParticlePainter(
                    progress: _particleController.value,
                  ),
                ),
              ),
            ),

            // Radial glow behind logo
            AnimatedBuilder(
              animation: _shimmerController,
              builder: (context, _) {
                return Center(
                  child: Transform.translate(
                    offset: const Offset(0, -60),
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(
                              alpha: 0.06 +
                                  0.03 *
                                      math.sin(
                                          _shimmerController.value * 2 * math.pi),
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Main content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),

                        // Logo with scale + rotate + pulse
                        AnimatedBuilder(
                          animation: Listenable.merge([
                            _logoController,
                            _pulseAnimation,
                          ]),
                          builder: (context, child) {
                            return FadeTransition(
                              opacity: _logoFade,
                              child: Transform.scale(
                                scale: _logoScale.value * _pulseAnimation.value,
                                child: Transform.rotate(
                                  angle: _logoRotate.value,
                                  child: child,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 30,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: AppColors.secondary
                                      .withValues(alpha: 0.15),
                                  blurRadius: 40,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              'assets/images/xora_logo.jpeg',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withValues(alpha: 0.2),
                                      Colors.white.withValues(alpha: 0.08),
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.shield,
                                  size: 64,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 36),

                        // "XORA" brand name
                        SlideTransition(
                          position: _xoraSlide,
                          child: FadeTransition(
                            opacity: _xoraFade,
                            child: Text(
                              'X O R A',
                              style: GoogleFonts.manrope(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 12,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // "CattleShield" main title
                        SlideTransition(
                          position: _titleSlide,
                          child: FadeTransition(
                            opacity: _titleFade,
                            child: ShaderMask(
                              shaderCallback: (bounds) {
                                return const LinearGradient(
                                  colors: [
                                    Colors.white,
                                    Color(0xFFE0E0E0),
                                    Colors.white,
                                  ],
                                ).createShader(bounds);
                              },
                              child: Text(
                                'CattleShield',
                                style: GoogleFonts.manrope(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Subtitle
                        SlideTransition(
                          position: _subtitleSlide,
                          child: FadeTransition(
                            opacity: _subtitleFade,
                            child: Text(
                              'Digital Livestock Insurance',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.7),
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Tagline with divider lines
                        FadeTransition(
                          opacity: _taglineFade,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildDividerLine(),
                              const SizedBox(width: 12),
                              Text(
                                'POWERED BY AI',
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 3,
                                  color: AppColors.secondary
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(width: 12),
                              _buildDividerLine(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 60),

                        // Loading indicator
                        FadeTransition(
                          opacity: _loaderFade,
                          child: Column(
                            children: [
                              SizedBox(
                                width: 180,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.1),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.secondary
                                          .withValues(alpha: 0.7),
                                    ),
                                    minHeight: 3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Securing your livestock...',
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 60),

                        // Bottom branding
                        FadeTransition(
                          opacity: _loaderFade,
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.verified_user,
                                    size: 14,
                                    color:
                                        Colors.white.withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'UIIC Certified Platform',
                                    style: GoogleFonts.manrope(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white
                                          .withValues(alpha: 0.3),
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'v2.0',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color:
                                      Colors.white.withValues(alpha: 0.2),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDividerLine() {
    return Container(
      width: 30,
      height: 1,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }
}

/// Paints floating particles in the background for a premium feel.
class _ParticlePainter extends CustomPainter {
  final double progress;

  _ParticlePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Generate 20 particles with deterministic positions
    final random = math.Random(42);
    for (int i = 0; i < 20; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final speed = 0.3 + random.nextDouble() * 0.7;
      final radius = 1.0 + random.nextDouble() * 2.5;

      // Animate vertical drift
      final y = (baseY - progress * size.height * speed * 0.3) %
          size.height;
      final x = baseX +
          math.sin(progress * 2 * math.pi + i) * 15;

      // Fade based on position
      final alpha = (0.05 + 0.1 * math.sin(progress * 2 * math.pi + i * 0.5))
          .clamp(0.0, 0.15);

      paint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
