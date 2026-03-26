import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UIIC Admin Dashboard'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats cards row
            Row(
              children: [
                _StatCard(
                  title: 'Total Animals',
                  value: '1,247',
                  icon: Icons.pets,
                  color: Colors.blue,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  title: 'Active Policies',
                  value: '892',
                  icon: Icons.policy,
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatCard(
                  title: 'Pending Claims',
                  value: '34',
                  icon: Icons.assignment,
                  color: Colors.orange,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  title: 'Fraud Alerts',
                  value: '7',
                  icon: Icons.warning_amber,
                  color: Colors.red,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Quick actions
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            _ActionTile(
              icon: Icons.history,
              title: 'Audit Trail',
              subtitle: 'View immutable audit log of all system actions',
              onTap: () => context.go('/admin/audit-logs'),
            ),
            _ActionTile(
              icon: Icons.warning,
              title: 'Fraud Alerts',
              subtitle: 'Review and resolve fraud detection alerts',
              onTap: () => context.go('/admin/fraud-alerts'),
            ),
            _ActionTile(
              icon: Icons.people,
              title: 'User Management',
              subtitle: 'Manage farmers, vets, agents, and admins',
              onTap: () {},
            ),
            _ActionTile(
              icon: Icons.map,
              title: 'GPS Map View',
              subtitle: 'View proposal/claim locations on map',
              onTap: () {},
            ),
            _ActionTile(
              icon: Icons.analytics,
              title: 'MIS Reports',
              subtitle: 'Generate and view management reports',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
