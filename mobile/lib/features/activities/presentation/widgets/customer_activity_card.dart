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
      customer: (id, entityName, transactionDate, amount, displayId, transactionType, balanceDue, receiptLink, invoiceDate, mobileNumber, paymentMode, invoiceBalanceDue, receivedAmount, items) {
        final initials = _initials(entityName);
        final isPayment = transactionType.toUpperCase() == 'PAYMENT';
        final hasInvoiceRef = displayId != null && displayId.isNotEmpty;
        
        final hasDue = balanceDue != null && balanceDue > 0;
        
        final String badgeText = isPayment 
            ? 'GOT' 
            : (hasDue ? 'DUE' : 'SETTLED');
            
        final Color badgeColor = isPayment 
            ? context.successColor 
            : (hasDue ? context.warningColor : context.successColor);

        return Material(
          color: context.surfaceColor,
          child: InkWell(
            onTap: () {
              // Open invoice details whenever this activity is an invoice entry.
              // Credit invoices can exist without a receipt link in some payloads.
              if (!isPayment && hasInvoiceRef) {
                final groupItems = items.map((e) => VerifiedInvoice.fromJson(e)).toList();
                final group = InvoiceGroup(
                  receiptNumber: displayId,
                  date: invoiceDate.isNotEmpty
                      ? invoiceDate
                      : transactionDate.toIso8601String(),
                  receiptLink: receiptLink,
                  customerName: entityName,
                  mobileNumber: mobileNumber,
                  uploadDate: invoiceDate.isNotEmpty
                      ? invoiceDate
                      : transactionDate.toIso8601String(),
                  paymentMode: paymentMode,
                  receivedAmount: receivedAmount,
                  balanceDue: invoiceBalanceDue,
                  customerDetails: entityName,
                  extraFields: const {},
                )
                  ..items = groupItems
                  ..totalAmount = amount;
                
                context.pushNamed('order-detail', extra: group);
                return;
              }

              // Fallback: open the credit ledger detail for this customer
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
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.borderColor.withValues(alpha: 0.5), width: 1),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    // ── Avatar ──────────────────────────────────────────────
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isPayment ? context.successColor.withValues(alpha: 0.12) : context.errorColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: isPayment ? context.successColor : context.errorColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // ── Entity name + date ───────────────────────────────────
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
                            'Customer',
                            style: TextStyle(
                              color: context.textSecondaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                        _TypeChip(
                          label: badgeText,
                          color: badgeColor,
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

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
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
