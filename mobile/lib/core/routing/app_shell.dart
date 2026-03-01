import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/shared/presentation/widgets/global_task_banner.dart';
import 'package:mobile/core/network/sync_provider.dart';
import 'package:toastification/toastification.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              const GlobalTaskBanner(),
              Expanded(child: navigationShell),
            ],
          ),
          // Sync Indicator overlaid at top right
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: _SyncIndicator(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int index) => _onTap(context, index),
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.primary.withOpacity(0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.home),
            selectedIcon: Icon(LucideIcons.home, color: AppTheme.primary),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.uploadCloud),
            selectedIcon:
                Icon(LucideIcons.uploadCloud, color: AppTheme.primary),
            label: 'Upload',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.layoutGrid),
            selectedIcon: Icon(LucideIcons.layoutGrid, color: AppTheme.primary),
            label: 'Inventory Hub',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.user),
            selectedIcon: Icon(LucideIcons.user, color: AppTheme.primary),
            label: 'Settings', // Using User icon for Profile/Settings combo
          ),
        ],
      ),
    );
  }
}

class _SyncIndicator extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);

    if (syncState.pendingCount == 0 && !syncState.isSyncing) {
      // Hide completely when zero to keep UI clean, or show a subtle icon
      // Let's show a subtle grey check icon when zero
      return IconButton(
        icon: const Icon(LucideIcons.cloudLightning,
            color: Colors.grey, size: 20),
        onPressed: () {
          toastification.show(
            context: context,
            title: const Text('All Caught Up'),
            description: const Text('All your data is synced to the cloud.'),
            type: ToastificationType.success,
            style: ToastificationStyle.flatColored,
            autoCloseDuration: const Duration(seconds: 3),
          );
        },
      ).animate().fadeIn(duration: 300.ms);
    }

    return Stack(
      children: [
        IconButton(
          icon: Icon(
            syncState.isSyncing ? LucideIcons.refreshCcw : LucideIcons.cloudOff,
            color: syncState.isSyncing ? AppTheme.primary : AppTheme.warning,
            size: 24,
          ),
          onPressed: () {
            toastification.show(
              context: context,
              title: const Text('Offline Mode'),
              description: Text(
                  '${syncState.pendingCount} action(s) saved offline. They will sync automatically when you reconnect.'),
              type: ToastificationType.warning,
              style: ToastificationStyle.flatColored,
              autoCloseDuration: const Duration(seconds: 5),
            );
          },
        ),
        if (syncState.pendingCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppTheme.error,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${syncState.pendingCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack);
  }
}
