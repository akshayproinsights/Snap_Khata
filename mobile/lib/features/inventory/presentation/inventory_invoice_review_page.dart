import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';
import 'package:mobile/features/inventory/presentation/inventory_review_page.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:mobile/features/review/presentation/receipt_review_page.dart';

class InventoryInvoiceReviewPage extends ConsumerStatefulWidget {
  final InventoryInvoiceBundle bundle;

  const InventoryInvoiceReviewPage({super.key, required this.bundle});

  @override
  ConsumerState<InventoryInvoiceReviewPage> createState() =>
      _InventoryInvoiceReviewPageState();
}

class _InventoryInvoiceReviewPageState
    extends ConsumerState<InventoryInvoiceReviewPage> {
  void _showFullImage(String imageUrl) {
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
            child: Center(
              child: Hero(
                tag: 'inv_img_${widget.bundle.invoiceNumber}',
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(color: Colors.white)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(double? v) {
    if (v == null) return '';
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Future<void> _markAllVerified(List<InventoryItem> items) async {
    for (final item in items) {
      await ref.read(inventoryProvider.notifier).updateItem(
        item.id,
        {'verification_status': 'Verified'},
      );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider so optimistic updates reflect immediately
    final state = ref.watch(inventoryProvider);

    // Recompute items for this bundle from latest state
    final invoiceKey = widget.bundle.invoiceNumber.isNotEmpty
        ? widget.bundle.invoiceNumber
        : '${widget.bundle.date}_${widget.bundle.vendorName}';

    final currentItems = state.items.where((i) {
      final key = i.invoiceNumber.isNotEmpty
          ? i.invoiceNumber
          : '${i.invoiceDate}_${i.vendorName ?? ''}';
      return key == invoiceKey;
    }).toList();

    // Mismatch items first
    final sortedItems = List<InventoryItem>.from(currentItems);
    sortedItems.sort((a, b) {
      final aMis = a.amountMismatch > 1.0;
      final bMis = b.amountMismatch > 1.0;
      if (aMis && !bMis) return -1;
      if (!aMis && bMis) return 1;
      return 0;
    });

    final hasAnyMismatch = sortedItems.any((i) => i.amountMismatch > 1.0);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.bundle.vendorName,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.bundle.invoiceNumber.isNotEmpty)
              Text(
                '#${widget.bundle.invoiceNumber}',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Receipt image
          if (widget.bundle.receiptLink.isNotEmpty)
            GestureDetector(
              onTap: () => _showFullImage(widget.bundle.receiptLink),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.25,
                width: double.infinity,
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'inv_img_${widget.bundle.invoiceNumber}',
                      child: CachedNetworkImage(
                        imageUrl: widget.bundle.receiptLink,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        placeholder: (ctx, url) => const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white)),
                        errorWidget: (ctx, url, err) => const Icon(
                            LucideIcons.imageOff,
                            color: Colors.white54,
                            size: 40),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.maximize,
                                color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text('Tap to expand',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Items list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                Row(
                  children: [
                    const Text(
                      'Line Items',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary),
                    ),
                    const Spacer(),
                    Text(
                      '${sortedItems.length} item${sortedItems.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (sortedItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                        child: Text('No items found.',
                            style: TextStyle(color: AppTheme.textSecondary))),
                  ),
                ...sortedItems.map((item) => _buildItemCard(item)),
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: double.infinity,
          child: FloatingActionButton.extended(
            onPressed: () => _markAllVerified(sortedItems),
            backgroundColor: hasAnyMismatch ? Colors.orange : Colors.green,
            foregroundColor: Colors.white,
            elevation: 4,
            icon: Icon(
                hasAnyMismatch ? LucideIcons.alertTriangle : LucideIcons.check),
            label: Text(
              hasAnyMismatch ? 'Save with Errors' : 'Mark as Verified',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(InventoryItem item) {
    final hasMismatch = item.amountMismatch > 1.0;
    final isVerified = item.verificationStatus == 'Verified';

    Color borderColor = AppTheme.border;
    Color bgColor = Colors.white;
    if (hasMismatch) {
      borderColor = Colors.red.shade400;
      bgColor = Colors.red.shade50;
    } else if (isVerified) {
      borderColor = Colors.green.shade400;
      bgColor = Colors.green.shade50;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: borderColor, width: hasMismatch || isVerified ? 2 : 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Part number + status icon row
          Row(
            children: [
              Expanded(
                child: Text(
                  item.partNumber.isNotEmpty
                      ? 'Part: ${item.partNumber}'
                      : 'Item #${item.id}',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600),
                ),
              ),
              if (hasMismatch)
                const Icon(LucideIcons.alertCircle, color: Colors.red, size: 16)
              else if (isVerified)
                const Icon(LucideIcons.checkCircle,
                    color: Colors.green, size: 16),
            ],
          ),
          const SizedBox(height: 8),

          // Description + Amount row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: DebouncedReviewField(
                  key: ValueKey('desc_${item.id}'),
                  initialValue: item.description,
                  decoration: _inputDecoration('Description').copyWith(
                    errorText:
                        item.description.trim().isEmpty ? 'Required' : null,
                  ),
                  maxLines: null,
                  onSaved: (val) {
                    if (val != item.description) {
                      ref.read(inventoryProvider.notifier).updateItem(
                        item.id,
                        {'description': val},
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DebouncedReviewField(
                  key: ValueKey('amount_${item.id}'),
                  initialValue: _fmt(item.netBill),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppTheme.primary),
                  decoration: _inputDecoration('Amount (₹)'),
                  onSaved: (val) {
                    final newAmount = double.tryParse(val);
                    if (newAmount != null && newAmount != item.netBill) {
                      ref.read(inventoryProvider.notifier).updateItem(
                        item.id,
                        {'net_bill': newAmount, 'amount_mismatch': 0},
                      );
                    }
                  },
                ),
              ),
            ],
          ),

          // Qty × Rate row
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DebouncedReviewField(
                  key: ValueKey('qty_${item.id}'),
                  initialValue: _fmt(item.qty),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDecoration('Qty'),
                  onSaved: (val) {
                    final newQty = double.tryParse(val);
                    if (newQty != null && newQty != item.qty) {
                      final newMismatch =
                          ((newQty * item.rate) - item.netBill).abs();
                      ref.read(inventoryProvider.notifier).updateItem(
                        item.id,
                        {'qty': newQty, 'amount_mismatch': newMismatch},
                      );
                    }
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child:
                    Text('×', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              Expanded(
                child: DebouncedReviewField(
                  key: ValueKey('rate_${item.id}'),
                  initialValue: _fmt(item.rate),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDecoration('Rate (₹)'),
                  onSaved: (val) {
                    final newRate = double.tryParse(val);
                    if (newRate != null && newRate != item.rate) {
                      final newMismatch =
                          ((item.qty * newRate) - item.netBill).abs();
                      ref.read(inventoryProvider.notifier).updateItem(
                        item.id,
                        {'rate': newRate, 'amount_mismatch': newMismatch},
                      );
                    }
                  },
                ),
              ),
            ],
          ),

          // Mismatch error hint
          if (hasMismatch) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(LucideIcons.alertTriangle,
                    size: 14, color: Colors.red),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Math Error: Qty × Rate ≠ Amount  (diff ₹${item.amountMismatch.toStringAsFixed(2)})',
                    style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
