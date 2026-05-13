import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/context_extension.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/galla/presentation/providers/galla_provider.dart';
import 'package:mobile/features/galla/domain/models/galla_transaction.dart';
import 'package:mobile/features/shared/domain/models/invoice_group.dart';
import 'package:mobile/features/verified/presentation/providers/verified_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class GallaDashboardPage extends ConsumerStatefulWidget {
  const GallaDashboardPage({super.key});

  @override
  ConsumerState<GallaDashboardPage> createState() => _GallaDashboardPageState();
}

class _GallaDashboardPageState extends ConsumerState<GallaDashboardPage> {
  
  Future<void> _navigateToOrderDetails(GallaTransaction tx) async {
    if (tx.receiptNumber == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final repo = ref.read(verifiedRepositoryProvider);
      final records = await repo.getVerifiedInvoices(
        receiptNumber: tx.receiptNumber,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (records.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find order details.')),
        );
        return;
      }

      final first = records.first;
      
      final group = InvoiceGroup(
        receiptNumber: first.receiptNumber,
        date: first.date.isNotEmpty ? first.date : first.uploadDate,
        receiptLink: first.receiptLink,
        customerName: first.customerName,
        mobileNumber: first.mobileNumber.replaceAll(RegExp(r'\.0$'), ''),
        extraFields: first.extraFields,
        uploadDate: first.uploadDate,
        paymentMode: tx.paymentMode ?? first.paymentMode,
        receivedAmount: tx.receivedAmount ?? first.receivedAmount,
        balanceDue: tx.balanceDue ?? first.balanceDue,
        customerDetails: first.customerDetails,
      );
      group.items = records;
      group.totalAmount = tx.amount;

      if (mounted) {
        await context.pushNamed('order-detail', extra: group);
        if (mounted) {
          ref.read(gallaProvider.notifier).fetchTransactions();
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildTransactionCard(GallaTransaction tx) {
    final isMoneyIn = tx.transactionType == 'CASH_SALE' || tx.transactionType == 'MONEY_IN';
    final canTap = tx.receiptNumber != null;

    final Color accentColor = isMoneyIn
        ? context.successColor
        : context.errorColor;
    final Color bgColor = accentColor.withValues(alpha: 0.08);

    final IconData txIcon = isMoneyIn
        ? LucideIcons.arrowDownLeft
        : LucideIcons.arrowUpRight;
        
    final String txTitle = tx.transactionType == 'CASH_SALE' 
        ? 'Cash Sale' 
        : tx.transactionType == 'MONEY_IN' ? 'Money In' : 'Money Out';

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: context.premiumShadow,
          border: Border.all(
            color: context.borderColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              onTap: canTap ? () => _navigateToOrderDetails(tx) : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(txIcon, color: accentColor, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                txTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                '${isMoneyIn ? '+' : '-'} ${CurrencyFormatter.format(tx.amount)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: accentColor,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                LucideIcons.calendar,
                                size: 12,
                                color: context.textSecondaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                tx.invoiceDate != null && tx.invoiceDate!.isNotEmpty 
                                  ? DateFormat('dd MMM yyyy').format(DateTime.tryParse(tx.invoiceDate!) ?? DateTime.tryParse(tx.createdAt) ?? DateTime.now())
                                  : DateFormat('dd MMM yyyy').format(DateTime.tryParse(tx.createdAt) ?? DateTime.now()),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.textSecondaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (tx.notes != null && tx.notes!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: context.textSecondaryColor.withValues(
                                  alpha: 0.05,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.messageSquare,
                                    size: 10,
                                    color: context.textSecondaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      tx.notes!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: context.textSecondaryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
  
            if (tx.customerName != null && tx.customerName!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: context.textSecondaryColor.withValues(alpha: 0.03),
                  border: Border(
                    top: BorderSide(color: context.borderColor, width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customer',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: context.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tx.customerName!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.textColor,
                          ),
                        ),
                      ],
                    ),
                    if (tx.receiptNumber != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Receipt No.',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: context.textSecondaryColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '#${tx.receiptNumber}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.textColor,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              
            if ((tx.customerName == null || tx.customerName!.isEmpty) && tx.receiptNumber != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  border: Border(
                    top: BorderSide(color: context.borderColor, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '#${tx.receiptNumber}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: context.textSecondaryColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                
                Expanded(
                  child: transactions.isEmpty
                      ? Center(
                          child: Text(
                            'No cash transactions yet.',
                            style: TextStyle(color: context.textSecondaryColor),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: transactions.length,
                          itemBuilder: (context, index) {
                            return _buildTransactionCard(transactions[index]);
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
    final isMoneyIn = type == 'MONEY_IN';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
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
                  const SizedBox(width: 12),
                  Text(
                    isMoneyIn ? 'Add Cash (Money In)' : 'Remove Cash (Money Out)',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                  prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text) ?? 0.0;
                    if (amount <= 0) return;
                    
                    final success = await ref.read(gallaProvider.notifier).addTransaction(
                      type,
                      amount,
                      notesController.text,
                    );
                    
                    if (success && context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Transaction added')),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: isMoneyIn ? context.successColor : context.errorColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Save Transaction', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
