import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../features/auth/domain/user_model.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import 'primary_button.dart';

/// Profile screen shared between farmer and vet roles.
///
/// Displays user information (avatar, name, phone, role, address) and
/// role-specific fields (qualification and reg number for vets).
/// Includes an edit mode that allows updating name, address, village,
/// district, and state via PUT /api/auth/me.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _villageController;
  late TextEditingController _districtController;
  late TextEditingController _stateController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _villageController = TextEditingController();
    _districtController = TextEditingController();
    _stateController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _villageController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  void _enterEditMode(AppUser user) {
    _nameController.text = user.name;
    _addressController.text = user.address ?? '';
    _villageController.text = user.village ?? '';
    _districtController.text = user.district ?? '';
    _stateController.text = user.state ?? '';
    setState(() => _isEditing = true);
  }

  void _cancelEdit() {
    setState(() => _isEditing = false);
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    final dio = ref.read(dioClientProvider);
    final data = <String, dynamic>{};

    if (_nameController.text.trim().isNotEmpty) {
      data['name'] = _nameController.text.trim();
    }
    data['address'] = _addressController.text.trim();
    data['village'] = _villageController.text.trim();
    data['district'] = _districtController.text.trim();
    data['state'] = _stateController.text.trim();

    final result = await dio.put(ApiEndpoints.currentUser, data: data);

    result.when(
      success: (_) {
        // Refresh user data
        ref.read(authProvider.notifier).refreshUser();
        if (mounted) {
          setState(() {
            _isEditing = false;
            _isSaving = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Profile updated successfully',
                style: GoogleFonts.inter(),
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      },
      failure: (error) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to update profile: ${error.message}',
                style: GoogleFonts.inter(),
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary,
                      Color(0xFF1A5C45),
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
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
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
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
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

                  if (_isEditing) ...[
                    // Edit form
                    _EditFormCard(
                      title: 'Edit Profile',
                      children: [
                        _EditField(
                          controller: _nameController,
                          label: 'Name',
                          icon: Icons.person_outline,
                        ),
                        _EditField(
                          controller: _addressController,
                          label: 'Address',
                          icon: Icons.home_outlined,
                        ),
                        _EditField(
                          controller: _villageController,
                          label: 'Village',
                          icon: Icons.location_on_outlined,
                        ),
                        _EditField(
                          controller: _districtController,
                          label: 'District',
                          icon: Icons.map_outlined,
                        ),
                        _EditField(
                          controller: _stateController,
                          label: 'State',
                          icon: Icons.flag_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Save / Cancel buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving ? null : _cancelEdit,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(color: AppColors.cardBorder),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // View mode
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

                    // Edit profile button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: user != null ? () => _enterEditMode(user) : null,
                        icon: const Icon(Icons.edit, size: 18),
                        label: Text(
                          'Edit Profile',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),

                  // Logout button
                  PrimaryButton(
                    label: 'Logout',
                    icon: Icons.logout,
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Text('Logout', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                          content: Text(
                            'Are you sure you want to logout?',
                            style: GoogleFonts.inter(),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text('Cancel', style: GoogleFonts.inter()),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.error,
                              ),
                              child: Text('Logout', style: GoogleFonts.inter()),
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
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textOnPrimary,
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
    return Container(
      width: double.infinity,
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

/// Edit form card.
class _EditFormCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _EditFormCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

/// Editable text field for edit mode.
class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;

  const _EditField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
          prefixIcon: Icon(icon, size: 20, color: AppColors.textTertiary),
          filled: true,
          fillColor: AppColors.background,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
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
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
