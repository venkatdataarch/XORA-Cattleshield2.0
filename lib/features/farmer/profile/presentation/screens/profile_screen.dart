import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Not logged in'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      (user.name.isNotEmpty ? user.name[0] : 'F').toUpperCase(),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.name.isNotEmpty ? user.name : 'Farmer',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user.role.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Details card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _DetailRow(Icons.phone, 'Phone', user.phone),
                          if (user.email != null && user.email!.isNotEmpty)
                            _DetailRow(Icons.email, 'Email', user.email!),
                          if (user.village != null && user.village!.isNotEmpty)
                            _DetailRow(Icons.location_city, 'Village', user.village!),
                          if (user.district != null && user.district!.isNotEmpty)
                            _DetailRow(Icons.map, 'District', user.district!),
                          if (user.state != null && user.state!.isNotEmpty)
                            _DetailRow(Icons.flag, 'State', user.state!),
                          if (user.aadhaarNumber != null && user.aadhaarNumber!.isNotEmpty)
                            _DetailRow(Icons.credit_card, 'Aadhaar', _maskAadhaar(user.aadhaarNumber!)),
                          if (user.fatherOrHusbandName != null && user.fatherOrHusbandName!.isNotEmpty)
                            _DetailRow(Icons.person_outline, 'Father/Husband', user.fatherOrHusbandName!),
                          if (user.occupation != null && user.occupation!.isNotEmpty)
                            _DetailRow(Icons.work, 'Occupation', user.occupation!),
                          if (user.qualification != null && user.qualification!.isNotEmpty)
                            _DetailRow(Icons.school, 'Qualification', user.qualification!),
                          if (user.regNumber != null && user.regNumber!.isNotEmpty)
                            _DetailRow(Icons.badge, 'Reg Number', user.regNumber!),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Logout button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('Logout', style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _maskAadhaar(String aadhaar) {
    if (aadhaar.length >= 8) {
      return 'XXXX XXXX ${aadhaar.substring(aadhaar.length - 4)}';
    }
    return aadhaar;
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
