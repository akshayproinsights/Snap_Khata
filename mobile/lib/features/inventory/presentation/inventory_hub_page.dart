import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/purchase_orders/presentation/providers/purchase_order_provider.dart';

/// A hub page that provides navigation to all inventory-related sub-pages.
class InventoryHubPage extends ConsumerWidget {
  const InventoryHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftCount =
        ref.watch(purchaseOrderProvider.select((s) => s.draftCount));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inventory Hub',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              'All inventory tools in one place',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader(label: 'Mapping'),
          const SizedBox(height: 8),
          _HubTile(
            icon: LucideIcons.gitMerge,
            iconColor: const Color(0xFF2563EB),
            iconBg: const Color(0xFFDBEAFE),
            title: 'Map Inventory Items',
            subtitle: 'Match invoice items to your product catalog',
            badge: null,
            onTap: () {
              HapticFeedback.lightImpact();
              context.pushNamed('inventory-item-mapping');
            },
          ),
          const SizedBox(height: 10),
          _HubTile(
            icon: LucideIcons.checkSquare,
            iconColor: const Color(0xFF16A34A),
            iconBg: const Color(0xFFDCFCE7),
            title: 'Mapped Items',
            subtitle: 'View and review all confirmed item mappings',
            badge: null,
            onTap: () {
              HapticFeedback.lightImpact();
              context.pushNamed('inventory-mapped');
            },
          ),
          const SizedBox(height: 10),
          _HubTile(
            icon: LucideIcons.truck,
            iconColor: const Color(0xFF9333EA),
            iconBg: const Color(0xFFF3E8FF),
            title: 'Vendor Mapping',
            subtitle: 'Link vendors to your supplier list',
            badge: null,
            onTap: () {
              HapticFeedback.lightImpact();
              context.pushNamed('vendor-mapping');
            },
          ),
          const SizedBox(height: 20),
          const _SectionHeader(label: 'Stock & Invoices'),
          const SizedBox(height: 8),
          _HubTile(
            icon: LucideIcons.package2,
            iconColor: const Color(0xFFD97706),
            iconBg: const Color(0xFFFEF3C7),
            title: 'Current Stock',
            subtitle: 'Live stock levels across all products',
            badge: null,
            onTap: () {
              HapticFeedback.lightImpact();
              context.pushNamed('current-stock');
            },
          ),
          const SizedBox(height: 10),
          _HubTile(
            icon: LucideIcons.fileCheck2,
            iconColor: const Color(0xFF0891B2),
            iconBg: const Color(0xFFCFFAFE),
            title: 'Verified Invoices',
            subtitle: 'All invoices that have passed verification',
            badge: null,
            onTap: () {
              HapticFeedback.lightImpact();
              context.pushNamed('verified-invoices');
            },
          ),
          const SizedBox(height: 10),
          _HubTile(
            icon: LucideIcons.upload,
            iconColor: const Color(0xFF4F46E5),
            iconBg: const Color(0xFFE0E7FF),
            title: 'Upload Inventory CSV',
            subtitle: 'Bulk upload stock data from a spreadsheet',
            badge: null,
            onTap: () {
              HapticFeedback.lightImpact();
              context.pushNamed('inventory-upload');
            },
          ),
          const SizedBox(height: 20),

          // ── Procurement ──────────────────────────────────────────────────────
          const _SectionHeader(label: 'Procurement'),
          const SizedBox(height: 8),
          _HubTile(
            icon: LucideIcons.shoppingCart,
            iconColor: const Color(0xFFEA580C),
            iconBg: const Color(0xFFFFF7ED),
            title: 'Purchase Orders',
            subtitle: 'Create, track and share POs with suppliers',
            badge: draftCount > 0 ? '$draftCount draft' : null,
            badgeColor: AppTheme.primary,
            onTap: () {
              HapticFeedback.lightImpact();
              context.pushNamed('purchase-orders');
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.textSecondary,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _HubTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.badge,
    this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBadgeColor = badgeColor ?? AppTheme.error;
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Badge or chevron
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: effectiveBadgeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: effectiveBadgeColor,
                    ),
                  ),
                )
              else
                const Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
