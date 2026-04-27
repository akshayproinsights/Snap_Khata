import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/activities/presentation/providers/activity_provider.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_providers.dart';

enum BillScanType { customer, supplier }

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
          const SizedBox(height: 32),
          
          // Body Section
          const Text(
            'Who is this bill for?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose Customer or Supplier before scanning.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 32),

          // Selectable Cards
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTypeCard(
                    type: BillScanType.customer,
                    title: 'Customer',
                    subtitle: '↓ Money In',
                    subtitleColor: context.successColor,
                    icon: LucideIcons.user,
                    isSelected: selectedType == BillScanType.customer,
                    selectedColor: context.successColor,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildTypeCard(
                    type: BillScanType.supplier,
                    title: 'Supplier',
                    subtitle: '↑ Money Out',
                    subtitleColor: context.errorColor,
                    icon: LucideIcons.truck,
                    isSelected: selectedType == BillScanType.supplier,
                    selectedColor: context.errorColor,
                    isDark: isDark,
                  ),
                  // Add a small bottom padding to the scrollable area
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Dynamic Action Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: selectedType == null
                      ? null
                      : () async {
                          final router = GoRouter.of(context);
                          
                          // Close the bottom sheet first
                          Navigator.pop(context);
                          
                          // Navigate and wait for result
                          final result = selectedType == BillScanType.customer
                              ? await router.pushNamed('upload')
                              : await router.push('/inventory-upload');
                          
                          // If the user successfully completed a scan/save, result should be true
                          if (result == true && mounted) {
                            // Trigger global refresh via providers
                            ref.invalidate(recentActivitiesProvider);
                            ref.invalidate(dashboardTotalsProvider);
                            
                            // Optional: Small feedback toast could be added here later
                          }
                        },
                  icon: Icon(
                    selectedType == null
                        ? LucideIcons.scan
                        : selectedType == BillScanType.customer
                            ? Icons.camera_alt_outlined
                            : Icons.camera_alt_rounded,
                  ),
                  label: Text(
                    selectedType == null
                        ? 'Select an option'
                        : selectedType == BillScanType.customer
                            ? 'Snap New Order'
                            : 'Scan Supplier Purchase',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedType == null
                        ? context.textSecondaryColor.withValues(alpha: 0.5)
                        : selectedType == BillScanType.customer
                            ? context.successColor // Green for customer
                            : context.errorColor, // Red for supplier
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: context.textSecondaryColor.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    shadowColor: (selectedType == BillScanType.customer 
                            ? context.successColor 
                            : context.errorColor).withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeCard({
    required BillScanType type,
    required String title,
    required String subtitle,
    required Color subtitleColor,
    required IconData icon,
    required bool isSelected,
    required Color selectedColor,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () => setState(() => selectedType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: isDark ? 0.15 : 0.05)
              : context.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? selectedColor
                : context.borderColor,
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isSelected ? selectedColor : context.textSecondaryColor)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isSelected ? selectedColor : context.textSecondaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(LucideIcons.checkCircle2, color: selectedColor, size: 24),
          ],
        ),
      ),
    );
  }
}
