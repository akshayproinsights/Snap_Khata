import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import '../../domain/models/vendor_ledger_models.dart';
import '../providers/vendor_ledger_provider.dart';

class VendorLedgerDetailPage extends ConsumerStatefulWidget {
  final VendorLedger ledger;

  const VendorLedgerDetailPage({super.key, required this.ledger});

  @override
  ConsumerState<VendorLedgerDetailPage> createState() =>
      _VendorLedgerDetailPageState();
}

class _VendorLedgerDetailPageState
    extends ConsumerState<VendorLedgerDetailPage> {
  final currencyFormatter =
      NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');
  final dateFormatter = DateFormat('dd MMM yyyy');

  List<VendorLedgerTransaction>? _transactions;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    final transactions = await ref
        .read(vendorLedgerProvider.notifier)
        .fetchTransactions(widget.ledger.id);
    
    // Ensure descending date order
    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    setState(() {
      _transactions = transactions;
      _isLoading = false;
    });
  }

  void _showAddPaymentDialog(BuildContext context) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Record Payment',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Current Balance:',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          currencyFormatter.format(widget.ledger.balanceDue),
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount Paid (₹)',
                      prefixIcon: Icon(LucideIcons.indianRupee, size: 18),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes / Reference',
                      prefixIcon: Icon(LucideIcons.edit2, size: 18),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final amount =
                                double.tryParse(amountController.text) ?? 0;
                            if (amount <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Please enter a valid amount')),
                              );
                              return;
                            }

                            setModalState(() => isSubmitting = true);
                            final success = await ref
                                .read(vendorLedgerProvider.notifier)
                                .recordPayment(widget.ledger.id, amount,
                                    notesController.text);

                            if (success && context.mounted) {
                              Navigator.pop(context);
                              _loadTransactions();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Payment recorded! 🎉')),
                              );
                            } else {
                              setModalState(() => isSubmitting = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Failed to save payment.')),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text(
                            'Save Payment',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vendorLedgerProvider);
    final currentLedger = state.ledgers.firstWhere(
        (l) => l.id == widget.ledger.id,
        orElse: () => widget.ledger);

    // Calculate aggregated stats from available transactions
    // Hide auto-generated payments by filtering out those with a linkedTransactionId
    final txList = _transactions?.where((tx) => tx.linkedTransactionId == null).toList() ?? [];
    double totalSpend = 0;
    int ordersCount = 0;
    DateTime? lastOrderDate;
    
    for (var tx in txList) {
      if (tx.transactionType != 'PAYMENT') {
        totalSpend += tx.amount;
        ordersCount++;
        if (lastOrderDate == null || tx.createdAt.isAfter(lastOrderDate)) {
          lastOrderDate = tx.createdAt;
        }
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.moreVertical),
            onPressed: () {},
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Profile
            Text(
              currentLedger.vendorName,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.checkCircle2, 
                       size: 14, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Verified Supplier',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // Metrics Grid (Stitch AI Layout)
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.8,
              children: [
                _buildMetricCard(
                  'Total Spend', 
                  currencyFormatter.format(totalSpend > 0 ? totalSpend : currentLedger.balanceDue)
                ),
                _buildMetricCard('Orders', '$ordersCount'),
                _buildMetricCard('Pending Due', currencyFormatter.format(currentLedger.balanceDue)),
                _buildMetricCard(
                  'Last Order', 
                  lastOrderDate != null ? dateFormatter.format(lastOrderDate) : 'N/A'
                ),
              ],
            ),


            // Transactions Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Transactions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () => _showAddPaymentDialog(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(LucideIcons.indianRupee, size: 14),
                      SizedBox(width: 6),
                      Text('Pay', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 16),

            // Transactions List
            _isLoading
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ))
                : txList.isEmpty
                    ? const Center(
                        child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text('No transactions found',
                            style: TextStyle(color: AppTheme.textSecondary)),
                      ))
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: txList.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final tx = txList[index];
                          final isPayment = tx.transactionType == 'PAYMENT';
                          return _buildTransactionCard(tx, isPayment);
                        },
                      ),
            
            const SizedBox(height: 48), // Padding bottom
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTransactionCard(VendorLedgerTransaction tx, bool isPayment) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: EdgeInsets.zero,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isPayment ? Colors.green.shade50 : AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPayment ? LucideIcons.arrowUpRight : LucideIcons.receipt,
                  color: isPayment ? Colors.green.shade600 : AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isPayment
                                ? 'Payment Sent'
                                : (tx.invoiceNumber?.isNotEmpty == true ? '#${tx.invoiceNumber}' : 'Purchase Order'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isPayment && tx.isPaid) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Text(
                              'PAID',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateFormatter.format(tx.createdAt.toLocal()),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isPayment ? '-' : '+'} ${currencyFormatter.format(tx.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isPayment ? Colors.green.shade600 : AppTheme.textPrimary,
                    ),
                  ),
                  if (tx.notes?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        tx.notes!,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          children: [
            if (!isPayment)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(height: 1, color: AppTheme.border),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Invoice Date', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            const SizedBox(height: 4),
                            Text(dateFormatter.format(tx.createdAt.toLocal()), style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          ],
                        ),
                        _buildMarkAsPaidButton(tx),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkAsPaidButton(VendorLedgerTransaction tx) {
    if (tx.isPaid) {
      return TextButton.icon(
        onPressed: () => _togglePaidStatus(tx, false),
        icon: Icon(LucideIcons.xCircle, size: 16, color: Colors.red.shade600),
        label: Text('Mark as Unpaid', style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.bold)),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: () => _togglePaidStatus(tx, true),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(LucideIcons.checkCircle, size: 16),
        label: const Text('Mark as Paid', style: TextStyle(fontWeight: FontWeight.bold)),
      );
    }
  }

  Future<void> _togglePaidStatus(VendorLedgerTransaction tx, bool markAsPaid) async {
    final success = await ref.read(vendorLedgerProvider.notifier).toggleTransactionPaidStatus(tx.id, markAsPaid);
    if (success) {
      _loadTransactions();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update status')));
      }
    }
  }
}
