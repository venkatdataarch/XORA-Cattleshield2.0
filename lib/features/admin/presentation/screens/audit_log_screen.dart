import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/di/providers.dart';

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  String? _filterAction;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioClientProvider);
      String url = '/api/audit-logs/?limit=100';
      if (_filterAction != null) {
        url += '&action_type=$_filterAction';
      }
      final result = await dio.get(url);
      result.when(
        success: (response) {
          final data = response.data as Map<String, dynamic>;
          setState(() {
            _logs = List<Map<String, dynamic>>.from(data['logs'] ?? []);
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
        title: const Text('Audit Trail'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _filterAction = value);
              _loadLogs();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('All Actions')),
              const PopupMenuItem(value: 'CREATE', child: Text('CREATE')),
              const PopupMenuItem(value: 'UPDATE', child: Text('UPDATE')),
              const PopupMenuItem(value: 'DELETE', child: Text('DELETE')),
              const PopupMenuItem(value: 'APPROVE', child: Text('APPROVE')),
              const PopupMenuItem(value: 'REJECT', child: Text('REJECT')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text('No audit log entries yet'))
              : ListView.builder(
                  itemCount: _logs.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    return _AuditLogCard(log: log);
                  },
                ),
    );
  }
}

class _AuditLogCard extends StatelessWidget {
  final Map<String, dynamic> log;

  const _AuditLogCard({required this.log});

  Color _actionColor(String? action) {
    switch (action) {
      case 'CREATE':
        return Colors.green;
      case 'UPDATE':
        return Colors.blue;
      case 'DELETE':
        return Colors.red;
      case 'APPROVE':
        return Colors.teal;
      case 'REJECT':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = log['action_type']?.toString() ?? 'UNKNOWN';
    final resource = log['resource_type']?.toString() ?? '';
    final timestamp = log['timestamp']?.toString() ?? '';
    final userId = log['user_id']?.toString() ?? 'system';
    final role = log['user_role']?.toString() ?? '';
    final endpoint = log['api_endpoint']?.toString() ?? '';
    final ip = log['ip_address']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ExpansionTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: _actionColor(action).withValues(alpha: 0.15),
          child: Text(
            action[0],
            style: TextStyle(
              color: _actionColor(action),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _actionColor(action).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                action,
                style: TextStyle(
                  color: _actionColor(action),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                resource,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Text(
          timestamp.length > 19 ? timestamp.substring(0, 19) : timestamp,
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow('User ID', userId),
                _DetailRow('Role', role),
                _DetailRow('Endpoint', endpoint),
                _DetailRow('IP Address', ip),
                if (log['gps_latitude'] != null)
                  _DetailRow(
                    'GPS',
                    '${log['gps_latitude']}, ${log['gps_longitude']}',
                  ),
                if (log['details'] != null)
                  _DetailRow('Details', log['details'].toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
