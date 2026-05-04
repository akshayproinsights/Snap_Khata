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
  Map<String, double> _backendSummary = {'total_billed': 0, 'total_paid': 0, 'balance_due': 0};

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final (transactions, summary) = await ref
        .read(udharProvider.notifier)
        .fetchLedgerWithTransactions(widget.ledger.id);
    if (!mounted) return;
    setState(() {
      _transactions = transactions;
      _backendSummary = summary;
      _isLoading = false;
    });
  }

  /// Returns the authoritative balance: prefers backend-computed value (which accounts
  /// for all transactions including linked initial payments) and only falls back to
  /// summing local transactions if the backend summary hasn't loaded yet.
  double get _computedBalance {
    // Primary: server-computed balance_due = final_billed - final_paid
    // This is authoritative because grand_total is now derived from item amounts, not stale DB fields.
    final backendVal = _backendSummary['balance_due'] ?? 0.0;
    if (!_isLoading && _transactions != null) return backendVal;
    // Fallback during initial load: iterate all transactions
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
    // Use backend-computed value if available (avoids local recalculation drift)
    final backendVal = _backendSummary['total_billed'] ?? 0.0;
    if (backendVal > 0) return backendVal;
    if (_transactions == null) return 0;
    return _transactions!
        .where((tx) =>
            tx.transactionType == 'INVOICE' ||
            tx.transactionType == 'MANUAL_CREDIT')
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  double get _totalPaid {
    // Use backend-computed value — avoids double-counting where an invoice's
    // receivedAmount (from verified_invoices) would be counted again here.
    final backendVal = _backendSummary['total_paid'] ?? 0.0;
    if (backendVal > 0) return backendVal;
    if (_transactions == null) return 0;
    // Fallback: only count PAYMENT rows that are standalone (not linked to an invoice
    // whose receivedAmount is already shown in the invoice clarity row).
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
                    '${_transactions!.where((tx) => !(tx.transactionType == 'PAYMENT' && tx.linkedTransactionId != null)).length} Entries',
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
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          border: Border(top: BorderSide(color: context.borderColor.withValues(alpha: 0.5), width: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 16),
                label: const Text('REMIND', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  side: const BorderSide(color: Color(0xFF25D366), width: 1.5),
                  foregroundColor: const Color(0xFF25D366),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _showWhatsAppReminderSheet(context, ref, currentLedger),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                icon: const Icon(LucideIcons.indianRupee, size: 18, color: Colors.white),
                label: const Text('RECORD PAYMENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primaryColor,
                  minimumSize: const Size(0, 52),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _showAddPaymentDialog(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(CustomerLedger currentLedger) {
    final balance = _isLoading ? currentLedger.balanceDue : _computedBalance;
    final isPositive = balance > 0.01;
    final isNegative = balance < -0.01;

    String headerLabel = 'TOTAL BALANCE DUE';
    if (isNegative) headerLabel = 'ADVANCE';
    if (!isPositive && !isNegative) headerLabel = 'SETTLED';

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
                    headerLabel,
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

  void _showWhatsAppReminderSheet(BuildContext context, WidgetRef ref, CustomerLedger ledger) {
    HapticFeedback.lightImpact();

    final shopProfile = ref.read(shopProvider);
    final authState = ref.read(authProvider);
    final shopName = shopProfile.name.isNotEmpty ? shopProfile.name : 'Our Shop';
    final upiId = shopProfile.upiId.isNotEmpty ? shopProfile.upiId : null;
    final usernameParam = authState.user?.username != null
        ? '&u=${Uri.encodeComponent(authState.user!.username)}'
        : '';
    final statementLink = 'https://snapkhata.com/receipt.html?party=${ledger.id}$usernameParam';

    // Collect invoices that have a receipt photo
    final invoicesWithPhotos = (_transactions ?? [])
        .where((tx) =>
            (tx.transactionType == 'INVOICE' || tx.transactionType == 'MANUAL_CREDIT') &&
            tx.receiptLink != null &&
            tx.receiptLink!.isNotEmpty &&
            tx.receiptLink != 'null')
        .toList();

    final phoneController = TextEditingController(text: ledger.customerPhone ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool useReceiptPhoto = false;
        LedgerTransaction? selectedTx =
            invoicesWithPhotos.isNotEmpty ? invoicesWithPhotos.first : null;

        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final message = WhatsAppUtils.buildPartyReminderMessage(
              customerName: ledger.customerName.isNotEmpty ? ledger.customerName : 'Customer',
              shopName: shopName,
              totalBilled: _totalInvoiced,
              totalPaid: _totalPaid,
              balanceDue: _computedBalance,
              statementLink: statementLink,
              upiId: upiId,
              useReceiptPhoto: useReceiptPhoto,
              receiptPhotoUrl: selectedTx?.receiptLink,
              receiptNumber: selectedTx?.receiptNumber?.toString(),
            );

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.85,
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Scrollable body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF25D366).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366), size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Send Payment Reminder',
                                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                                    Text(ledger.customerName,
                                        style: TextStyle(fontSize: 13, color: context.textSecondaryColor, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(LucideIcons.x, color: context.textSecondaryColor),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Summary strip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: context.backgroundColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _summaryChip(context, 'Billed', CurrencyFormatter.format(_totalInvoiced), context.textColor),
                                Container(width: 1, height: 32, color: context.borderColor),
                                _summaryChip(context, 'Paid', CurrencyFormatter.format(_totalPaid), context.successColor),
                                Container(width: 1, height: 32, color: context.borderColor),
                                _summaryChip(context, 'Due', CurrencyFormatter.format(_computedBalance), context.errorColor),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Send As toggle (only if receipt photos exist)
                          if (invoicesWithPhotos.isNotEmpty) ...[
                            Text('SEND AS',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                                    color: context.textSecondaryColor, letterSpacing: 1.2)),
                            const SizedBox(height: 10),
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(
                                  value: false,
                                  label: Text('Account Statement', style: TextStyle(fontSize: 12)),
                                  icon: Icon(LucideIcons.fileText, size: 15),
                                ),
                                ButtonSegment(
                                  value: true,
                                  label: Text('Receipt Photo', style: TextStyle(fontSize: 12)),
                                  icon: Icon(LucideIcons.image, size: 15),
                                ),
                              ],
                              selected: {useReceiptPhoto},
                              onSelectionChanged: (s) => setSheet(() => useReceiptPhoto = s.first),
                              showSelectedIcon: false,
                              style: SegmentedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              ),
                            ),
                            // Receipt picker when multiple invoices have photos
                            if (useReceiptPhoto && invoicesWithPhotos.length > 1) ...[
                              const SizedBox(height: 14),
                              Text('CHOOSE RECEIPT',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                                      color: context.textSecondaryColor, letterSpacing: 1.2)),
                              const SizedBox(height: 6),
                              ...invoicesWithPhotos.map((tx) => InkWell(
                                onTap: () => setSheet(() => selectedTx = tx),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: selectedTx == tx
                                        ? context.primaryColor.withValues(alpha: 0.08)
                                        : context.backgroundColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selectedTx == tx ? context.primaryColor : context.borderColor,
                                      width: selectedTx == tx ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(LucideIcons.receipt, size: 16,
                                          color: selectedTx == tx ? context.primaryColor : context.textSecondaryColor),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Bill #${tx.receiptNumber ?? "N/A"} · ${DateFormat("dd MMM yyyy").format(tx.createdAt.toLocal())}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: selectedTx == tx ? context.primaryColor : context.textColor,
                                          ),
                                        ),
                                      ),
                                      if (selectedTx == tx)
                                        Icon(LucideIcons.checkCircle2, size: 16, color: context.primaryColor),
                                    ],
                                  ),
                                ),
                              )),
                            ],
                            const SizedBox(height: 20),
                          ],

                          // Message preview (WhatsApp bubble style)
                          Text('PREVIEW',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                                  color: context.textSecondaryColor, letterSpacing: 1.2)),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCF8C6),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(18),
                                bottomLeft: Radius.circular(18),
                                bottomRight: Radius.circular(18),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              message,
                              style: const TextStyle(
                                color: Color(0xFF0D0D0D),
                                fontSize: 13,
                                height: 1.65,
                              ),
                            ),
                          ),

                          // Phone field if missing
                          if (ledger.customerPhone == null || ledger.customerPhone!.trim().isEmpty) ...[
                            const SizedBox(height: 20),
                            TextField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'Customer Mobile Number',
                                prefixText: '+91 ',
                                hintText: '9876543210',
                                prefixIcon: Icon(LucideIcons.phone, color: context.primaryColor),
                                filled: true,
                                fillColor: context.textSecondaryColor.withValues(alpha: 0.03),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: context.borderColor),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // Action buttons
                  Container(
                    padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.of(ctx).padding.bottom),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      border: Border(top: BorderSide(color: context.borderColor.withValues(alpha: 0.5))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 52),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              side: BorderSide(color: context.borderColor),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 18, color: Colors.white),
                            label: const Text('SEND ON WHATSAPP',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              minimumSize: const Size(0, 52),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () async {
                              final phone = phoneController.text.trim().isNotEmpty
                                  ? phoneController.text.trim()
                                  : (ledger.customerPhone ?? '');

                              // Capture all values before popping — ctx becomes invalid after Navigator.pop
                              final capturedMessage = message;
                              final capturedReceiptLink = selectedTx?.receiptLink;
                              final capturedUseReceiptPhoto = useReceiptPhoto;

                              Navigator.pop(ctx);

                              if (capturedUseReceiptPhoto &&
                                  capturedReceiptLink != null &&
                                  capturedReceiptLink.isNotEmpty &&
                                  capturedReceiptLink != 'null') {
                                await WhatsAppUtils.shareActualImageOnWhatsApp(
                                  context: context,
                                  imageUrl: capturedReceiptLink,
                                  caption: capturedMessage,
                                  phone: phone,
                                );
                              } else {
                                if (phone.isNotEmpty) {
                                  await WhatsAppUtils.openWhatsAppChat(
                                    phone: phone,
                                    message: capturedMessage,
                                  );
                                } else {
                                  await WhatsAppUtils.shareReceipt(
                                    context,
                                    phone: phone,
                                    message: capturedMessage,
                                    dialogTitle: 'Send Reminder',
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  Widget _summaryChip(BuildContext context, String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: context.textSecondaryColor,
              letterSpacing: 0.5,
            )),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: valueColor,
            )),
      ],
    );
  }


  Widget _buildTransactionCard(LedgerTransaction tx) {
    final isPayment = tx.transactionType == 'PAYMENT';
    final isInvoice = tx.transactionType == 'INVOICE' || tx.transactionType == 'MANUAL_CREDIT';
    final canTap = isInvoice && (tx.receiptNumber != null || tx.receiptLink != null);

    final Color accentColor = isPayment ? context.successColor : context.errorColor;
    final Color bgColor = accentColor.withValues(alpha: 0.08);
    
    final IconData txIcon = isPayment ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight;
    final String txTitle = isPayment 
        ? 'Payment Received' 
        : (tx.paymentMode != null && tx.paymentMode!.toLowerCase() != 'credit' 
            ? '${tx.paymentMode} Sale' 
            : 'Credit Sale');

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
                                    // Clean up auto-generated notes for SMB readability
                                    tx.notes!.startsWith('Payment collected for Invoice')
                                        ? 'Full balance collected'
                                        : tx.notes!.startsWith('Auto-generated payment')
                                            ? 'Payment for Invoice #${tx.receiptNumber ?? ""}'
                                            : tx.notes!,
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
                    CurrencyFormatter.format(tx.receivedAmount ?? (tx.amount - (tx.balanceDue ?? (tx.isPaid ? 0 : tx.amount))))
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
                  if (isInvoice) ...[
                    // SETTLED badge for paid invoices
                    if (tx.isPaid)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.successColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.successColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.checkCircle2, size: 10, color: context.successColor),
                            const SizedBox(width: 4),
                            Text(
                              'SETTLED',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: context.successColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // COLLECT button removed — use RECORD PAYMENT button at bottom instead
                  ],
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
