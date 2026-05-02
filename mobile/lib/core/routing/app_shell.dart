import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/shared/presentation/widgets/global_task_banner.dart';
import 'package:mobile/features/upload/presentation/providers/upload_provider.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(BuildContext context, WidgetRef ref, int index) {
    final uploadState = ref.read(uploadProvider);
    // Block navigation while file upload is in-flight
    if (uploadState.isUploading) return;

    // Background refresh totals when switching to main data tabs (Home or Parties)
    if (index == 0 || index == 1) {
      ref.read(dashboardTotalsProvider.notifier).refreshSilent();
    }

    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadState = ref.watch(uploadProvider);
    final isUploading = uploadState.isUploading;

    // ── GHOST STATE GUARD ──
    // If isUploading is true but no files are present and we aren't restoring state,
    // it's a "ghost" state. Auto-clear it to prevent user lockout.
    if (isUploading && !uploadState.hasFiles && !uploadState.isRestoringState) {
      Future.microtask(() => ref.read(uploadProvider.notifier).forceReset());
    }

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              const GlobalTaskBanner(),
              Expanded(
                child: Stack(
                  children: [
                    // ── Main navigation content ──
                    AbsorbPointer(
                      absorbing: isUploading,
                      child: navigationShell,
                    ),

                    // ── Upload lockout overlay (non-upload tabs only) ──
                    if (isUploading) _UploadLockOverlay(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Stack(
        children: [
          NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (int index) => _onTap(context, ref, index),
            backgroundColor: Theme.of(context).colorScheme.surface,
            indicatorColor: isUploading
                ? Colors.amber.withValues(alpha: 0.15)
                : AppTheme.primary.withValues(alpha: 0.15),
            destinations: const [
              NavigationDestination(
                icon: Icon(LucideIcons.home),
                selectedIcon: Icon(LucideIcons.home, color: AppTheme.primary),
                label: 'HOME',
              ),
              NavigationDestination(
                icon: Icon(LucideIcons.users),
                selectedIcon: Icon(LucideIcons.users, color: AppTheme.primary),
                label: 'PARTIES',
              ),
              // NavigationDestination(
              //   icon: Icon(LucideIcons.box),
              //   selectedIcon: Icon(LucideIcons.box, color: AppTheme.primary),
              //   label: 'Track Items',
              // ),
              NavigationDestination(
                icon: Icon(LucideIcons.user),
                selectedIcon: Icon(LucideIcons.user, color: AppTheme.primary),
                label: 'SETTINGS',
              ),
            ],
          ),

          // ── Lock badge on nav bar during upload ──
          if (isUploading)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.amber.shade600,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-screen blurred lockout overlay when upload is active and
/// the user is NOT on the Upload tab.
class _UploadLockOverlay extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        // Blur the content behind
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            color: Colors.black.withValues(alpha: 0.55),
          ),
        ),
        // Warning card in the center
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: BoxDecoration(
              color: context.isDark ? Colors.amber.shade900 : Colors.amber.shade700,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 32,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Upload in Progress',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Please wait until your photo finishes\nuploading to continue using the app.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                
                // ── ESCAPE HATCHES ──
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.push('/upload'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.amber.shade900,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('View Upload Progress', 
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        // Double check with user before cancelling? 
                        // For a quick fix, we just allow force-reset.
                        ref.read(uploadProvider.notifier).forceReset();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.8),
                      ),
                      child: const Text('Cancel & Unlock App', 
                        style: TextStyle(decoration: TextDecoration.underline)),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().scale(
                duration: 400.ms,
                curve: Curves.easeOutBack,
              ).fadeIn(),
        ),
      ],
    );
  }
}

