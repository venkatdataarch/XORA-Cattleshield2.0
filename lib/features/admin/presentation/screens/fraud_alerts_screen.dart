import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/di/providers.dart';

class FraudAlertsScreen extends ConsumerStatefulWidget {
  const FraudAlertsScreen({super.key});

  @override
  ConsumerState<FraudAlertsScreen> createState() => _FraudAlertsScreenState();
}

class _FraudAlertsScreenState extends ConsumerState<FraudAlertsScreen> {
  List<Map<String, dynamic>> _alerts = [];
  bool _loading = true;
  bool _showResolved = false;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioClientProvider);
      String url = '/api/fraud-alerts/?limit=100';
      if (!_showResolved) {
        url += '&resolved=false';
      }
      final result = await dio.get(url);
      result.when(
        success: (response) {
          final data = response.data as Map<String, dynamic>;
          setState(() {
            _alerts = List<Map<String, dynamic>>.from(data['alerts'] ?? []);
            _loading = false;
          });
        },
        failure: (_) {
          setState(() => _loading = false);
        },
      );
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fraud Alerts'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Show resolved', style: TextStyle(fontSize: 12)),
              Switch(
                value: _showResolved,
                onChanged: (v) {
                  setState(() => _showResolved = v);
                  _loadAlerts();
                },
                activeColor: Colors.white,
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _alerts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 64, color: Colors.green.shade300),
                      const SizedBox(height: 16),
                      const Text('No active fraud alerts'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _alerts.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final alert = _alerts[index];
                    return _FraudAlertCard(alert: alert);
                  },
                ),
    );
  }
}

class _FraudAlertCard extends StatelessWidget {
  final Map<String, dynamic> alert;

  const _FraudAlertCard({required this.alert});

  Color _riskColor(String? level) {
    switch (level) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.yellow.shade700;
      default:
        return Colors.grey;
    }
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'duplicate_muzzle':
        return Icons.copy;
      case 'gps_anomaly':
        return Icons.location_off;
      case 'claim_velocity':
        return Icons.speed;
      case 'early_claim':
        return Icons.timer;
      case 'muzzle_mismatch':
        return Icons.fingerprint;
      case 'agent_anomaly':
        return Icons.person_off;
      default:
        return Icons.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = alert['alert_type']?.toString() ?? '';
    final risk = alert['risk_level']?.toString() ?? 'medium';
    final desc = alert['description']?.toString() ?? '';
    final timestamp = alert['timestamp']?.toString() ?? '';
    final resolved = alert['resolved'] == true;
    final factors = alert['contributing_factors'] as List? ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: resolved ? Colors.grey.shade300 : _riskColor(risk).withValues(alpha: 0.5),
          width: resolved ? 1 : 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_typeIcon(type), color: _riskColor(risk), size: 24),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _riskColor(risk).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    risk.toUpperCase(),
                    style: TextStyle(
                      color: _riskColor(risk),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    type.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (resolved)
                  const Chip(
                    label: Text('Resolved', style: TextStyle(fontSize: 10)),
                    backgroundColor: Colors.green,
                    labelStyle: TextStyle(color: Colors.white),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(desc, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Text(
              timestamp.length > 19 ? timestamp.substring(0, 19) : timestamp,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            if (factors.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Contributing Factors:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              ...factors.map((f) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 12)),
                        Expanded(
                          child: Text(
                            f.toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
