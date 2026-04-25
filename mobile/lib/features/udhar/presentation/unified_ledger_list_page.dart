import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/udhar/domain/models/unified_ledger.dart';
import 'package:mobile/features/udhar/presentation/providers/unified_ledger_provider.dart';
import 'package:mobile/features/udhar/presentation/udhar_detail_page.dart';
import 'package:mobile/features/inventory/presentation/vendor_ledger/vendor_ledger_detail_page.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:lucide_icons/lucide_icons.dart';

class UnifiedLedgerListPage extends ConsumerWidget {
  const UnifiedLedgerListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgers = ref.watch(unifiedLedgerProvider);

    if (ledgers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.users, size: 64, color: context.borderColor),
            const SizedBox(height: 16),
            Text(
              'No parties found',
              style: TextStyle(
                color: context.textSecondaryColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: ledgers.length,
      itemBuilder: (context, index) {
        final ledger = ledgers[index];
        return _buildLedgerCard(context, ledger);
      },
    );
  }

  Widget _buildLedgerCard(BuildContext context, UnifiedLedger ledger) {
    final bool isCustomer = ledger.type == LedgerType.customer;
    final bool isDue = ledger.balanceDue > 0;
    
    // Stitch design: green (#1b6d24) for collecting (customers due), red for paying (suppliers due)
    final Color amountColor = isCustomer 
        ? (isDue ? context.successColor : context.textColor)
        : (isDue ? context.errorColor : context.textColor);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: context.borderColor.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (isCustomer) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UdharDetailPage(ledger: ledger.originalLedger),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VendorLedgerDetailPage(ledger: ledger.originalLedger),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isCustomer 
                    ? context.primaryColor.withValues(alpha: 0.1) 
                    : context.primaryColor.withValues(alpha: 0.05),
                child: Text(
                  ledger.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: isCustomer 
                        ? context.primaryColor
                        : context.textSecondaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ledger.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ledger.lastActivityDate != null
                          ? timeago.format(ledger.lastActivityDate!)
                          : 'No activity',
                      style: TextStyle(
                        color: context.textSecondaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(ledger.balanceDue),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isCustomer ? (isDue ? 'To Collect' : 'Settled') : (isDue ? 'To Pay' : 'Settled'),
                    style: TextStyle(
                      color: context.textSecondaryColor,
                      fontSize: 11,
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
}
