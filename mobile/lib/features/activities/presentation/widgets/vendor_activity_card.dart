import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/features/activities/domain/models/activity_item.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';
import 'package:mobile/features/inventory/presentation/inventory_review_page.dart';
import 'package:mobile/features/inventory/domain/models/vendor_ledger_models.dart';
import 'package:mobile/features/inventory/presentation/providers/vendor_ledger_provider.dart';

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
      vendor: (id, entityName, transactionDate, amount, displayId, isPaid, balanceDue, totalPriceHike, receiptLink, invoiceDate, inventoryItems, isVerified, balanceOwed) {
        final hasPriceHike = totalPriceHike > 0;
        final hasInvoiceRef = displayId != null && displayId.isNotEmpty;
        final hasDue = balanceDue != null && balanceDue > 0;
        final pendingAmount = hasDue ? balanceDue : 0.0;
        
        final String badgeText = hasDue 
            ? 'TO PAY' 
            : (isPaid ? 'PAID' : 'SETTLED');
            
        final Color statusColor = hasDue 
            ? context.errorColor 
            : (isPaid ? context.successColor : context.textSecondaryColor);

        // Date formatting
        final now = DateTime.now();
        final isToday = transactionDate.year == now.year && 
                        transactionDate.month == now.month && 
                        transactionDate.day == now.day;
        final isYesterday = transactionDate.year == now.year && 
                            transactionDate.month == now.month && 
                            transactionDate.day == (now.day - 1);
        
        String dateStr = "";
        if (isToday) {
          dateStr = "Today";
        } else if (isYesterday) {
          dateStr = "Yesterday";
        } else {
          dateStr = "${transactionDate.day}/${transactionDate.month}/${transactionDate.year}";
        }
        
        final timeStr = "${transactionDate.hour % 12 == 0 ? 12 : transactionDate.hour % 12}:${transactionDate.minute.toString().padLeft(2, '0')} ${transactionDate.hour >= 12 ? 'PM' : 'AM'}";

        return Material(
          color: context.surfaceColor,
          child: InkWell(
            onTap: () {
              if (hasInvoiceRef) {
                final List<InventoryItem> items = inventoryItems.map((map) {
                  return InventoryItem(
                    id: int.tryParse(map['id']?.toString() ?? '0') ?? 0,
                    invoiceDate: invoiceDate,
                    invoiceNumber: displayId,
                    vendorName: entityName,
                    partNumber: map['part_number']?.toString() ?? '',
                    description: map['description']?.toString() ?? '',
                    quantity: (map['quantity'] as num?)?.toDouble() ?? (map['qty'] as num?)?.toDouble() ?? 0.0,
                    rate: (map['rate'] as num?)?.toDouble() ?? 0.0,
                    netBill: (map['net_bill'] as num?)?.toDouble() ?? 0.0,
                    amountMismatch: (map['amount_mismatch'] as num?)?.toDouble() ?? 0.0,
                    receiptLink: receiptLink,
                    priceHikeAmount: (map['price_hike_amount'] as num?)?.toDouble(),
                    previousRate: (map['previous_rate'] as num?)?.toDouble(),
                  );
                }).toList();

                final bundle = InventoryInvoiceBundle(
                  invoiceNumber: displayId,
                  date: invoiceDate.isNotEmpty ? invoiceDate : transactionDate.toIso8601String(),
                  vendorName: entityName,
                  receiptLink: receiptLink,
                  items: items,
                  totalAmount: amount,
                  hasMismatch: items.any((i) => i.amountMismatch != 0),
                  isVerified: isVerified,
                  createdAt: transactionDate.toIso8601String(),
                  paymentMode: isPaid ? 'Cash' : 'Credit',
                );

                context.pushNamed('vendor-delivery-detail', extra: bundle);
                return;
              }

              final vendorState = ref.read(vendorLedgerProvider);
              VendorLedger? matched;
              try {
                matched = vendorState.ledgers.firstWhere(
                  (l) => l.vendorName.toLowerCase() == entityName.toLowerCase(),
                );
              } catch (_) {
                matched = VendorLedger(
                  id: -1,
                  vendorName: entityName,
                  balanceDue: balanceDue ?? 0.0,
                );
              }

              context.pushNamed(
                'vendor-ledger-detail',
                pathParameters: {'id': matched.id.toString()},
                extra: matched,
              );
            },
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.borderColor.withValues(alpha: 0.5), width: 1),
                  left: BorderSide(
                    color: hasDue ? context.errorColor : (isPaid ? context.successColor : context.textSecondaryColor.withValues(alpha: 0.5)),
                    width: 4,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entityName,
                                style: TextStyle(
                                  color: context.textColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  letterSpacing: -0.6,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'SUPPLIER',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$dateStr • $timeStr',
                                    style: TextStyle(
                                      color: context.textSecondaryColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
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
                            Text(
                              hasDue ? CurrencyFormatter.format(pendingAmount) : CurrencyFormatter.format(amount),
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              hasDue ? 'BALANCE' : 'PAID',
                              style: TextStyle(
                                color: context.textSecondaryColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (hasPriceHike) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: context.errorColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.errorColor.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.trending_up, size: 14, color: context.errorColor),
                            const SizedBox(width: 8),
                            Text(
                              'Price hike: ${CurrencyFormatter.format(totalPriceHike)} extra',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.errorColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              if (hasInvoiceRef) ...[
                                Icon(Icons.inventory_2_outlined, size: 14, color: context.textSecondaryColor),
                                const SizedBox(width: 4),
                                Text(
                                  '#$displayId',
                                  style: TextStyle(
                                    color: context.textColor.withValues(alpha: 0.7),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Text(
                                'BILL TOTAL: ${CurrencyFormatter.format(amount)}',
                                style: TextStyle(
                                  color: context.textSecondaryColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _StatusChip(label: badgeText, color: statusColor),
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
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
