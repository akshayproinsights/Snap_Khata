import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/features/inventory/domain/models/inventory_models.dart';
import 'package:mobile/features/inventory/presentation/inventory_review_page.dart';
import 'package:mobile/shared/widgets/robust_receipt_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:mobile/features/inventory/domain/models/vendor_ledger_models.dart';
import 'package:mobile/features/inventory/presentation/providers/vendor_ledger_provider.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_items_provider.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/theme/context_extension.dart';

class VendorDeliveryDetailPage extends ConsumerWidget {
  final InventoryInvoiceBundle bundle;

  const VendorDeliveryDetailPage({super.key, required this.bundle});


  void _showReceiptDialog(BuildContext context) {
    if (bundle.receiptLink.isEmpty || bundle.receiptLink == 'null') return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Invoice Image'),
          ),
          body: InteractiveViewer(
            maxScale: 5.0,
            child: Center(
              child: RobustReceiptImageFullScreen(
                imageUrl: bundle.receiptLink,
                maxRetries: 3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasLink = bundle.receiptLink.isNotEmpty && bundle.receiptLink != 'null';
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final totalAmount = bundle.totalAmount;
    final hasChori = bundle.hasChoriCatcherAlert;

    // Watch inventory items to get the latest payment status (reactive sync)
    final inventoryItemsAsync = ref.watch(inventoryItemsProvider);
    
    // Determine effective payment mode by joining with latest items
    String effectivePaymentMode = bundle.paymentMode;
    inventoryItemsAsync.whenData((items) {
      final key = bundle.invoiceNumber.isNotEmpty
          ? bundle.invoiceNumber
          : '${bundle.date}_${bundle.vendorName}';
          
      final matchingItems = items.where((item) {
        final itemKey = item.invoiceNumber.isNotEmpty
            ? item.invoiceNumber
            : '${item.invoiceDate}_${item.vendorName ?? ''}';
        return itemKey == key;
      }).toList();
      
      if (matchingItems.isNotEmpty) {
        bool hasCash = matchingItems.any((i) => i.paymentMode == 'Cash');
        effectivePaymentMode = hasCash ? 'Cash' : 'Credit';
      }
    });

    final isPaid = effectivePaymentMode == 'Cash';

    return Scaffold(
      backgroundColor: context.backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Bill Details'),
        backgroundColor: context.surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(LucideIcons.edit, color: context.primaryColor),
            tooltip: 'Edit Details',
            onPressed: () => context.push('/inventory-invoice-review', extra: bundle),
          ),
          if (hasLink)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Icon(LucideIcons.eye, color: context.primaryColor),
                tooltip: 'View Original Receipt',
                onPressed: () => _showReceiptDialog(context),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          children: [
            // ── Rate Hike Alert banner ──────────────────────────
            if (hasChori) _buildRateHikeBanner(context),
            _buildHeader(context),
            const SizedBox(height: 12),
            _buildVendorCard(context, isPaid),
            const SizedBox(height: 12),
            _buildItemsSection(context),
          ],
        ),
      ),
      bottomNavigationBar: _buildStickyBottomBar(context, totalAmount, keyboardInset, isPaid),
    );
  }

  // ── Rate Hike banner ────────────────────────────────────────────────────
  Widget _buildRateHikeBanner(BuildContext context) {
    final hasMismatch = bundle.hasMismatch;
    final priceHike = bundle.totalPriceHike;

    // Build list of plain-language alerts
    final List<String> alerts = [];
    if (hasMismatch) {
      alerts.add('Bill total does not match our calculation — possible overcharge.');
    }
    if (priceHike > 0) {
      alerts.add(
          'Price went up by ${CurrencyFormatter.format(priceHike)} compared to last purchase.');
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.errorColor.withValues(alpha: 0.05),
        border: Border.all(color: context.errorColor.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: context.errorColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.warning_amber_rounded,
                    size: 18, color: context.errorColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '🔴 Rate Hike Alert',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: context.errorColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Alert lines
          ...alerts.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ',
                        style: TextStyle(
                            color: context.errorColor,
                            fontWeight: FontWeight.bold)),
                    Expanded(
                        child: Text(a,
                            style: TextStyle(
                                fontSize: 13,
                                color: context.textColor,
                                fontWeight: FontWeight.w500))),
                  ],
                ),
              )),
          const SizedBox(height: 4),
          Text(
            'Tap Edit (top-right) to review and fix.',
            style: TextStyle(
                fontSize: 11.5,
                color: context.errorColor.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar(BuildContext context, double grandTotal, double keyboardInset, bool isPaid) {

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.3 : 0.08),
              offset: const Offset(0, -4),
              blurRadius: 20,
            )
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Amount column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Bill Amount',
                            style: TextStyle(
                                color: context.textSecondaryColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Text(CurrencyFormatter.format(grandTotal),
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: context.textColor,
                                letterSpacing: -0.5)),
                        const SizedBox(height: 10),
                        // ── Credit Status Badge ──────────────
                        if (!isPaid)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: context.errorColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: context.errorColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.alertCircle,
                                  size: 13,
                                  color: context.errorColor,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Credit (Due)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: context.errorColor,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: context.successColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: context.successColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.checkCircle2,
                                  size: 13,
                                  color: context.successColor,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Paid (Cash)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: context.successColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Verify / Verified button
                  if (!bundle.isVerified)
                    FilledButton.icon(
                      onPressed: () =>
                          context.push('/inventory-invoice-review', extra: bundle),
                      icon: const Icon(LucideIcons.checkCircle, size: 18),
                      label: const Text('Verify'),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.primaryColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: context.successColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: context.successColor.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.checkCircle2,
                              size: 18, color: context.successColor),
                          const SizedBox(width: 8),
                          Text('Verified',
                              style: TextStyle(
                                  color: context.successColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: context.surfaceColor,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Invoice No
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invoice Number',
                    style: TextStyle(
                        color: context.textSecondaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                    bundle.invoiceNumber.isNotEmpty
                        ? '#${bundle.invoiceNumber}'
                        : 'N/A',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: context.textColor)),
              ],
            ),
          ),
          // Divider
          Container(
            width: 1,
            height: 40,
            color: context.borderColor,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          // Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date',
                    style: TextStyle(
                        color: context.textSecondaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(bundle.date.isNotEmpty ? bundle.date : 'N/A',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: context.textColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorCard(BuildContext context, bool isPaid) {
    return Container(
      color: context.surfaceColor,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vendor Details',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: context.textColor)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: context.primaryColor.withValues(alpha: 0.04),
              border: Border.all(color: context.primaryColor.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: context.primaryColor.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Icon(LucideIcons.store, color: context.primaryColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Vendor Name',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text(
                          bundle.vendorName.isNotEmpty
                              ? bundle.vendorName
                              : 'Unknown Vendor',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: context.textColor),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isPaid) ...[
            const SizedBox(height: 14),
            _VendorCreditBookButton(
              vendorName: bundle.vendorName.isNotEmpty
                  ? bundle.vendorName
                  : 'Unknown Vendor',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsSection(BuildContext context) {
    return Container(
      color: context.surfaceColor,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [context.primaryColor, context.primaryColor.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.shoppingBag, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Item Details',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ...bundle.items.asMap().entries.map((e) {
            return _ItemRow(
              index: e.key + 1,
              item: e.value,
              isLast: e.key == bundle.items.length - 1,
            );
          }),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final int index;
  final InventoryItem item;
  final bool isLast;

  const _ItemRow({
    required this.index,
    required this.item,
    this.isLast = false,
  });


  @override
  Widget build(BuildContext context) {
    final hasMismatch = item.amountMismatch.abs() > 1.0;
    final qtyStr = item.quantity == item.quantity.roundToDouble() 
        ? item.quantity.toInt().toString() 
        : item.quantity.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: isLast ? Colors.transparent : context.borderColor.withValues(alpha: 0.5))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIndexBadge(context),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                    item.description.isNotEmpty ? item.description : item.partNumber,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: context.textColor)),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(CurrencyFormatter.format(item.netBill),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: context.textColor)),
                  if (hasMismatch) ...[
                    const SizedBox(height: 2),
                    Text('+Tax/Fees', style: TextStyle(color: context.errorColor, fontSize: 10, fontWeight: FontWeight.w600)),
                  ]
                ],
              )
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Row(
              children: [
                Text(
                  '$qtyStr  x  ${CurrencyFormatter.format(item.rate)}',
                  style: TextStyle(
                      color: context.textSecondaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
                if (hasMismatch)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.errorColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Mismatch',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: context.errorColor)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndexBadge(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: context.borderColor.withValues(alpha: 0.1),
        border: Border.all(color: context.borderColor.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text('#$index',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: context.textSecondaryColor,
                fontSize: 10)),
      ),
    );
  }
}

class _VendorCreditBookButton extends ConsumerWidget {
  final String vendorName;

  const _VendorCreditBookButton({
    required this.vendorName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();

        VendorLedger? findMatch(List<VendorLedger> ledgers) {
          final sName = vendorName.toLowerCase().trim();
          if (sName.isEmpty) return null;

          // 1. Try exact match on Name
          if (sName != 'unknown' && sName != 'unknown vendor') {
            final matches = ledgers.where((l) => l.vendorName.toLowerCase().trim() == sName);
            if (matches.isNotEmpty) return matches.first;
          }

          // 2. Try partial match on Name
          if (sName != 'unknown' && sName != 'unknown vendor') {
            final matches = ledgers.where((l) => l.vendorName.toLowerCase().contains(sName));
            if (matches.isNotEmpty) return matches.first;
          }

          return null;
        }

        final state = ref.read(vendorLedgerProvider);
        VendorLedger? match = findMatch(state.ledgers);

        // If no match found, try refreshing data once
        if (match == null) {
          await ref.read(vendorLedgerProvider.notifier).fetchLedgers();
          final newState = ref.read(vendorLedgerProvider);
          match = findMatch(newState.ledgers);
        }

        if (!context.mounted) return;

        if (match == null) {
          // If still no match, go to vendor ledger list
          context.push('/inventory/vendor-ledger');
          return;
        }

        context.push('/inventory/vendor-ledger/${match.id}', extra: match);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.warningColor.withValues(alpha: 0.15),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.warningColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.bookOpen, size: 18, color: context.warningColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'View in Credit Book',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: context.warningColor,
                    ),
                  ),
                  Text(
                    'Check previous balances & history',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textSecondaryColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 18, color: context.textSecondaryColor.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}
