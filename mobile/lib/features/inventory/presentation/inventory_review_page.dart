import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';
import 'package:mobile/features/inventory/domain/models/invoice_item_v2_model.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_upload_provider.dart';
import 'package:mobile/shared/widgets/app_toast.dart';

// ─── Grouped invoice bundle ──────────────────────────────────────────────────
class InventoryInvoiceBundle {
  final String invoiceNumber;
  final String date;
  final String vendorName;
  final String receiptLink;
  final List<InventoryItem> items;
  double totalAmount;
  bool hasMismatch;
  bool isVerified;
  String createdAt;
  List<HeaderAdjustment> headerAdjustments;
  String paymentMode;

  InventoryInvoiceBundle({
    required this.invoiceNumber,
    required this.date,
    required this.vendorName,
    required this.receiptLink,
    required this.items,
    required this.totalAmount,
    required this.hasMismatch,
    required this.isVerified,
    required this.createdAt,
    this.headerAdjustments = const [],
    this.paymentMode = 'Credit',
  });

  bool get isPaid => paymentMode == 'Cash';

  double get totalPriceHike => items.fold(0.0, (sum, item) => sum + (item.priceHikeAmount ?? 0.0));

  bool get hasChoriCatcherAlert => hasMismatch || totalPriceHike > 0.01;
}

class InventoryReviewPage extends ConsumerStatefulWidget {
  const InventoryReviewPage({super.key});

  @override
  ConsumerState<InventoryReviewPage> createState() =>
      _InventoryReviewPageState();
}

class _InventoryReviewPageState extends ConsumerState<InventoryReviewPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(inventoryProvider.notifier).fetchItems();
      }
    });
  }

  List<InventoryInvoiceBundle> _groupItems(List<InventoryItem> items) {
    final Map<String, InventoryInvoiceBundle> groups = {};
    for (final item in items) {
      final key = item.invoiceNumber.isNotEmpty
          ? item.invoiceNumber
          : '${item.invoiceDate}_${item.vendorName ?? ''}';
      final safeKey = key.isNotEmpty ? key : item.id.toString();

      if (!groups.containsKey(safeKey)) {
        groups[safeKey] = InventoryInvoiceBundle(
          invoiceNumber: item.invoiceNumber,
          date: item.invoiceDate,
          vendorName: item.vendorName?.isNotEmpty == true
              ? item.vendorName!
              : 'Unknown Vendor',
          receiptLink: item.receiptLink,
          items: [],
          totalAmount: 0,
          hasMismatch: false,
          isVerified: true,
          createdAt: item.createdAt ?? '',
          headerAdjustments: item.headerAdjustments ?? [],
        );
      }
      final bundle = groups[safeKey]!;
      bundle.items.add(item);
      bundle.totalAmount += item.netBill;
      if (item.amountMismatch.abs() > 1.0) bundle.hasMismatch = true;
      if (item.verificationStatus != 'Done') bundle.isVerified = false;
      if (item.createdAt != null &&
          (bundle.createdAt.isEmpty ||
              item.createdAt!.compareTo(bundle.createdAt) > 0)) {
        bundle.createdAt = item.createdAt!;
      }
    }

    final allBundles = groups.values.toList();
    return allBundles
      ..sort((a, b) {
        if (a.hasMismatch && !b.hasMismatch) return -1;
        if (!a.hasMismatch && b.hasMismatch) return 1;
        if (a.createdAt.isNotEmpty && b.createdAt.isNotEmpty) {
          final cA = DateTime.tryParse(a.createdAt) ?? DateTime(0);
          final cB = DateTime.tryParse(b.createdAt) ?? DateTime(0);
          final dateCmp = cB.compareTo(cA);
          if (dateCmp != 0) return dateCmp;
        }
        final dA = DateTime.tryParse(a.date) ?? DateTime(0);
        final dB = DateTime.tryParse(b.date) ?? DateTime(0);
        return dB.compareTo(dA);
      });
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: context.textSecondaryColor,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: context.borderColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: context.textSecondaryColor,
            ),
          ),
        ),
        const Spacer(),
        Container(
          height: 1,
          width: 40,
          color: context.borderColor.withValues(alpha: 0.3),
        ),
      ],
    );
  }

  void _onBundleTap(InventoryInvoiceBundle bundle, List<InventoryInvoiceBundle> allBundles) async {
    HapticFeedback.lightImpact();
    final index = allBundles.indexOf(bundle);
    await context.push('/inventory-invoice-review', extra: {
      'bundle': bundle,
      'allBundles': allBundles,
      'currentIndex': index,
    });
    if (mounted) {
      ref.read(inventoryProvider.notifier).fetchItems();
    }
  }

  String _dateLabel(String rawDate) {
    final dt = DateTime.tryParse(rawDate);
    if (dt == null) return rawDate;
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(dt.year, dt.month, dt.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('d MMM').format(dt);
  }

  void _syncAndFinish() async {
    await ref.read(inventoryProvider.notifier).syncAndFinish();
    if (!mounted) return;
    final state = ref.read(inventoryProvider);
    if (state.error == null) {
      AppToast.showSuccess(context, 'Inventory synced successfully!',
          title: 'Sync Complete');
      context.go('/');
    } else {
      AppToast.showError(context, state.error!, title: 'Sync Failed');
    }
  }

  Widget _buildProgressHeader(int total, int done, int pending, int error) {
    if (total == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: context.surfaceColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (pending > 0)
            _buildBadge(LucideIcons.clock, '$pending Pending', context.warningColor),
          if (pending > 0 && error > 0) const SizedBox(width: 12),
          if (error > 0)
            _buildBadge(LucideIcons.alertCircle, '$error Errors', context.errorColor),
          if (pending == 0 && error == 0 && done > 0)
            _buildBadge(LucideIcons.checkCircle2, 'All Verified', context.successColor),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final uploadState = ref.watch(inventoryUploadProvider);
    final skippedCount = uploadState.processingStatus?.skipped ?? 0;
    
    final allBundles = _groupItems(state.items);
    final total = allBundles.length;
    final done = allBundles.where((b) => b.isVerified && !b.hasMismatch).length;
    final pending = allBundles.where((b) => !b.isVerified && !b.hasMismatch).length;
    final error = allBundles.where((b) => b.hasMismatch).length;

    // Filter: ONLY show bundles that need action (not verified or has mismatch)
    final actionNeededBundles = allBundles.where((b) => !b.isVerified || b.hasMismatch).toList();

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.go('/'),
        ),
        title: Text('PENDING REVIEW', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: context.textColor)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: state.isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(LucideIcons.refreshCw),
            onPressed: () => ref.read(inventoryProvider.notifier).fetchItems(),
          ),
        ],
      ),
      body: Builder(builder: (context) {
        if (state.isSyncing) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text('Syncing to Ledgers...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textColor)),
                const SizedBox(height: 8),
                Text('Please wait while we update your records.', style: TextStyle(color: context.textSecondaryColor)),
              ],
            ),
          );
        }

        if (state.isLoading && allBundles.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (allBundles.isEmpty && !state.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.clipboardCheck, size: 64, color: context.successColor),
                const SizedBox(height: 16),
                Text('No inventory items to review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textColor)),
              ],
            ),
          );
        }

        final now = DateTime.now();
        final threshold = now.subtract(const Duration(hours: 48));
        
        final recentBundles = actionNeededBundles.where((b) {
          final dt = DateTime.tryParse(b.createdAt);
          return dt != null && dt.isAfter(threshold);
        }).toList();
        
        final olderBundles = actionNeededBundles.where((b) {
          final dt = DateTime.tryParse(b.createdAt);
          return dt == null || dt.isBefore(threshold);
        }).toList();

        final bool allVerified = actionNeededBundles.isEmpty && total > 0;

        return Column(
          children: [
            _buildProgressHeader(total, done, pending, error),
            if (state.isSyncing) const LinearProgressIndicator(),
            if (allVerified)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: context.successColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: Icon(LucideIcons.checkCircle2, color: context.successColor, size: 64),
                      ),
                      const SizedBox(height: 24),
                      Text('All Items Verified!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: context.textColor)),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: Text('All $done invoices are ready to be synced to your vendor ledgers.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: context.textSecondaryColor)),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: 200, height: 50,
                        child: FilledButton.icon(
                          onPressed: _syncAndFinish,
                          icon: const Icon(LucideIcons.refreshCw, size: 18),
                          label: const Text('Sync & Finish Now'),
                          style: FilledButton.styleFrom(backgroundColor: context.successColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    if (skippedCount > 0) ...[
                      _buildSkippedBanner(skippedCount),
                      const SizedBox(height: 16),
                    ],
                    if (recentBundles.isNotEmpty) ...[
                      _buildSectionHeader('RECENT UPLOADS', recentBundles.length),
                      const SizedBox(height: 12),
                      ...recentBundles.map((b) => _BundleReviewTile(bundle: b, dateLabel: _dateLabel(b.date), onTap: () => _onBundleTap(b, allBundles))),
                    ],
                    if (olderBundles.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionHeader('PENDING FROM PAST', olderBundles.length),
                      const SizedBox(height: 12),
                      ...olderBundles.map((b) => _BundleReviewTile(bundle: b, dateLabel: _dateLabel(b.date), onTap: () => _onBundleTap(b, allBundles))),
                    ],
                  ],
                ),
              ),
          ],
        );
      }),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: (actionNeededBundles.isNotEmpty)
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: FloatingActionButton.extended(
                  onPressed: state.isSyncing ? null : _syncAndFinish,
                  backgroundColor: context.primaryColor,
                  foregroundColor: Colors.white,
                  icon: state.isSyncing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(LucideIcons.checkCheck),
                  label: Text(state.isSyncing ? 'Syncing...' : 'Sync Anyway', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSkippedBanner(int count) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: context.warningColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: context.warningColor.withValues(alpha: 0.3))),
      child: Row(
        children: [
          Icon(LucideIcons.info, color: context.warningColor, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text('$count duplicate${count == 1 ? '' : 's'} skipped from recent upload.', style: TextStyle(color: context.warningColor, fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _BundleReviewTile extends ConsumerWidget {
  final InventoryInvoiceBundle bundle;
  final String dateLabel;
  final VoidCallback onTap;

  const _BundleReviewTile({required this.bundle, required this.dateLabel, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool hasMismatch = bundle.hasMismatch;
    final bool isVerified = bundle.isVerified;
    
    final Color borderColor = hasMismatch ? context.errorColor.withValues(alpha: 0.5) : (isVerified ? context.successColor.withValues(alpha: 0.5) : context.borderColor);
    final Color bgColor = isVerified ? context.successColor.withValues(alpha: 0.05) : context.surfaceColor;
    final Color iconColor = hasMismatch ? context.errorColor : (isVerified ? context.successColor : context.primaryColor);
    final IconData statusIcon = hasMismatch ? LucideIcons.alertCircle : (isVerified ? LucideIcons.checkCircle2 : LucideIcons.packageCheck);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor, width: hasMismatch ? 1.5 : 1.0)),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(statusIcon, color: iconColor, size: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bundle.vendorName, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: context.textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(dateLabel, style: TextStyle(fontSize: 12, color: context.textSecondaryColor)),
                          Text(' · ', style: TextStyle(color: context.textSecondaryColor)),
                          Text('${bundle.items.length} items', style: TextStyle(color: context.textSecondaryColor, fontSize: 12, fontWeight: FontWeight.w600)),
                          Text(' · ', style: TextStyle(color: context.textSecondaryColor)),
                          Text(CurrencyFormatter.format(bundle.totalAmount), style: TextStyle(color: context.textColor, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (hasMismatch) _tag('Review', context.errorColor) else if (isVerified) _tag('Verified', context.successColor) else _tag('Pending', context.warningColor),
                    const SizedBox(height: 8),
                    Icon(LucideIcons.chevronRight, size: 18, color: context.textSecondaryColor.withValues(alpha: 0.5)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}
