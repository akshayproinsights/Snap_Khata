import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';
import 'package:mobile/features/inventory/domain/models/invoice_item_v2_model.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_upload_provider.dart';
import 'package:mobile/shared/widgets/app_toast.dart';

// ─── Grouped invoice bundle (same structure as inventory_main_page) ───────────
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
  /// 'Cash' = fully paid on delivery; 'Credit' = outstanding/unpaid
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

  double get totalPriceHike {
    return items.fold(0.0, (sum, item) => sum + (item.priceHikeAmount ?? 0.0));
  }

  bool get hasChoriCatcherAlert => hasMismatch || totalPriceHike > 0;
}

// ─── Page ─────────────────────────────────────────────────────────────────────
class InventoryReviewPage extends ConsumerStatefulWidget {
  const InventoryReviewPage({super.key});

  @override
  ConsumerState<InventoryReviewPage> createState() =>
      _InventoryReviewPageState();
}

class _InventoryReviewPageState extends ConsumerState<InventoryReviewPage> {
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
          isVerified: true, // assume verified until we find otherwise
          createdAt: item.createdAt ?? '',
          headerAdjustments:
              item.headerAdjustments ?? [], // Take from the first item
        );
      }
      final bundle = groups[safeKey]!;
      bundle.items.add(item);
      bundle.totalAmount += item.netBill;
      if (item.amountMismatch.abs() > 1.0) bundle.hasMismatch = true;
      // If any item is NOT verified, the whole bundle is not verified
      if (item.verificationStatus != 'Done') bundle.isVerified = false;
      // Track most recent upload date
      if (item.createdAt != null &&
          (bundle.createdAt.isEmpty ||
              item.createdAt!.compareTo(bundle.createdAt) > 0)) {
        bundle.createdAt = item.createdAt!;
      }
    }

    final allBundles = groups.values.toList();

    // Mismatched bundles first, then newest uploaded first (using createdAt if available, else date)
    return allBundles
      ..sort((a, b) {
        if (a.hasMismatch && !b.hasMismatch) return -1;
        if (!a.hasMismatch && b.hasMismatch) return 1;

        // Use createdAt for precise newest-first sorting, fallback to invoice date
        if (a.createdAt.isNotEmpty && b.createdAt.isNotEmpty) {
          final cA = DateTime.tryParse(a.createdAt) ?? DateTime(0);
          final cB = DateTime.tryParse(b.createdAt) ?? DateTime(0);
          final dateCmp = cB.compareTo(cA); // Newest first
          if (dateCmp != 0) return dateCmp;
        }

        final dA = DateTime.tryParse(a.date) ?? DateTime(0);
        final dB = DateTime.tryParse(b.date) ?? DateTime(0);
        return dB.compareTo(dA); // Newest date first
      });
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
      context.go('/inventory');
    } else {
      AppToast.showError(context, state.error!, title: 'Sync Failed');
    }
  }

  Widget _buildProgressHeader(int total, int done, int pending, int error) {
    if (total == 0 || (pending == 0 && error == 0 && done == 0)) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Review Progress',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              Text('$done of $total Done',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? done / total : 0,
              backgroundColor: Colors.grey.shade200,
              color: Colors.green,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (pending > 0)
                _buildBadge(
                    LucideIcons.clock, '$pending Pending', Colors.orange),
              if (error > 0)
                _buildBadge(
                    LucideIcons.alertCircle, '$error Errors', Colors.red),
            ],
          )
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
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<InventoryState>(inventoryProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        AppToast.showError(context, next.error!, title: 'Update Failed');
      }
    });

    final state = ref.watch(inventoryProvider);
    final uploadState = ref.watch(inventoryUploadProvider);
    final skippedCount = uploadState.processingStatus?.skipped ?? 0;

    final allBundles = _groupItems(state.items);

    final total = allBundles.length;
    final done = allBundles.where((b) => b.isVerified && !b.hasMismatch).length;
    final pending =
        allBundles.where((b) => !b.isVerified && !b.hasMismatch).length;
    final error = allBundles.where((b) => b.hasMismatch).length;
    final allDone = total > 0 && done == total;

    final bundles = allBundles.where((b) => !b.isVerified).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.go('/dashboard'),
        ),
        title: const Text('PENDING REVIEW',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            )),
        centerTitle: false,
        actions: [
          IconButton(
            icon: state.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.refreshCw),
            tooltip: 'Refresh',
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(inventoryProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: Builder(builder: (context) {
        if (state.isLoading && bundles.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.error != null && bundles.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.wifiOff,
                      size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(state.error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        ref.read(inventoryProvider.notifier).refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (bundles.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.clipboardCheck,
                      size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text(
                    'No inventory items to review',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            _buildProgressHeader(total, done, pending, error),
            if (state.isSyncing) const LinearProgressIndicator(),
            if (skippedCount > 0)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.info,
                        color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$skippedCount duplicate${skippedCount == 1 ? '' : 's'} skipped from recent upload.',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(
                    left: 16, right: 16, top: 16, bottom: 100),
                itemCount: bundles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final bundle = bundles[index];
                  return _BundleReviewTile(
                    bundle: bundle,
                    dateLabel: _dateLabel(bundle.date),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.push('/inventory-invoice-review', extra: bundle);
                    },
                  );
                },
              ),
            ),
          ],
        );
      }),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: bundles.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: FloatingActionButton.extended(
                  onPressed: state.isSyncing ? null : _syncAndFinish,
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  icon: state.isSyncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(LucideIcons.checkCheck),
                  label: Text(
                    state.isSyncing
                        ? 'Syncing...'
                        : (allDone ? 'Sync & Finish' : 'Sync Anyway'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

// ─── Bundle Review Tile ───────────────────────────────────────────────────────
class _BundleReviewTile extends ConsumerWidget {
  final InventoryInvoiceBundle bundle;
  final String dateLabel;
  final VoidCallback onTap;

  const _BundleReviewTile({
    required this.bundle,
    required this.dateLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    Color borderColor;
    Color bgColor;
    Color iconBg;
    Color iconColor;
    IconData statusIcon;

    if (bundle.hasMismatch) {
      borderColor = const Color(0xFFEF4444).withValues(alpha: 0.5);
      bgColor = Colors.white;
      iconBg = const Color(0xFFEF4444).withValues(alpha: 0.08);
      iconColor = const Color(0xFFEF4444);
      statusIcon = LucideIcons.alertCircle;
    } else if (bundle.isVerified) {
      borderColor = Colors.green.shade300;
      bgColor = Colors.green.shade50;
      iconBg = Colors.green.withValues(alpha: 0.1);
      iconColor = Colors.green;
      statusIcon = LucideIcons.checkCircle2;
    } else {
      borderColor = Colors.grey.shade200;
      bgColor = Colors.white;
      iconBg = AppTheme.primary.withValues(alpha: 0.08);
      iconColor = AppTheme.primary;
      statusIcon = LucideIcons.packageCheck;
    }

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: bundle.hasMismatch ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration:
                    BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(statusIcon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bundle.vendorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                    ),
                    if (bundle.invoiceNumber.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(LucideIcons.hash,
                                size: 11, color: Colors.grey.shade500),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                bundle.invoiceNumber,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          dateLabel,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                        const Text(' · ',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                        Text(
                          '${bundle.items.length} item${bundle.items.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                        const Text(' · ',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                        Text(
                          currencyFormat.format(bundle.totalAmount),
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (bundle.hasMismatch)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color:
                                const Color(0xFFEF4444).withValues(alpha: 0.3)),
                      ),
                      child: const Text('⚠ Review',
                          style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    )
                  else if (bundle.isVerified)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Verified',
                              style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(width: 3),
                          Icon(LucideIcons.checkCircle2,
                              size: 11, color: Colors.green.shade600),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Text('Pending',
                          style: TextStyle(
                              color: Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ),
                  IconButton(
                    icon: Icon(LucideIcons.trash2,
                        size: 18, color: AppTheme.error.withValues(alpha: 0.7)),
                    onPressed: () => _confirmDelete(context, ref, bundle),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 20,
                  ),
                  const SizedBox(height: 10),
                  Icon(LucideIcons.chevronRight,
                      size: 18, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref,
      InventoryInvoiceBundle bundle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Invoice?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            'Are you sure you want to delete this invoice for "${bundle.vendorName}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ids = bundle.items.map((i) => i.id).toList();
      await ref.read(inventoryProvider.notifier).bulkDeleteItems(ids);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice deleted successfully'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}
