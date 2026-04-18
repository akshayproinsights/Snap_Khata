import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/shared/domain/models/invoice_group.dart';
import '../../verified/presentation/providers/verified_provider.dart';
import '../domain/models/udhar_models.dart';
import 'providers/udhar_provider.dart';


class UdharDetailPage extends ConsumerStatefulWidget {
  final CustomerLedger ledger;

  const UdharDetailPage({super.key, required this.ledger});

  @override
  ConsumerState<UdharDetailPage> createState() => _UdharDetailPageState();
}

class _UdharDetailPageState extends ConsumerState<UdharDetailPage> {
  final currencyFormatter =
      NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');
  final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');

  List<LedgerTransaction>? _transactions;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    final transactions = await ref
        .read(udharProvider.notifier)
        .fetchTransactions(widget.ledger.id);
    setState(() {
      _transactions = transactions;
      _isLoading = false;
    });
  }

  /// Compute balance from actual transactions: invoices add, payments subtract
  double get _computedBalance {
    if (_transactions == null || _transactions!.isEmpty) {
      return widget.ledger.balanceDue;
    }
    double balance = 0;
    for (final tx in _transactions!) {
      if (tx.transactionType == 'INVOICE' ||
          tx.transactionType == 'MANUAL_CREDIT') {
        balance += tx.amount;
      } else if (tx.transactionType == 'PAYMENT') {
        balance -= tx.amount;
      }
    }
    return balance;
  }

  double get _totalInvoiced {
    if (_transactions == null) return 0;
    return _transactions!
        .where((tx) =>
            tx.transactionType == 'INVOICE' ||
            tx.transactionType == 'MANUAL_CREDIT')
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  double get _totalPaid {
    if (_transactions == null) return 0;
    return _transactions!
        .where((tx) => tx.transactionType == 'PAYMENT')
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  void _showAddPaymentDialog(BuildContext context) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Receive Payment',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Balance Due:',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          currencyFormatter.format(widget.ledger.balanceDue),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount Received (₹)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(LucideIcons.indianRupee),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: 'Notes / Reference',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(LucideIcons.edit2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
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
                                  .read(udharProvider.notifier)
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
                                        content:
                                            Text('Failed to save payment.')),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isSubmitting
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Theme.of(context).colorScheme.onPrimary, strokeWidth: 2))
                          : const Text(
                              'Save Payment',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
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

  Future<void> _navigateToOrderDetails(LedgerTransaction tx) async {
    if (tx.receiptNumber == null) return;

    // Show a loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final repo = ref.read(verifiedRepositoryProvider);
      final records =
          await repo.getVerifiedInvoices(receiptNumber: tx.receiptNumber);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (records.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find order details.')),
        );
        return;
      }

      // Construct InvoiceGroup
      final first = records.first;
      final group = InvoiceGroup(
        receiptNumber: first.receiptNumber,
        date: first.date.isNotEmpty ? first.date : first.uploadDate,
        receiptLink: first.receiptLink,
        customerName: first.customerName,
        mobileNumber: first.mobileNumber,
        extraFields: first.extraFields,
        uploadDate: first.uploadDate,
        paymentMode: first.paymentMode,
        receivedAmount: first.receivedAmount,
        balanceDue: first.balanceDue,
        customerDetails: first.customerDetails,
      );
      group.items = records;
      group.totalAmount = records.fold(0, (sum, item) => sum + item.amount);

      if (mounted) {
        context.pushNamed('order-detail', extra: group);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(udharProvider);
    final currentLedger = state.ledgers.firstWhere(
        (l) => l.id == widget.ledger.id,
        orElse: () => widget.ledger);

    final initials = currentLedger.customerName.isNotEmpty
        ? currentLedger.customerName
            .trim()
            .split(' ')
            .take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .join()
        : 'C';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.25),
              child: Text(
                initials,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentLedger.customerName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (currentLedger.customerPhone != null &&
                      currentLedger.customerPhone!.isNotEmpty)
                    Text(
                      currentLedger.customerPhone!,
                      style:
                          TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)),
                    ),
                ],
              ),
            ),
          ],
        ),
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
      ),
      body: Column(
        children: [
          // Header with balance & stats
          _buildHeaderCard(currentLedger),

          // Section Label
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'TRANSACTIONS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          // Transactions List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _transactions == null || _transactions!.isEmpty
                    ? _buildEmptyState()
                    : Builder(builder: (context) {
                        final visibleTxs = _transactions!
                            .where((tx) => !(tx.transactionType == 'PAYMENT' &&
                                tx.linkedTransactionId != null))
                            .toList();
                        if (visibleTxs.isEmpty) return _buildEmptyState();
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                          itemCount: visibleTxs.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final tx = visibleTxs[index];
                            return _buildTransactionCard(tx);
                          },
                        );
                      }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPaymentDialog(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        icon: Icon(LucideIcons.indianRupee, color: Theme.of(context).colorScheme.onPrimary),
        label: Text(
          'Add Payment',
          style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeaderCard(CustomerLedger currentLedger) {
    final balance = _isLoading ? currentLedger.balanceDue : _computedBalance;
    final isPositive = balance >= 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Balance
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
            child: Column(
              children: [
                Text(
                  isPositive ? 'Pending Balance' : 'Overpaid',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currencyFormatter.format(balance.abs()),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color:
                        isPositive ? Theme.of(context).colorScheme.onPrimary : Colors.greenAccent.shade200,
                  ),
                ),
                if (!isPositive)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Customer has overpaid',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),

          // Stats Row
          if (!_isLoading) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        label: 'Total Billed',
                        value: currencyFormatter.format(_totalInvoiced),
                        color: Theme.of(context).colorScheme.onPrimary,
                        iconColor: Colors.orange.shade300,
                        icon: LucideIcons.fileText,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        label: 'Total Paid',
                        value: currencyFormatter.format(_totalPaid),
                        color: Theme.of(context).colorScheme.onPrimary,
                        iconColor: Colors.greenAccent.shade400,
                        icon: LucideIcons.checkCircle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    Color? iconColor,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor ?? color, size: 16),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7), fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Future<void> _togglePaidStatus(LedgerTransaction tx, bool isPaid) async {
    // Show loading indicator wrapper
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final success = await ref
        .read(udharProvider.notifier)
        .toggleTransactionPaidStatus(widget.ledger.id, tx.id, isPaid);

    if (mounted) {
      Navigator.pop(context); // Close dialog

      if (success) {
        _loadTransactions();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPaid
                  ? 'Invoice marked as Paid! 🎉'
                  : 'Invoice marked as Unpaid.',
            ),
            backgroundColor:
                isPaid ? Colors.green.shade600 : Colors.orange.shade700,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to mark invoice as ${isPaid ? 'paid' : 'unpaid'}.'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  Widget _buildMarkAsPaidButton(LedgerTransaction tx) {
    if (tx.isPaid) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () => _togglePaidStatus(tx, false),
              icon: const Icon(LucideIcons.xCircle,
                  color: Colors.orange, size: 18),
              label: const Text(
                'Mark as Unpaid',
                style: TextStyle(
                    color: Colors.orange, fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => _togglePaidStatus(tx, true),
            icon: const Icon(LucideIcons.checkCircle2,
                color: Colors.white, size: 20),
            label: const Text(
              'Mark as Paid',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      );
    }
  }


  Widget _buildTransactionCard(LedgerTransaction tx) {
    final isPayment = tx.transactionType == 'PAYMENT';
    final isInvoice = tx.transactionType == 'INVOICE';
    final canTap = isInvoice && tx.receiptNumber != null;

    final Color accentColor =
        isPayment ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error;
    final Color bgColor =
        isPayment ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Theme.of(context).colorScheme.error.withValues(alpha: 0.1);
    final IconData txIcon =
        isPayment ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight;
    final String txTitle = isPayment
        ? 'Payment Received'
        : 'Credit Invoice ${tx.receiptNumber ?? ''}';

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 14, 8),
              child: Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(txIcon, color: accentColor, size: 18),
                  ),
                  const SizedBox(width: 12),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                txTitle,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isInvoice && tx.isPaid)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border:
                                      Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                                ),
                                child: Text(
                                  'PAID',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isInvoice
                              ? 'Invoice Date: ${dateFormatter.format(tx.createdAt.toLocal())}'
                              : dateFormatter.format(tx.createdAt.toLocal()),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (tx.notes != null && tx.notes!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            tx.notes!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Trailing items
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 70,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${isPayment ? '-' : '+'} ${currencyFormatter.format(tx.amount)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (canTap) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(LucideIcons.receipt,
                              color: AppTheme.textSecondary, size: 24),
                          onPressed: () => _navigateToOrderDetails(tx),
                          tooltip: 'View Invoice Summary',
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isInvoice) _buildMarkAsPaidButton(tx),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.fileText, size: 52, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Transactions will appear here once\nan invoice or payment is recorded.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
