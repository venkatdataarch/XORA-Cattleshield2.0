import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/di/providers.dart';
import '../../core/network/sync_service.dart';

class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);
    final syncState = ref.watch(syncServiceProvider);

    return connectivity.when(
      data: (results) {
        final isOffline = results.every((r) => r == ConnectivityResult.none);

        if (!isOffline && syncState.pendingCount == 0) {
          return const SizedBox.shrink();
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isOffline ? AppColors.error : AppColors.warning,
          child: Row(
            children: [
              Icon(
                isOffline ? Icons.cloud_off : Icons.sync,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOffline
                      ? 'You are offline. Changes will sync when connected.'
                      : '${syncState.pendingCount} item(s) pending sync',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (!isOffline && syncState.pendingCount > 0)
                GestureDetector(
                  onTap: () =>
                      ref.read(syncServiceProvider.notifier).syncAll(),
                  child: const Text(
                    'Sync Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
