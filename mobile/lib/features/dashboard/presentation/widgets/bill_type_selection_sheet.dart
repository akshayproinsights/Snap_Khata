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
  final BuildContext parentContext;
  const BillTypeSelectionSheet({super.key, required this.parentContext});

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
            'How would you like to bill?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Selectable Cards
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── PRIMARY SCAN CARDS (MVP) ──
                  _buildPrimaryScanCard(
                    context: context,
                    type: BillScanType.customer,
                    title: 'Scan Customer Bill',
                    badgeText: 'Money In',
                    badgeColor: context.successColor,
                    icon: LucideIcons.user,
                    gradientColors: [
                      context.successColor.withValues(alpha: isDark ? 0.12 : 0.05),
                      context.successColor.withValues(alpha: isDark ? 0.04 : 0.01),
                    ],
                    isDark: isDark,
                  ),
                  _buildPrimaryScanCard(
                    context: context,
                    type: BillScanType.supplier,
                    title: 'Scan Supplier Bill',
                    badgeText: 'Money Out',
                    badgeColor: context.errorColor,
                    icon: LucideIcons.truck,
                    gradientColors: [
                      context.errorColor.withValues(alpha: isDark ? 0.12 : 0.05),
                      context.errorColor.withValues(alpha: isDark ? 0.04 : 0.01),
                    ],
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),

                  // ── Divider with label ──
                  Row(
                    children: [
                      Expanded(child: Divider(color: context.borderColor)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR ENTER MANUALLY',
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
                  const SizedBox(height: 16),

                  // ── SECONDARY MANUAL CARDS ──
                  Row(
                    children: [
                      _buildSecondaryManualCard(
                        context: context,
                        title: 'Quick Bill',
                        icon: LucideIcons.shoppingCart,
                        onTap: () => _handleAction(BillScanType.quickBill),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 12),
                      _buildSecondaryManualCard(
                        context: context,
                        title: 'Manual Entry',
                        icon: LucideIcons.edit3,
                        onTap: () async {
                          Navigator.pop(context);
                          await showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            useRootNavigator: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const AddPartyEntrySheet(),
                          );
                        },
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
      final result = await Navigator.push<List<CatalogueCartItem>>(
        widget.parentContext,
        MaterialPageRoute(
          builder: (_) => const ItemCataloguePage(selectionMode: true),
        ),
      );
      if (result != null && result.isNotEmpty && widget.parentContext.mounted) {
        await showModalBottomSheet(
          context: widget.parentContext,
          isScrollControlled: true,
          useRootNavigator: true,
          backgroundColor: Colors.transparent,
          builder: (context) => AddPartyEntrySheet(initialItems: result),
        );
      }
      return;
    }

    // Give a small delay for the selection animation to be visible
    await Future.delayed(const Duration(milliseconds: 150));
    
    if (!mounted || !widget.parentContext.mounted) return;

    final router = GoRouter.of(widget.parentContext);
    
    // Close the bottom sheet first
    Navigator.pop(context);
    
    // Navigate and wait for result
    final result = type == BillScanType.customer
        ? await router.pushNamed('upload')
        : await router.pushNamed('inventory-upload');
    
    // If the user successfully completed a scan/save, result should be true
    if (result == true && widget.parentContext.mounted) {
      // Trigger global refresh via providers using parentContext's provider container
      final container = ProviderScope.containerOf(widget.parentContext);
      container.invalidate(recentActivitiesProvider);
      container.invalidate(dashboardTotalsProvider);
    }
  }

  /// Large, premium stacked hero card for scanning bills
  Widget _buildPrimaryScanCard({
    required BuildContext context,
    required BillScanType type,
    required String title,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
    required List<Color> gradientColors,
    required bool isDark,
  }) {
    final isSelected = selectedType == type;

    return GestureDetector(
      onTap: () => _handleAction(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected
                ? [
                    badgeColor,
                    badgeColor.withValues(alpha: 0.8),
                  ]
                : gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? badgeColor
                : badgeColor.withValues(alpha: 0.25),
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: badgeColor.withValues(alpha: 0.3),
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
                    : badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : badgeColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? Colors.white : context.textColor,
                      letterSpacing: -0.5,
                    ),
                  ),

                ],
              ),
            ),
            Icon(
              LucideIcons.scan,
              color: isSelected
                  ? Colors.white
                  : badgeColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Compact side-by-side card for manual options
  Widget _buildSecondaryManualCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.borderColor,
              width: 1.5,
            ),
            boxShadow: context.premiumShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.textSecondaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: context.textSecondaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: context.textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
