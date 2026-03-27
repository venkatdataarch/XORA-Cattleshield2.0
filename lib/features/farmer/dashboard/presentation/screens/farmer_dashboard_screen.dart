import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../data/farmer_dashboard_repository.dart';

class FarmerDashboardScreen extends ConsumerStatefulWidget {
  const FarmerDashboardScreen({super.key});

  @override
  ConsumerState<FarmerDashboardScreen> createState() =>
      _FarmerDashboardScreenState();
}

class _FarmerDashboardScreenState extends ConsumerState<FarmerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(authProvider.notifier).refreshUser();
    });
  }

  Future<void> _onRefresh() async {
    ref.invalidate(farmerDashboardStatsProvider);
    await ref
        .read(farmerDashboardStatsProvider.future)
        .catchError((_) => DashboardStats());
    ref.read(authProvider.notifier).refreshUser();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final statsAsync = ref.watch(farmerDashboardStatsProvider);
    final userName = authState.user?.name ?? 'Farmer';
    final firstName = userName.split(' ').first;

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ─── Dark Green Header Bar ────────────────
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top bar — logo + icons
                    Row(
                      children: [
                        // Logo
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            'assets/images/xora_logo.jpeg',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.white.withValues(alpha: 0.15),
                              child: const Icon(Icons.shield, size: 20, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'CattleShield',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        // Location icon
                        Icon(
                          Icons.location_on_outlined,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        // Notification bell with badge
                        Stack(
                          children: [
                            Icon(
                              Icons.notifications_none_rounded,
                              color: Colors.white.withValues(alpha: 0.7),
                              size: 24,
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '2',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        // Avatar
                        GestureDetector(
                          onTap: () => context.go('/farmer/profile'),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                            child: Center(
                              child: Text(
                                firstName.isNotEmpty ? firstName[0].toUpperCase() : 'F',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Greeting
                    Text(
                      '$greeting, $firstName',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Protecting Your Herd, Every Day',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Insure Your Livestock Banner
                    GestureDetector(
                      onTap: () => context.push('/farmer/animals'),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.white.withValues(alpha: 0.12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.security_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Insure Your Livestock',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'AI-powered muzzle ID & health assessment',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Start Now',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Content ────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Stats ──────────────────────────
                      statsAsync.when(
                        data: (stats) => _StatsSection(stats: stats),
                        loading: () => const _StatsShimmer(),
                        error: (_, __) => _StatsSection(stats: const DashboardStats()),
                      ),

                      const SizedBox(height: 32),

                      // ─── Quick Actions ──────────────────
                      Text(
                        'Quick Actions',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _QuickAction(
                            icon: Icons.pets_rounded,
                            label: 'Register\nAnimal',
                            color: Colors.white,
                            bgColor: AppColors.primary,
                            onTap: () async {
                              await context.push('/farmer/animals/new');
                              // Refresh stats when returning
                              ref.invalidate(farmerDashboardStatsProvider);
                            },
                          ),
                          const SizedBox(width: 12),
                          _QuickAction(
                            icon: Icons.description_outlined,
                            label: 'File\nClaim',
                            color: Colors.white,
                            bgColor: const Color(0xFFE65100),
                            onTap: () async {
                              await context.push('/farmer/claims/new');
                              ref.invalidate(farmerDashboardStatsProvider);
                            },
                          ),
                          const SizedBox(width: 12),
                          _QuickAction(
                            icon: Icons.qr_code_scanner_rounded,
                            label: 'Identify\nAnimal',
                            color: Colors.white,
                            bgColor: const Color(0xFF1565C0),
                            onTap: () => context.push('/scan/muzzle-identify'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // ─── Protection Banner ──────────────
                      _ProtectionBanner(),

                      const SizedBox(height: 32),

                      // ─── Recent Activity ────────────────
                      Text(
                        'Recent Activity',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _RecentActivity(),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stats Section ──────────────────────────────────────

class _StatsSection extends StatelessWidget {
  final DashboardStats stats;
  const _StatsSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatPill(
          value: stats.activePolicies.toString(),
          label: 'Active',
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        _StatPill(
          value: stats.pendingProposals.toString(),
          label: 'Pending',
          color: AppColors.warning,
        ),
        const SizedBox(width: 8),
        _StatPill(
          value: stats.pendingClaims.toString(),
          label: 'Claims',
          color: AppColors.error,
        ),
        const SizedBox(width: 8),
        _StatPill(
          value: stats.totalAnimals.toString(),
          label: 'Animals',
          color: AppColors.info,
        ),
      ],
    );
  }
}

class _StatPill extends StatefulWidget {
  final String value;
  final String label;
  final Color color;

  const _StatPill({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  State<_StatPill> createState() => _StatPillState();
}

class _StatPillState extends State<_StatPill> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.color.withValues(alpha: 0.12)
                : widget.color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? widget.color.withValues(alpha: 0.3)
                  : widget.color.withValues(alpha: 0.1),
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: GoogleFonts.poppins(
                  fontSize: _isHovered ? 26 : 24,
                  fontWeight: FontWeight.w700,
                  color: widget.color,
                  height: 1,
                ),
                child: Text(widget.value),
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsShimmer extends StatelessWidget {
  const _StatsShimmer();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (i) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Quick Action Button ────────────────────────────────

class _QuickAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (_) {
            setState(() => _isPressed = true);
            _controller.forward();
          },
          onTapUp: (_) {
            setState(() => _isPressed = false);
            _controller.reverse();
            widget.onTap();
          },
          onTapCancel: () {
            setState(() => _isPressed = false);
            _controller.reverse();
          },
          child: AnimatedBuilder(
            animation: _scaleAnim,
            builder: (context, child) => Transform.scale(
              scale: _scaleAnim.value,
              child: child,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: _isHovered
                    ? Color.lerp(widget.bgColor, Colors.white, 0.15)
                    : widget.bgColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: widget.bgColor.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: widget.bgColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: _isHovered ? 0.3 : 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 22),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.color,
                      height: 1.3,
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

// ─── Protection Banner ──────────────────────────────────

class _ProtectionBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Livestock Protection',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'AI-powered health assessment & muzzle biometric ID',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Learn More',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shield_rounded,
              size: 30,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recent Activity ────────────────────────────────────

class _RecentActivity extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      _ActivityData(
        icon: Icons.add_circle_outline,
        title: 'Animal Registered',
        subtitle: 'Gir Cow - HF-0042',
        time: '2h ago',
      ),
      _ActivityData(
        icon: Icons.description_outlined,
        title: 'Proposal Submitted',
        subtitle: 'Buffalo - BF-0015',
        time: '1d ago',
      ),
      _ActivityData(
        icon: Icons.verified_outlined,
        title: 'Policy Issued',
        subtitle: 'POL-2024-0089',
        time: '3d ago',
      ),
    ];

    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cream.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.icon,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        item.subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  item.time,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ActivityData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;

  const _ActivityData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
  });
}
