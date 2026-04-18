import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/features/inventory/domain/models/inventory_models.dart';
import 'package:mobile/features/inventory/presentation/inventory_review_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VendorDeliveryDetailPage extends StatelessWidget {
  final InventoryInvoiceBundle bundle;

  const VendorDeliveryDetailPage({super.key, required this.bundle});

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return NumberFormat('#,##0', 'en_IN').format(amount);
    }
    return NumberFormat('#,##0.00', 'en_IN').format(amount);
  }

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
              child: CachedNetworkImage(
                imageUrl: bundle.receiptLink,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
                errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLink = bundle.receiptLink.isNotEmpty && bundle.receiptLink != 'null';
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final totalAmount = bundle.totalAmount;
    final hasChori = bundle.hasChoriCatcherAlert;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Bill Details'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(LucideIcons.edit, color: Theme.of(context).colorScheme.primary),
            tooltip: 'Edit Details',
            onPressed: () => context.push('/inventory-invoice-review', extra: bundle),
          ),
          if (hasLink)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Icon(LucideIcons.eye, color: Theme.of(context).colorScheme.primary),
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
            // ── Chori Catcher Alert banner ──────────────────────────
            if (hasChori) _buildChoriCatcherBanner(context),
            _buildHeader(context),
            const SizedBox(height: 12),
            _buildVendorCard(context),
            const SizedBox(height: 12),
            _buildItemsSection(context),
          ],
        ),
      ),
      bottomNavigationBar: _buildStickyBottomBar(context, totalAmount, keyboardInset),
    );
  }

  // ── Chori Catcher banner ────────────────────────────────────────────────────
  Widget _buildChoriCatcherBanner(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final hasMismatch = bundle.hasMismatch;
    final priceHike = bundle.totalPriceHike;

    // Build list of plain-language alerts
    final List<String> alerts = [];
    if (hasMismatch) {
      alerts.add('Bill total does not match our calculation — possible overcharge.');
    }
    if (priceHike > 0) {
      alerts.add(
          'Price went up by ${currencyFormat.format(priceHike)} compared to last purchase.');
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.5),
        border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2)),
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
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.warning_amber_rounded,
                    size: 18, color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '🔴 Chori Catcher Alert',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.error,
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
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.bold)),
                    Expanded(
                        child: Text(a,
                            style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w500))),
                  ],
                ),
              )),
          const SizedBox(height: 4),
          Text(
            'Tap Edit (top-right) to review and fix.',
            style: TextStyle(
                fontSize: 11.5,
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar(BuildContext context, double grandTotal, double keyboardInset) {
    final isPaid = bundle.isPaid;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
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
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Text('₹${_formatAmount(grandTotal)}',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onSurface,
                                letterSpacing: -0.5)),
                        const SizedBox(height: 6),
                        // ── Paid / Credit status pill ──────────────
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPaid
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isPaid
                                  ? Colors.green.withValues(alpha: 0.4)
                                  : Colors.orange.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPaid
                                    ? LucideIcons.checkCircle2
                                    : LucideIcons.clock,
                                size: 13,
                                color: isPaid
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.orange.shade700,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isPaid ? 'Paid (Cash)' : 'Credit – Unpaid',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isPaid
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.orange.shade700,
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
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.green.shade200,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.checkCircle2,
                              size: 18, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Text('Verified',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
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
      color: Theme.of(context).colorScheme.surface,
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                        color: Theme.of(context).colorScheme.onSurface)),
              ],
            ),
          ),
          // Divider
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).colorScheme.outlineVariant,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          // Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(bundle.date.isNotEmpty ? bundle.date : 'N/A',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: Theme.of(context).colorScheme.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorCard(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vendor Details',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
              border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Icon(LucideIcons.store, color: Theme.of(context).colorScheme.primary),
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
                              color: Theme.of(context).colorScheme.onSurface),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.shoppingBag, color: Theme.of(context).colorScheme.onPrimary, size: 18),
                const SizedBox(width: 8),
                Text('Item Details',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
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

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return NumberFormat('#,##0', 'en_IN').format(amount);
    }
    return NumberFormat('#,##0.00', 'en_IN').format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final hasMismatch = item.amountMismatch.abs() > 1.0;
    final qtyStr = item.qty == item.qty.roundToDouble() 
        ? item.qty.toInt().toString() 
        : item.qty.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: isLast ? Colors.transparent : Theme.of(context).colorScheme.outlineVariant)),
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
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurface)),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${_formatAmount(item.netBill)}',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface)),
                  if (hasMismatch) ...[
                    const SizedBox(height: 2),
                    Text('+Tax/Fees', style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 10, fontWeight: FontWeight.w600)),
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
                  '$qtyStr  x  ₹${_formatAmount(item.rate)}',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Mismatch',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.error)),
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text('#$index',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10)),
      ),
    );
  }
}
