import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/shared/presentation/widgets/global_task_banner.dart';
import 'package:mobile/features/upload/presentation/providers/upload_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(BuildContext context, WidgetRef ref, int index) {
    final uploadState = ref.read(uploadProvider);
    // Block navigation while file upload is in-flight
    if (uploadState.isUploading) return;
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadState = ref.watch(uploadProvider);
    final isUploading = uploadState.isUploading;

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
                icon: Icon(LucideIcons.book),
                selectedIcon: Icon(LucideIcons.book, color: AppTheme.primary),
                label: 'CREDIT',
              ),
              NavigationDestination(
                icon: Icon(LucideIcons.layoutGrid),
                selectedIcon:
                    Icon(LucideIcons.layoutGrid, color: AppTheme.primary),
                label: 'Inventory',
              ),
              NavigationDestination(
                icon: Icon(LucideIcons.user),
                selectedIcon: Icon(LucideIcons.user, color: AppTheme.primary),
                label: 'Settings',
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
class _UploadLockOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Blur the content behind
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            color: Colors.black.withValues(alpha: 0.55),
          ),
        ),
        // Warning pill in the center
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.amber.shade700,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.shade900.withValues(alpha: 0.5),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, color: Colors.white, size: 36),
                const SizedBox(height: 12),
                const Text(
                  'Upload in Progress',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait here until your\nphoto finishes uploading.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ).animate().scale(
                duration: 300.ms,
                curve: Curves.easeOutBack,
              ),
        ),
      ],
    );
  }
}

