import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/features/activities/domain/models/activity_item.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/shared/domain/models/invoice_group.dart';
import 'package:mobile/features/udhar/domain/models/udhar_models.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_provider.dart';
import 'package:mobile/features/verified/domain/models/verified_models.dart';

/// Renders a customer (receivable) transaction row.
/// Amounts are formatted with zero decimal digits per SnapKhata UI guidelines.
class CustomerActivityCard extends ConsumerWidget {
  const CustomerActivityCard({super.key, required this.item});

  /// The customer variant of [ActivityItem].
  final ActivityItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return item.maybeWhen(
      customer: (id, entityName, transactionDate, amount, displayId, transactionType, balanceDue, receiptLink, invoiceDate, mobileNumber, paymentMode, invoiceBalanceDue, receivedAmount, items, isVerified) {
        final isPayment = transactionType.toUpperCase() == 'PAYMENT';
        final hasInvoiceRef = displayId != null && displayId.isNotEmpty;
        
        // Use invoiceBalanceDue for the specific transaction balance
        final double currentBalance = invoiceBalanceDue;
        final hasDue = currentBalance > 0;
        
        // Fix for TOTAL: ₹0 bug - if amount is 0, sum received + balance
        final double billTotal = (amount > 0) ? amount : (receivedAmount + invoiceBalanceDue);
        
        final String badgeText = isPayment 
            ? 'GOT' 
            : (hasDue ? 'DUE' : 'SETTLED');
            
        // Date formatting: "Today 10:30 AM" style
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
              if (!isPayment && hasInvoiceRef) {
                final groupItems = items.map((e) => VerifiedInvoice.fromJson(e)).toList();
                final group = InvoiceGroup(
                  receiptNumber: displayId,
                  date: invoiceDate.isNotEmpty ? invoiceDate : transactionDate.toIso8601String(),
                  receiptLink: receiptLink,
                  customerName: entityName,
                  mobileNumber: mobileNumber,
                  uploadDate: invoiceDate.isNotEmpty ? invoiceDate : transactionDate.toIso8601String(),
                  paymentMode: paymentMode,
                  receivedAmount: receivedAmount,
                  balanceDue: invoiceBalanceDue,
                  customerDetails: entityName,
                  extraFields: const {},
                )
                  ..items = groupItems
                  ..totalAmount = billTotal;
                
                context.pushNamed('order-detail', extra: group);
                return;
              }

              final udharState = ref.read(udharProvider);
              CustomerLedger? matched;
              try {
                matched = udharState.ledgers.firstWhere(
                  (l) => l.customerName.toLowerCase() == entityName.toLowerCase(),
                );
              } catch (_) {
                matched = CustomerLedger(
                  id: -1,
                  customerName: entityName,
                  balanceDue: balanceDue ?? 0.0,
                );
              }
              
              context.pushNamed(
                'udhar-detail',
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
                    color: isPayment || !hasDue ? context.successColor : context.errorColor,
                    width: 4,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
                child: Column(
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
                                      color: context.primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'CUSTOMER',
                                      style: TextStyle(
                                        color: context.primaryColor,
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
                              isPayment 
                                  ? CurrencyFormatter.format(amount)
                                  : (hasDue ? CurrencyFormatter.format(currentBalance) : CurrencyFormatter.format(receivedAmount)),
                              style: TextStyle(
                                color: isPayment || !hasDue ? context.successColor : context.errorColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              isPayment 
                                  ? 'RECEIVED' 
                                  : (hasDue ? 'BALANCE' : 'PAID'),
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
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              if (hasInvoiceRef) ...[
                                Icon(Icons.receipt_long_outlined, size: 14, color: context.textSecondaryColor),
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
                              // Mobile number omitted to keep UI clean.
                              Text(
                                isPayment 
                                    ? 'MODE: $paymentMode'
                                    : 'BILL TOTAL: ${CurrencyFormatter.format(billTotal)}',
                                style: TextStyle(
                                  color: context.textSecondaryColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _TypeChip(
                          label: badgeText,
                          color: isPayment || !hasDue ? context.successColor : context.errorColor,
                        ),
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

/// Small pill chip for the transaction type label.
class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.color});
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
