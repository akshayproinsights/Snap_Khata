import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/features/activities/domain/models/activity_item.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';
import 'package:mobile/features/inventory/domain/models/vendor_ledger_models.dart';
import 'package:mobile/features/inventory/presentation/providers/vendor_ledger_provider.dart';
import 'package:mobile/features/inventory/presentation/inventory_review_page.dart';

/// Renders a vendor (payable) transaction row.
/// Amounts are formatted with zero decimal digits per SnapKhata UI guidelines.
/// Shows a 🔴 "Price hike" alert banner when [ActivityItem.vendor.totalPriceHike] > 0.
class VendorActivityCard extends ConsumerWidget {
  const VendorActivityCard({super.key, required this.item});

  /// The vendor variant of [ActivityItem].
  final ActivityItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return item.maybeWhen(
      vendor: (id, entityName, transactionDate, amount, displayId, isPaid, balanceDue, totalPriceHike) {
        final hasPriceHike = totalPriceHike > 0;

        return Material(
          color: context.surfaceColor,
          child: InkWell(
            onTap: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );

              try {
                if (displayId != null && displayId.isNotEmpty && !displayId.toUpperCase().startsWith('PAY')) {
                  final notifier = ref.read(vendorLedgerProvider.notifier);
                  final itemsData = await notifier.fetchInvoiceItems(displayId);
                  
                  if (context.mounted && itemsData.isNotEmpty) {
                    Navigator.pop(context); // hide loading
                    final items = itemsData.map((e) => InventoryItem.fromJson(e as Map<String, dynamic>)).toList();
                    final bundle = InventoryInvoiceBundle(
                      invoiceNumber: items.first.invoiceNumber,
                      date: items.first.invoiceDate,
                      vendorName: items.first.vendorName ?? entityName,
                      receiptLink: items.first.receiptLink,
                      items: items,
                      totalAmount: items.fold(0.0, (sum, item) => sum + item.netBill),
                      hasMismatch: items.any((i) => i.amountMismatch.abs() > 1.0),
                      isVerified: items.every((i) => i.verificationStatus == 'Done'),
                      createdAt: items.first.createdAt ?? '',
                      paymentMode: isPaid ? 'Cash' : 'Credit',
                    );
                    context.push('/vendor-delivery-detail', extra: bundle);
                    return;
                  }
                }
              } catch (_) {}

              if (context.mounted) {
                Navigator.pop(context); // hide loading
                context.push('/vendor-ledger-detail', 
                  extra: VendorLedger(
                    id: -1, 
                    vendorName: entityName, 
                    balanceDue: balanceDue ?? 0.0,
                  )
                );
              }
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.borderColor.withValues(alpha: 0.5), width: 1),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Avatar ──────────────────────────────────────────────
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: hasPriceHike
                            ? context.errorColor.withValues(alpha: 0.12)
                            : context.primaryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        hasPriceHike ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                        color: hasPriceHike ? context.errorColor : context.primaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // ── Entity name + date + alert ───────────────────────────────────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entityName,
                            style: TextStyle(
                              color: context.textColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Supplier',
                            style: TextStyle(
                              color: context.textSecondaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // ── Price Hike Alert ────────────────────────────────
                          if (hasPriceHike) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: context.errorColor.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: context.errorColor.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      size: 13, color: context.errorColor),
                                  const SizedBox(width: 5),
                                  Text(
                                    '🔴 Price hike: ${CurrencyFormatter.format(totalPriceHike)} extra',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.errorColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ── Amount & Badge ───────────────────────────────────────────────
                      Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(amount),
                          style: TextStyle(
                            color: context.textColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _StatusChip(isPaid: isPaid, balanceDue: balanceDue),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Pill chip showing paid/unpaid status or balance due for vendor transactions.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isPaid, this.balanceDue});
  final bool isPaid;
  final double? balanceDue;

  @override
  Widget build(BuildContext context) {
    // If there's a positive balance due, we show "DUE"
    final hasDue = balanceDue != null && balanceDue! > 0;
    final color = hasDue ? context.warningColor : (isPaid ? context.successColor : context.errorColor);
    final label = hasDue ? 'DUE' : (isPaid ? 'PAID' : 'SETTLED');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
