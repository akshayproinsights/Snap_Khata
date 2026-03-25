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
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mobile/core/utils/whatsapp_utils.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/settings/presentation/providers/shop_provider.dart';

class UdharDetailPage extends ConsumerStatefulWidget {
  final CustomerLedger ledger;

  const UdharDetailPage({super.key, required this.ledger});

  @override
  ConsumerState<UdharDetailPage> createState() => _UdharDetailPageState();
}

class _UdharDetailPageState extends ConsumerState<UdharDetailPage> {
  final currencyFormatter =
      NumberFormat.currency(symbol: '₹', decimalDigits: 2, locale: 'en_IN');
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
      if (tx.transactionType == 'INVOICE' || tx.transactionType == 'MANUAL_CREDIT') {
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
        .where((tx) => tx.transactionType == 'INVOICE' || tx.transactionType == 'MANUAL_CREDIT')
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
                        color: Colors.grey.shade300,
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
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Balance Due:',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          currencyFormatter.format(widget.ledger.balanceDue),
                          style: TextStyle(
                            color: Colors.orange.shade800,
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
                                        content: Text('Failed to save payment.')),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
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
        vehicleNumber: first.vehicleNumber,
        mobileNumber: first.mobileNumber,
        uploadDate: first.uploadDate,
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (currentLedger.customerPhone != null &&
                      currentLedger.customerPhone!.isNotEmpty)
                    Text(
                      currentLedger.customerPhone!,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white70),
                    ),
                ],
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
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
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'TRANSACTIONS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
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
        backgroundColor: AppTheme.primary,
        icon: const Icon(LucideIcons.indianRupee, color: Colors.white),
        label: const Text(
          'Add Payment',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
      decoration: const BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Balance
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Column(
              children: [
                Text(
                  isPositive ? 'Pending Balance' : 'Overpaid',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  currencyFormatter.format(balance.abs()),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: isPositive ? Colors.white : Colors.greenAccent.shade200,
                  ),
                ),
                if (!isPositive)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                        color: Colors.orange.shade200,
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
                        color: Colors.greenAccent.shade200,
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
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
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
            backgroundColor: isPaid ? Colors.green.shade600 : Colors.orange.shade700,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark invoice as ${isPaid ? 'paid' : 'unpaid'}.'),
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
              icon: const Icon(LucideIcons.xCircle, color: Colors.orange, size: 18),
              label: const Text(
                'Mark as Unpaid',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            icon: const Icon(LucideIcons.checkCircle2, color: Colors.white, size: 20),
            label: const Text(
              'Mark as Paid',
              style: TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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

  Future<void> _sendWhatsAppReminder(LedgerTransaction tx) async {
    HapticFeedback.lightImpact();

    final authState = ref.read(authProvider);
    final usernameParam = authState.user?.username != null
        ? '&u=${authState.user!.username}'
        : '';
        
    final link = 'https://mydigientry.com/receipt.html?i=${tx.receiptNumber}$usernameParam';
    
    final customerNameMsg = widget.ledger.customerName.isNotEmpty && widget.ledger.customerName.toLowerCase() != 'unknown'
        ? widget.ledger.customerName
        : 'Customer';

    final shopProfile = ref.read(shopProvider);
    final shopName = shopProfile.name.isNotEmpty
        ? shopProfile.name
        : 'Our Shop';

    // Log shop name for debugging
    debugPrint('Udhar WhatsApp message - Shop name: "$shopName" (from shopProfile.name: "${shopProfile.name}")');
    debugPrint('Udhar WhatsApp message - Customer: $customerNameMsg, Balance: ${widget.ledger.balanceDue}');

    final pendingFmt = WhatsAppUtils.formatIndianCurrency(widget.ledger.balanceDue);
    
    final message = 'Hi $customerNameMsg,\n\n'
        'This is a gentle reminder from *$shopName* regarding your pending balance.\n\n'
        '⚠️ *Total Amount Due: $pendingFmt*\n\n'
        'Please find your invoice receipt for reference:\n$link\n\n'
        'Thank you for your business!';

    final phoneController = TextEditingController(text: widget.ledger.customerPhone ?? '');

    if (!context.mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send WhatsApp Reminder'),
        content: TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Customer Phone Number',
            prefixText: '+91 ',
            hintText: 'e.g. 9876543210',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, phoneController.text),
            child: const Text('Send Reminder'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final opened = await WhatsAppUtils.openWhatsAppChat(
        phone: result,
        message: message,
      );

      if (!context.mounted) return;

      if (!opened) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp. Please ensure it is installed.')),
        );
      }
    }
  }

  Widget _buildWhatsAppReminderButton(LedgerTransaction tx) {
    if (tx.transactionType != 'INVOICE' || tx.receiptNumber == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: OutlinedButton.icon(
        onPressed: () => _sendWhatsAppReminder(tx),
        icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 18),
        label: const Text('Send Reminder on WhatsApp', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.green.shade200),
          minimumSize: const Size(double.infinity, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(LedgerTransaction tx) {
    final isPayment = tx.transactionType == 'PAYMENT';
    final isInvoice = tx.transactionType == 'INVOICE';
    final canTap = isInvoice && tx.receiptNumber != null;

    final Color accentColor = isPayment ? AppTheme.success : Colors.orange.shade600;
    final Color bgColor = isPayment ? Colors.green.shade50 : Colors.orange.shade50;
    final IconData txIcon = isPayment ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight;
    final String txTitle = isPayment
        ? 'Payment Received'
        : 'Credit Invoice ${tx.receiptNumber ?? ''}';

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.fromLTRB(4, 8, 14, 8),
            childrenPadding: EdgeInsets.zero,
            title: Row(
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isInvoice && tx.isPaid)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Text(
                                'PAID',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isInvoice ? 'Invoice Date: ${dateFormatter.format(tx.createdAt.toLocal())}' : dateFormatter.format(tx.createdAt.toLocal()),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
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
              ],
            ),
            trailing: SizedBox(
               width: 80,
               child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${isPayment ? '-' : '+'} ${currencyFormatter.format(tx.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: accentColor,
                    ),
                  ),
                  Icon(
                    LucideIcons.chevronDown,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
            children: [
              if (isInvoice)
                 _buildMarkAsPaidButton(tx),
              if (canTap && !tx.isPaid)
                _buildWhatsAppReminderButton(tx),
              if (canTap)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: OutlinedButton.icon(
                      onPressed: () => _navigateToOrderDetails(tx),
                      icon: const Icon(LucideIcons.fileText, size: 16),
                      label: const Text('View Invoice Summary'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ),
            ],
          ),
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
