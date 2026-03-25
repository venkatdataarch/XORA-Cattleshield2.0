import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../features/auth/domain/user_model.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import 'primary_button.dart';

/// Profile screen shared between farmer and vet roles.
///
/// Displays user information (avatar, name, phone, role, address) and
/// role-specific fields (qualification and reg number for vets).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Header with avatar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            title: const Text('Profile'),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary,
                      AppColors.primaryDark,
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      _AvatarCircle(name: user?.name ?? 'U'),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        user?.name ?? 'User',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              AppColors.textOnPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _roleLabel(user?.role),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.textOnPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.lg),

                  // Personal info section
                  _SectionCard(
                    title: 'Personal Information',
                    children: [
                      _InfoRow(
                        icon: Icons.person_outline,
                        label: 'Name',
                        value: user?.name ?? '-',
                      ),
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: user?.phone ?? '-',
                      ),
                      if (user?.email != null)
                        _InfoRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: user!.email!,
                        ),
                      if (user?.fatherOrHusbandName != null)
                        _InfoRow(
                          icon: Icons.family_restroom,
                          label: 'Father/Husband',
                          value: user!.fatherOrHusbandName!,
                        ),
                      if (user?.occupation != null)
                        _InfoRow(
                          icon: Icons.work_outline,
                          label: 'Occupation',
                          value: user!.occupation!,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Address section
                  _SectionCard(
                    title: 'Address',
                    children: [
                      if (user?.address != null)
                        _InfoRow(
                          icon: Icons.home_outlined,
                          label: 'Address',
                          value: user!.address!,
                        ),
                      if (user?.village != null)
                        _InfoRow(
                          icon: Icons.location_on_outlined,
                          label: 'Village',
                          value: user!.village!,
                        ),
                      if (user?.district != null)
                        _InfoRow(
                          icon: Icons.map_outlined,
                          label: 'District',
                          value: user!.district!,
                        ),
                      if (user?.state != null)
                        _InfoRow(
                          icon: Icons.flag_outlined,
                          label: 'State',
                          value: user!.state!,
                        ),
                      if (_hasNoAddress(user))
                        _InfoRow(
                          icon: Icons.home_outlined,
                          label: 'Address',
                          value: 'Not provided',
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Vet-specific section
                  if (user?.role == UserRole.vet) ...[
                    _SectionCard(
                      title: 'Professional Details',
                      children: [
                        _InfoRow(
                          icon: Icons.school_outlined,
                          label: 'Qualification',
                          value: user?.qualification ?? '-',
                        ),
                        _InfoRow(
                          icon: Icons.badge_outlined,
                          label: 'Reg. Number',
                          value: user?.regNumber ?? '-',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Edit profile button (disabled)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit Profile (Coming Soon)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textTertiary,
                        side: const BorderSide(color: AppColors.cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.buttonRadius),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Logout button
                  PrimaryButton(
                    label: 'Logout',
                    icon: Icons.logout,
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Logout'),
                          content: const Text(
                            'Are you sure you want to logout?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.error,
                              ),
                              child: const Text('Logout'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true && context.mounted) {
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasNoAddress(AppUser? user) {
    return user?.address == null &&
        user?.village == null &&
        user?.district == null &&
        user?.state == null;
  }

  String _roleLabel(UserRole? role) {
    switch (role) {
      case UserRole.farmer:
        return 'Farmer';
      case UserRole.vet:
        return 'Veterinarian';
      case UserRole.agent:
        return 'Agent';
      case UserRole.admin:
        return 'Administrator';
      case null:
        return 'User';
    }
  }
}

/// Circular avatar showing the user's initial.
class _AvatarCircle extends StatelessWidget {
  final String name;

  const _AvatarCircle({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.textOnPrimary.withValues(alpha: 0.2),
        border: Border.all(
          color: AppColors.textOnPrimary.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.textOnPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

/// Section card with a title and list of info rows.
class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

/// Single info row with icon, label, and value.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
