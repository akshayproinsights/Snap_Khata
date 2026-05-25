import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/activities/presentation/providers/activity_provider.dart';
import 'package:mobile/features/udhar/presentation/widgets/add_party_entry_sheet.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mobile/features/udhar/presentation/pages/item_catalogue_page.dart';
import 'package:flutter/services.dart';

enum BillScanType { customer, supplier, quickBill }

class BillTypeSelectionSheet extends ConsumerStatefulWidget {
  const BillTypeSelectionSheet({super.key});

  @override
  ConsumerState<BillTypeSelectionSheet> createState() => _BillTypeSelectionSheetState();
}

class _BillTypeSelectionSheetState extends ConsumerState<BillTypeSelectionSheet> {
  BillScanType? selectedType;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: context.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: context.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: context.surfaceColor,
                  side: BorderSide(color: context.borderColor),
                ),
              ),
              const Text(
                'SNAP NEW BILL',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(LucideIcons.helpCircle, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: context.surfaceColor,
                  side: BorderSide(color: context.borderColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Body Section
          const Text(
            'What do you want to do?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scan a photo or quickly pick items from your list.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 24),

          // Selectable Cards
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Quick Bill (item catalogue) — most prominent option ──
                  _buildQuickBillCard(context, isDark),
                  const SizedBox(height: 12),

                  // ── Divider with label ──
                  Row(
                    children: [
                      Expanded(child: Divider(color: context.borderColor)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR SCAN A PHOTO',
                          style: TextStyle(
                            color: context.textSecondaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: context.borderColor)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactScanCard(
                          context: context,
                          type: BillScanType.customer,
                          label: 'Customer Bill',
                          badge: 'Money In',
                          badgeColor: context.successColor,
                          icon: LucideIcons.user,
                          isSelected: selectedType == BillScanType.customer,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCompactScanCard(
                          context: context,
                          type: BillScanType.supplier,
                          label: 'Supplier Bill',
                          badge: 'Money Out',
                          badgeColor: context.errorColor,
                          icon: LucideIcons.truck,
                          isSelected: selectedType == BillScanType.supplier,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Compact Manual Entry
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const AddPartyEntrySheet(),
                          );
                        },
                        icon: Icon(
                          LucideIcons.edit3,
                          size: 16,
                          color: context.textSecondaryColor,
                        ),
                        label: Text(
                          'Record manual entry',
                          style: TextStyle(
                            color: context.textSecondaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(BillScanType type) async {
    setState(() => selectedType = type);

    if (type == BillScanType.quickBill) {
      HapticFeedback.mediumImpact();
      Navigator.pop(context);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ItemCataloguePage(selectionMode: true),
        ),
      );
      return;
    }

    // Give a small delay for the selection animation to be visible
    await Future.delayed(const Duration(milliseconds: 150));
    
    if (!mounted) return;

    final router = GoRouter.of(context);
    
    // Close the bottom sheet first
    Navigator.pop(context);
    
    // Navigate and wait for result
    final result = type == BillScanType.customer
        ? await router.pushNamed('upload')
        : await router.pushNamed('inventory-upload');
    
    // If the user successfully completed a scan/save, result should be true
    if (result == true && mounted) {
      // Trigger global refresh via providers
      ref.invalidate(recentActivitiesProvider);
      ref.invalidate(dashboardTotalsProvider);
    }
  }

  /// Large, gradient hero card for Quick Bill — the most discoverable entry point.
  Widget _buildQuickBillCard(BuildContext context, bool isDark) {
    final isSelected = selectedType == BillScanType.quickBill;
    return GestureDetector(
      onTap: () => _handleAction(BillScanType.quickBill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected
                ? [
                    context.primaryColor,
                    context.primaryColor.withValues(alpha: 0.8),
                  ]
                : [
                    context.primaryColor.withValues(alpha: isDark ? 0.18 : 0.07),
                    context.primaryColor.withValues(alpha: isDark ? 0.08 : 0.03),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? context.primaryColor
                : context.primaryColor.withValues(alpha: 0.35),
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: context.primaryColor.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : context.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                LucideIcons.shoppingCart,
                color: isSelected ? Colors.white : context.primaryColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Bill',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? Colors.white : context.textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pick items from your list · no photo needed',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.85)
                          : context.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.arrowRight,
              color: isSelected
                  ? Colors.white
                  : context.primaryColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Compact side-by-side scan card for Customer / Supplier.
  Widget _buildCompactScanCard({
    required BuildContext context,
    required BillScanType type,
    required String label,
    required String badge,
    required Color badgeColor,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () => _handleAction(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? badgeColor.withValues(alpha: isDark ? 0.15 : 0.06)
              : context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? badgeColor : context.borderColor,
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isSelected ? badgeColor : context.textSecondaryColor)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? badgeColor : context.textSecondaryColor,
                    size: 18,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Icon(LucideIcons.checkCircle2, color: badgeColor, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: context.textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              badge,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: badgeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
