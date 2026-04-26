import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:lucide_icons/lucide_icons.dart';

class DualActionFab extends StatelessWidget {
  const DualActionFab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          heroTag: 'fab_vendor_scan',
          onPressed: () => context.push('/inventory-upload'),
          icon: const Icon(LucideIcons.scan, size: 18),
          label: const Text(
            "PURCHASE SCAN",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.8),
          ),
          backgroundColor: context.errorColor,
          foregroundColor: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          heroTag: 'fab_customer_snap',
          onPressed: () => context.pushNamed('upload'),
          icon: const Icon(LucideIcons.camera, size: 18),
          label: const Text(
            "NEW ORDER SNAP",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.8),
          ),
          backgroundColor: context.successColor,
          foregroundColor: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ],
    );
  }
}
