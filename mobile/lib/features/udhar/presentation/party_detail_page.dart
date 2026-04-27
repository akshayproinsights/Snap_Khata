import "package:mobile/core/theme/context_extension.dart";
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/shared/domain/models/invoice_group.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import '../../verified/presentation/providers/verified_provider.dart';
import '../domain/models/udhar_models.dart';
import 'providers/udhar_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mobile/core/utils/whatsapp_utils.dart';
import 'package:mobile/features/settings/presentation/providers/shop_provider.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class PartyDetailPage extends ConsumerStatefulWidget {
  final CustomerLedger ledger;

  const PartyDetailPage({super.key, required this.ledger});

  @override
  ConsumerState<PartyDetailPage> createState() => _PartyDetailPageState();
}

class _PartyDetailPageState extends ConsumerState<PartyDetailPage> {
  final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');

  List<LedgerTransaction>? _transactions;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final transactions = await ref
        .read(udharProvider.notifier)
        .fetchTransactions(widget.ledger.id);
    if (!mounted) return;
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
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Record Payment',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.primaryColor.withValues(alpha: 0.2), width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Balance Due:',
                          style: TextStyle(
                              color: context.textSecondaryColor,
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          CurrencyFormatter.format(_computedBalance),
                          style: TextStyle(
                            color: context.primaryColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
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
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                    decoration: InputDecoration(
                      labelText: 'Amount Received',
                      labelStyle: TextStyle(color: context.textSecondaryColor),
                      prefixIcon: Icon(LucideIcons.indianRupee, color: context.primaryColor),
                      filled: true,
                      fillColor: context.textSecondaryColor.withValues(alpha: 0.03),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: 'Notes (Optional)',
                      labelStyle: TextStyle(color: context.textSecondaryColor),
                      prefixIcon: Icon(LucideIcons.edit3, color: context.textSecondaryColor),
                      filled: true,
                      fillColor: context.textSecondaryColor.withValues(alpha: 0.03),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
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
                                ref.invalidate(verifiedProvider);
                                ref.invalidate(dashboardTotalsProvider);
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
                        backgroundColor: context.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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
                                  fontSize: 18, fontWeight: FontWeight.w800),
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
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _showReceiptPhotoDialog(LedgerTransaction tx) async {
    if (tx.receiptNumber == null && tx.receiptLink == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    const Icon(LucideIcons.receipt, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Invoice #${tx.receiptNumber ?? "N/A"}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12),
              Expanded(
                child: tx.receiptLink != null && tx.receiptLink!.isNotEmpty && tx.receiptLink != 'null'
                  ? _buildImageWidget(tx.receiptLink!, scrollController)
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.imageOff, color: Colors.white.withValues(alpha: 0.2), size: 64),
                          const SizedBox(height: 16),
                          const Text(
                            'No receipt photo available',
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageWidget(String url, ScrollController scrollController) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: InteractiveViewer(
        maxScale: 5.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            width: double.infinity,
            placeholder: (context, url) => Container(
              height: 400,
              color: Colors.white.withValues(alpha: 0.05),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: 200,
              color: Colors.white.withValues(alpha: 0.05),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.alertTriangle, color: Colors.orange, size: 48),
                  SizedBox(height: 12),
                  Text('Could not load image', style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentLedger.customerName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (currentLedger.customerPhone != null &&
                      currentLedger.customerPhone!.isNotEmpty)
                    Text(
                      currentLedger.customerPhone!,
                      style: TextStyle(
                        fontSize: 12, 
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 20),
            tooltip: 'Send Reminder',
            onPressed: () => _sendWhatsAppReminder(context, ref, currentLedger),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildHeaderCard(currentLedger),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: context.primaryColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'TRANSACTION HISTORY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: context.textSecondaryColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                if (_transactions != null && _transactions!.isNotEmpty)
                  Text(
                    '${_transactions!.length} Entries',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondaryColor.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),

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
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                          itemCount: visibleTxs.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final tx = visibleTxs[index];
                            return _buildTransactionCard(tx);
                          },
                        );
                      }),
          ),
        ],
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddPaymentDialog(context),
          backgroundColor: context.primaryColor,
          elevation: 8,
          icon: const Icon(LucideIcons.indianRupee, color: Colors.white, size: 20),
          label: const Text(
            'RECORD PAYMENT',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.0),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        color: context.primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        boxShadow: [
          BoxShadow(
            color: context.primaryColor.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    isPositive ? 'TOTAL BALANCE DUE' : 'OVERPAID AMOUNT',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '₹',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: isPositive ? Colors.white : Colors.greenAccent.shade200,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        NumberFormat('#,##,###.##').format(balance.abs()),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: isPositive ? Colors.white : Colors.greenAccent.shade200,
                          letterSpacing: -2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: _buildHeaderStat(
                          label: 'TOTAL BILLED',
                          value: CurrencyFormatter.format(_totalInvoiced),
                          icon: LucideIcons.fileText,
                        ),
                      ),
                      Container(
                        width: 1.5,
                        height: 36,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      Expanded(
                        child: _buildHeaderStat(
                          label: 'TOTAL PAID',
                          value: CurrencyFormatter.format(_totalPaid),
                          icon: LucideIcons.checkCircle2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 14),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Future<void> _sendWhatsAppReminder(BuildContext context, WidgetRef ref, CustomerLedger ledger) async {
    HapticFeedback.lightImpact();

    final customerNameMsg = ledger.customerName.isNotEmpty &&
            ledger.customerName.toLowerCase() != 'unknown'
        ? ledger.customerName
        : 'Customer';

    final shopProfile = ref.read(shopProvider);
    final shopName = shopProfile.name.isNotEmpty ? shopProfile.name : 'Our Shop';
    final pendingFmt = CurrencyFormatter.format(ledger.balanceDue);

    String message = 'Hi $customerNameMsg,\n\n'
        'This is a gentle reminder from *${shopName.trim()}* regarding your pending balance.\n\n'
        '⚠️ *Total Amount Due: $pendingFmt*\n\n';

    if (shopProfile.upiId.isNotEmpty) {
      final upiLink = 'upi://pay?pa=${shopProfile.upiId}&pn=${Uri.encodeComponent(shopName)}&am=${ledger.balanceDue.toStringAsFixed(2)}&cu=INR';
      message += '💳 *Pay via UPI:* ${shopProfile.upiId}\n'
                '🔗 *Payment Link:* $upiLink\n\n';
    }

    final authState = ref.read(authProvider);
    final usernameParam = authState.user?.username != null
        ? '&u=${Uri.encodeComponent(authState.user!.username)}'
        : '';
    final statementLink = 'https://snapkhata.com/receipt.html?party=${ledger.id}$usernameParam';
    message += '📋 *View your account statement:*\n$statementLink\n\n';
    message += 'Thank you for your business!\n— *${shopName.trim()}*';

    await WhatsAppUtils.shareReceipt(
      context,
      phone: ledger.customerPhone ?? '',
      message: message,
      dialogTitle: 'Send Reminder',
      dialogContent: 'Send a payment reminder statement to ${ledger.customerName} via WhatsApp.',
    );
  }

  Future<void> _togglePaidStatus(LedgerTransaction tx, bool isPaid) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final success = await ref
        .read(udharProvider.notifier)
        .toggleTransactionPaidStatus(widget.ledger.id, tx.id, isPaid);

    if (mounted) {
      Navigator.pop(context);

      if (success) {
        ref.invalidate(verifiedProvider);
        ref.invalidate(dashboardTotalsProvider);
        _loadTransactions();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPaid
                  ? 'Invoice marked as Paid! 🎉'
                  : 'Invoice marked as Unpaid.',
            ),
            backgroundColor:
                isPaid ? context.successColor : context.warningColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to update status.'),
            backgroundColor: context.errorColor,
          ),
        );
      }
    }
  }

  Widget _buildTransactionCard(LedgerTransaction tx) {
    final isPayment = tx.transactionType == 'PAYMENT';
    final isInvoice = tx.transactionType == 'INVOICE' || tx.transactionType == 'MANUAL_CREDIT';
    final canTap = isInvoice && (tx.receiptNumber != null || tx.receiptLink != null);

    final Color accentColor = isPayment ? context.successColor : context.errorColor;
    final Color bgColor = accentColor.withValues(alpha: 0.08);
    
    final IconData txIcon = isPayment ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight;
    final String txTitle = isPayment ? 'Payment Received' : 'Credit Sale';

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: context.premiumShadow,
        border: Border.all(color: context.borderColor.withValues(alpha: 0.5), width: 1),
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
                              '${isPayment ? '-' : '+'} ${CurrencyFormatter.format(tx.amount)}',
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
                            Icon(LucideIcons.calendar, size: 12, color: context.textSecondaryColor),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('dd MMM yyyy • hh:mm a').format(tx.createdAt.toLocal()),
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: context.textSecondaryColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.messageSquare, size: 10, color: context.textSecondaryColor),
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
          
          // User Clarity Row: Bill, Paid, Balance
          if (isInvoice)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: context.textSecondaryColor.withValues(alpha: 0.03),
                border: Border(top: BorderSide(color: context.borderColor, width: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildClarityItem('Bill Amount', CurrencyFormatter.format(tx.amount)),
                  _buildClarityItem(
                    'Paid', 
                    CurrencyFormatter.format(tx.amount - (tx.balanceDue ?? (tx.isPaid ? 0 : tx.amount)))
                  ),
                  _buildClarityItem(
                    'Balance', 
                    CurrencyFormatter.format(tx.balanceDue ?? (tx.isPaid ? 0 : tx.amount)),
                    valueColor: (tx.balanceDue ?? (tx.isPaid ? 0 : tx.amount)) <= 0 
                        ? context.successColor 
                        : context.errorColor,
                  ),
                ],
              ),
            ),

          // Actions Row
          if (isInvoice || canTap)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                border: Border(top: BorderSide(color: context.borderColor, width: 0.5)),
              ),
              child: Row(
                children: [
                  if (tx.receiptNumber != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '#${tx.receiptNumber}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: context.textSecondaryColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (canTap)
                    TextButton.icon(
                      onPressed: () => _showReceiptPhotoDialog(tx),
                      icon: const Icon(LucideIcons.eye, size: 14),
                      label: const Text('VIEW BILL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: context.primaryColor,
                      ),
                    ),
                  if (isInvoice)
                    TextButton.icon(
                      onPressed: () => _togglePaidStatus(tx, !tx.isPaid),
                      icon: Icon(tx.isPaid ? LucideIcons.xCircle : LucideIcons.checkCircle2, size: 14),
                      label: Text(
                        tx.isPaid ? 'MARK UNPAID' : 'MARK PAID', 
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: tx.isPaid ? context.warningColor : context.successColor,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClarityItem(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: context.textSecondaryColor.withValues(alpha: 0.6),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: valueColor ?? context.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              shape: BoxShape.circle,
              boxShadow: context.premiumShadow,
            ),
            child: Icon(LucideIcons.fileText, size: 48, color: context.borderColor),
          ),
          const SizedBox(height: 24),
          Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: context.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Transactions will appear here once\nan invoice or payment is recorded.',
            style: TextStyle(
              fontSize: 14, 
              color: context.textSecondaryColor,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
