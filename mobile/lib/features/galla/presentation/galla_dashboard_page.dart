import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/context_extension.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/galla/presentation/providers/galla_provider.dart';

class GallaDashboardPage extends ConsumerWidget {
  const GallaDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gallaState = ref.watch(gallaProvider);
    final transactions = gallaState.transactions;
    
    // Calculate total cash in hand from transactions
    double cashInHand = 0.0;
    for (final tx in transactions) {
      if (tx.transactionType == 'CASH_SALE' || tx.transactionType == 'MONEY_IN') {
        cashInHand += tx.amount;
      } else if (tx.transactionType == 'MONEY_OUT') {
        cashInHand -= tx.amount;
      }
    }

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: const Text('Galla (Cash Box)'),
        backgroundColor: context.surfaceColor,
        elevation: 0,
      ),
      body: gallaState.isLoading && transactions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.primaryColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: context.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.wallet, color: Colors.white.withValues(alpha: 0.8), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'CASH IN HAND',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        CurrencyFormatter.format(cashInHand),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Transaction List Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'RECENT TRANSACTIONS',
                        style: TextStyle(
                          color: context.textSecondaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Transactions
                Expanded(
                  child: transactions.isEmpty
                      ? Center(
                          child: Text(
                            'No cash transactions yet.',
                            style: TextStyle(color: context.textSecondaryColor),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: transactions.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final tx = transactions[index];
                            final isMoneyIn = tx.transactionType == 'CASH_SALE' || tx.transactionType == 'MONEY_IN';
                            
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isMoneyIn 
                                      ? context.successColor.withValues(alpha: 0.1) 
                                      : context.errorColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isMoneyIn ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
                                  color: isMoneyIn ? context.successColor : context.errorColor,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                tx.transactionType == 'CASH_SALE' ? 'Cash Sale' : 
                                tx.transactionType == 'MONEY_IN' ? 'Money In' : 'Money Out',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: tx.notes != null && tx.notes!.isNotEmpty
                                  ? Text(tx.notes!, maxLines: 1, overflow: TextOverflow.ellipsis)
                                  : tx.receiptNumber != null
                                      ? Text('Receipt: ${tx.receiptNumber}')
                                      : null,
                              trailing: Text(
                                '${isMoneyIn ? "+" : "-"}${CurrencyFormatter.format(tx.amount)}',
                                style: TextStyle(
                                  color: isMoneyIn ? context.successColor : context.errorColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'money_out_btn',
            backgroundColor: context.errorColor,
            onPressed: () => _showAddTransactionDialog(context, ref, 'MONEY_OUT'),
            icon: const Icon(LucideIcons.minus),
            label: const Text('OUT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            heroTag: 'money_in_btn',
            backgroundColor: context.successColor,
            onPressed: () => _showAddTransactionDialog(context, ref, 'MONEY_IN'),
            icon: const Icon(LucideIcons.plus),
            label: const Text('IN', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddTransactionDialog(BuildContext context, WidgetRef ref, String type) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(type == 'MONEY_IN' ? 'Money In' : 'Money Out'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: context.textSecondaryColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: type == 'MONEY_IN' ? context.successColor : context.errorColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0.0;
              if (amount > 0) {
                Navigator.pop(context);
                await ref.read(gallaProvider.notifier).addTransaction(type, amount, notesController.text);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
