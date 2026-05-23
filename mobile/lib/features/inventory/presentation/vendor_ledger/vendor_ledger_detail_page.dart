import 'package:mobile/core/theme/context_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../domain/models/vendor_ledger_models.dart';
import '../providers/vendor_ledger_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/models/inventory_models.dart';
import '../providers/inventory_items_provider.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mobile/features/inventory/presentation/inventory_review_page.dart';
import 'package:mobile/core/utils/whatsapp_utils.dart';
import 'package:mobile/features/settings/presentation/providers/shop_provider.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:share_plus/share_plus.dart';

class VendorLedgerDetailPage extends ConsumerStatefulWidget {
  final VendorLedger ledger;

  const VendorLedgerDetailPage({super.key, required this.ledger});

  @override
  ConsumerState<VendorLedgerDetailPage> createState() =>
      _VendorLedgerDetailPageState();
}

class VendorActivityItem {
  final DateTime date;
  final VendorLedgerTransaction? transaction;
  final Map<String, dynamic>? purchaseInvoice;
  final bool isPayment;

  VendorActivityItem({
    required this.date,
    this.transaction,
    this.purchaseInvoice,
    required this.isPayment,
  });
}

class _VendorLedgerDetailPageState
    extends ConsumerState<VendorLedgerDetailPage> {
  final dateFormatter = DateFormat('dd MMM yyyy');
  final detailDateFormatter = DateFormat('dd MMM yyyy, hh:mm a');

  List<VendorLedgerTransaction>? _transactions;
  List<Map<String, dynamic>>? _purchaseInvoices;
  List<VendorActivityItem>? _activityItems;
  bool _isLoading = true;

  // Selection state
  final Set<int> _selectedIds = {};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    List<VendorLedgerTransaction> transactions = [];
    List<Map<String, dynamic>> purchaseInvoices = [];

    // If ledger ID is negative, it's a view-only mode (no actual ledger exists)
    if (widget.ledger.id < 0) {
      purchaseInvoices = await ref
          .read(vendorLedgerProvider.notifier)
          .fetchInventoryItemsByVendor(widget.ledger.vendorName);
    } else {
      // Fetch both transactions and purchase invoices in parallel
      final results = await Future.wait([
        ref
            .read(vendorLedgerProvider.notifier)
            .fetchTransactions(widget.ledger.id),
        ref
            .read(vendorLedgerProvider.notifier)
            .fetchInventoryItemsByVendor(widget.ledger.vendorName),
      ]);

      transactions = results[0] as List<VendorLedgerTransaction>;
      purchaseInvoices = results[1] as List<Map<String, dynamic>>;
    }

    // Unify them
    final List<VendorActivityItem> activityItems = [];
    final Set<String> matchedInvoiceNumbers = {};

    // 1. Process ledger transactions
    for (var tx in transactions) {
      if (tx.linkedTransactionId != null) {
        continue; // Skip auto-generated payments
      }

      if (tx.transactionType == 'PAYMENT') {
        activityItems.add(
          VendorActivityItem(
            date: tx.createdAt,
            transaction: tx,
            isPayment: true,
          ),
        );
      } else {
        Map<String, dynamic>? matchedInvoice;
        if (tx.invoiceNumber != null && tx.invoiceNumber!.isNotEmpty) {
          try {
            matchedInvoice = purchaseInvoices.firstWhere(
              (inv) => inv['invoice_number']?.toString() == tx.invoiceNumber,
            );
            matchedInvoiceNumbers.add(tx.invoiceNumber!);
          } catch (_) {}
        }
        activityItems.add(
          VendorActivityItem(
            date: tx.createdAt,
            transaction: tx,
            purchaseInvoice: matchedInvoice,
            isPayment: false,
          ),
        );
      }
    }

    // 2. Process unmatched purchase invoices
    for (var inv in purchaseInvoices) {
      final invNumber = inv['invoice_number']?.toString() ?? '';
      if (invNumber.isNotEmpty && matchedInvoiceNumbers.contains(invNumber)) {
        continue; // Already processed
      }

      DateTime date = DateTime.now();
      final dateStr = inv['invoice_date']?.toString();
      if (dateStr != null && dateStr.isNotEmpty) {
        date = DateTime.tryParse(dateStr) ?? DateTime.now();
      }

      activityItems.add(
        VendorActivityItem(date: date, purchaseInvoice: inv, isPayment: false),
      );
    }

    // 3. Sort chronologically
    activityItems.sort((a, b) => b.date.compareTo(a.date));

    // Ensure descending date order for transactions
    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (mounted) {
      setState(() {
        _transactions = transactions;
        _purchaseInvoices = purchaseInvoices;
        _activityItems = activityItems;
        _isLoading = false;
      });
    }
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
    });
  }

  Future<void> _handleBatchMarkAsPaid(bool paid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          paid ? 'Mark as Paid' : 'Mark as Unpaid',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to mark ${_selectedIds.length} transactions as ${paid ? 'paid' : 'unpaid'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'CONFIRM',
              style: TextStyle(
                color: paid ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(vendorLedgerProvider.notifier)
          .batchTogglePaidStatus(_selectedIds.toList(), paid);
      if (success) {
        _clearSelection();
        _loadData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update transactions')),
        );
      }
    }
  }

  Future<void> _handleBatchDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Transactions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete ${_selectedIds.length} transactions? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'DELETE',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(vendorLedgerProvider.notifier)
          .batchDeleteTransactions(_selectedIds.toList());
      if (success) {
        _clearSelection();
        _loadData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete transactions')),
        );
      }
    }
  }

  Future<void> _navigateToBillDetails(String invoiceNumber) async {
    if (invoiceNumber.isEmpty) return;

    final invoice = _purchaseInvoices?.firstWhere(
      (inv) => inv['invoice_number']?.toString() == invoiceNumber,
      orElse: () => <String, dynamic>{},
    );

    if (invoice == null || invoice.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice details not found for #$invoiceNumber'),
          ),
        );
      }
      return;
    }

    final bundle = InventoryInvoiceBundle(
      invoiceNumber: invoiceNumber,
      date: invoice['invoice_date']?.toString() ?? '',
      vendorName:
          invoice['vendor_name']?.toString() ?? widget.ledger.vendorName,
      receiptLink: invoice['receipt_link']?.toString() ?? '',
      items:
          (invoice['items'] as List<dynamic>?)
              ?.map(
                (item) => InventoryItem.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
      totalAmount: (invoice['total_amount'] as num?)?.toDouble() ?? 0.0,
      hasMismatch: false,
      isVerified: true,
      createdAt: invoice['created_at']?.toString() ?? '',
    );

    if (mounted) {
      await context.pushNamed(
        'vendor-delivery-detail',
        extra: bundle,
        queryParameters: {
          'invoiceNumber': bundle.invoiceNumber,
          'vendorName': bundle.vendorName,
          'date': bundle.date,
        },
      );
      if (mounted) {
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vendorLedgerProvider);
    final currentLedger = state.ledgers.firstWhere(
      (l) => l.id == widget.ledger.id,
      orElse: () => widget.ledger,
    );

    // Calculate aggregated stats
    final txList =
        _transactions?.where((tx) => tx.linkedTransactionId == null).toList() ??
        [];

    double totalSpent = 0;
    if (_purchaseInvoices != null && _purchaseInvoices!.isNotEmpty) {
      for (var inv in _purchaseInvoices!) {
        totalSpent += (inv['total_amount'] as num?)?.toDouble() ?? 0.0;
      }
    } else {
      for (var tx in txList) {
        if (tx.transactionType != 'PAYMENT') totalSpent += tx.amount;
      }
    }

    final totalPaid = totalSpent - currentLedger.balanceDue;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: _buildAppBar(currentLedger),
      body: Column(
        children: [
          _buildHeaderCard(currentLedger, totalSpent, totalPaid),
          _buildSectionHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_activityItems == null || _activityItems!.isEmpty)
                ? _buildEmptyState(currentLedger)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                    itemCount: _activityItems!.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _activityItems![index];
                      return _buildActivityCard(item);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _isSelectionMode
          ? null
          : _buildBottomNavBar(currentLedger, totalSpent, totalPaid),
    );
  }

  PreferredSizeWidget _buildAppBar(VendorLedger ledger) {
    return AppBar(
      backgroundColor: context.primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: _isSelectionMode
          ? IconButton(
              icon: const Icon(LucideIcons.x, color: Colors.white),
              onPressed: _clearSelection,
            )
          : IconButton(
              icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
      title: _isSelectionMode
          ? Text(
              '${_selectedIds.length} Selected',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    ledger.vendorName.isNotEmpty
                        ? ledger.vendorName[0].toUpperCase()
                        : 'V',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ledger.vendorName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
      actions: [
        if (!_isSelectionMode)
          IconButton(
            icon: const Icon(LucideIcons.moreVertical, color: Colors.white),
            onPressed: () {},
          )
        else ...[
          IconButton(
            icon: const Icon(LucideIcons.checkCircle, color: Colors.white),
            onPressed: () => _handleBatchMarkAsPaid(true),
            tooltip: 'Mark Paid',
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2, color: Colors.white),
            onPressed: _handleBatchDelete,
            tooltip: 'Delete',
          ),
        ],
      ],
    );
  }

  Widget _buildHeaderCard(
    VendorLedger ledger,
    double totalSpent,
    double totalPaid,
  ) {
    final balance = ledger.balanceDue;
    final isPending = balance > 0.01;
    final isAdvance = balance < -0.01;

    String headerLabel = 'TOTAL BALANCE DUE';
    if (isAdvance) headerLabel = 'ADVANCE';
    if (!isPending && !isAdvance) headerLabel = 'SETTLED';

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
          ),
        ],
      ),
      child: Padding(
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
                        color: isPending
                            ? Colors.white
                            : Colors.greenAccent.shade200,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    CurrencyFormatter.formatPlain(balance.abs()),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: isPending
                          ? Colors.white
                          : Colors.greenAccent.shade200,
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
                      label: 'TOTAL SPENT',
                      value: CurrencyFormatter.format(totalSpent),
                      icon: LucideIcons.shoppingCart,
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
                      value: CurrencyFormatter.format(totalPaid),
                      icon: LucideIcons.checkCircle2,
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

  Widget _buildSectionHeader() {
    return Padding(
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
          if (_activityItems != null && _activityItems!.isNotEmpty)
            Text(
              '${_activityItems!.length} Entries',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.textSecondaryColor.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(VendorActivityItem item) {
    final tx = item.transaction;
    final inv = item.purchaseInvoice;
    final isPayment = item.isPayment;
    final isSelected = tx != null && _selectedIds.contains(tx.id);

    final Color accentColor = isPayment
        ? context.successColor
        : context.errorColor;
    final Color bgColor = accentColor.withValues(alpha: 0.08);

    final IconData txIcon = isPayment
        ? LucideIcons.arrowDownLeft
        : LucideIcons.arrowUpRight;
    final String txTitle = isPayment ? 'Payment Sent' : 'Purchase Bill';

    final amount = isPayment
        ? (tx?.amount ?? 0)
        : (inv?['total_amount']?.toDouble() ?? tx?.amount ?? 0);
    final date = item.date;
    final isPaid = tx?.isPaid ?? (inv?['payment_status'] == 'paid');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? context.primaryColor.withValues(alpha: 0.05)
            : context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: context.premiumShadow,
        border: Border.all(
          color: isSelected
              ? context.primaryColor
              : context.borderColor.withValues(alpha: 0.5),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onLongPress: tx != null ? () => _toggleSelection(tx.id) : null,
        onTap: () {
          if (_isSelectionMode && tx != null) {
            _toggleSelection(tx.id);
          } else if (!isPayment) {
            final invNum =
                inv?['invoice_number']?.toString() ?? tx?.invoiceNumber ?? '';
            if (invNum.isNotEmpty) _navigateToBillDetails(invNum);
          }
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isSelectionMode) ...[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 12, top: 4),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? context.primaryColor
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? context.primaryColor
                              : context.textSecondaryColor,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        LucideIcons.check,
                        size: 12,
                        color: isSelected ? Colors.white : Colors.transparent,
                      ),
                    ),
                  ],
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
                              '${isPayment ? '-' : '+'} ${CurrencyFormatter.format(amount)}',
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
                              dateFormatter.format(date),
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textSecondaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (!isPayment && isPaid) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: context.successColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'PAID',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: context.successColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!isPayment)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: context.textSecondaryColor.withValues(alpha: 0.03),
                  border: Border(
                    top: BorderSide(color: context.borderColor, width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildClarityItem(
                      'Bill Amount',
                      CurrencyFormatter.format(amount),
                    ),
                    _buildClarityItem(
                      'Bill #',
                      inv?['invoice_number']?.toString() ??
                          tx?.invoiceNumber ??
                          'N/A',
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                border: Border(
                  top: BorderSide(color: context.borderColor, width: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (tx != null || (inv?['receipt_link'] != null))
                    TextButton.icon(
                      onPressed: () {
                        if (tx != null) {
                          _showReceiptPhotoDialog(tx);
                        } else if (inv?['receipt_link'] != null) {
                          _showInvoicePhotoDialog(
                            inv!['receipt_link'],
                            inv['invoice_number']?.toString() ?? 'N/A',
                          );
                        }
                      },
                      icon: const Icon(LucideIcons.eye, size: 14),
                      label: const Text(
                        'VIEW BILL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: context.primaryColor,
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

  Widget _buildEmptyState(VendorLedger ledger) {
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
            child: Icon(
              LucideIcons.fileText,
              size: 48,
              color: context.borderColor,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No activity yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Activity will appear here once\na purchase or payment is recorded.',
            style: TextStyle(fontSize: 14, color: context.textSecondaryColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(LucideIcons.camera, size: 18),
            label: const Text(
              'Scan Purchase Bill',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              context.push('/upload', extra: {'vendorName': ledger.vendorName});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar(VendorLedger ledger, double spent, double paid) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(
          top: BorderSide(
            color: context.borderColor.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
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
            flex: 1,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 52),
                side: const BorderSide(color: Color(0xFF25D366), width: 1.5),
                foregroundColor: const Color(0xFF25D366),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () =>
                  _showWhatsAppReminderSheet(context, ref, ledger, spent, paid),
              child: const FaIcon(FontAwesomeIcons.whatsapp, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: ElevatedButton.icon(
              icon: const Icon(
                LucideIcons.indianRupee,
                size: 18,
                color: Colors.white,
              ),
              label: const Text(
                'RECORD PAYMENT',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.primaryColor,
                minimumSize: const Size(0, 52),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => _showAddPaymentDialog(context, ledger),
            ),
          ),
        ],
      ),
    );
  }

  // Dialogs & Sheets

  void _showAddPaymentDialog(BuildContext context, VendorLedger ledger) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  color: context.primaryColor.withValues(alpha: 0.1),
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
                      CurrencyFormatter.format(ledger.balanceDue),
                      style: TextStyle(
                        color: context.primaryColor,
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
                              content: Text('Please enter a valid amount'),
                            ),
                          );
                          return;
                        }
                        setModalState(() => isSubmitting = true);
                        final success = await ref
                            .read(vendorLedgerProvider.notifier)
                            .recordPayment(
                              ledger.id,
                              amount,
                              notesController.text,
                              vendorName: ledger.vendorName,
                            );
                        if (success && context.mounted) {
                          ref.invalidate(inventoryItemsProvider);
                          ref.invalidate(dashboardTotalsProvider);
                          Navigator.pop(context);
                          _loadData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Payment recorded! 🎉'),
                            ),
                          );
                        } else if (context.mounted) {
                          setModalState(() => isSubmitting = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to save payment.'),
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: context.primaryColor,
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
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save Payment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showReceiptPhotoDialog(VendorLedgerTransaction tx) {
    if (tx.receiptLink != null && tx.receiptLink != 'null') {
      _showInvoicePhotoDialog(tx.receiptLink!, tx.invoiceNumber ?? 'N/A');
    } else if (tx.invoiceNumber != null) {
      // Try to fetch it
      showDialog(
        context: context,
        builder: (context) => FutureBuilder<String?>(
          future: ref
              .read(vendorLedgerProvider.notifier)
              .fetchReceiptLink(tx.invoiceNumber!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }
            final link = snapshot.data;
            if (link == null || link.isEmpty) {
              return AlertDialog(
                title: const Text('No Photo'),
                content: const Text(
                  'No receipt photo available for this invoice.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              );
            }
            Navigator.pop(context); // Close wait dialog
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _showInvoicePhotoDialog(link, tx.invoiceNumber!),
            );
            return const SizedBox.shrink();
          },
        ),
      );
    }
  }

  void _showInvoicePhotoDialog(String url, String invoiceNumber) {
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
            color: Colors.black87,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.receipt,
                      color: Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Invoice #$invoiceNumber',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12),
              Expanded(
                child: InteractiveViewer(
                  maxScale: 5.0,
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(
                        LucideIcons.alertTriangle,
                        color: Colors.orange,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showWhatsAppReminderSheet(
    BuildContext context,
    WidgetRef ref,
    VendorLedger ledger,
    double spent,
    double paid,
  ) {
    final shop = ref.read(shopProvider);
    final user = ref.read(authProvider).user;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share Reminder',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF25D366),
                child: FaIcon(
                  FontAwesomeIcons.whatsapp,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              title: const Text(
                'Send Payment Update',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Share current balance and payment status'),
              onTap: () {
                Navigator.pop(context);
                final message =
                    'Payment Update for ${ledger.vendorName}\n'
                    'Current Balance: ${CurrencyFormatter.format(ledger.balanceDue)}\n'
                    'Thank you!\n— *${shop.name.isNotEmpty ? shop.name : user?.name ?? 'Our Shop'}*';
                WhatsAppUtils.openWhatsAppChat(phone: '', message: message);
              },
            ),
            const Divider(),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: context.primaryColor.withValues(alpha: 0.1),
                child: Icon(
                  LucideIcons.share2,
                  color: context.primaryColor,
                  size: 18,
                ),
              ),
              title: const Text(
                'Share Ledger Summary',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Share spend and payment stats'),
              onTap: () {
                Navigator.pop(context);
                final summary =
                    'Ledger Summary for ${ledger.vendorName}\nTotal Spent: ${CurrencyFormatter.format(spent)}\nTotal Paid: ${CurrencyFormatter.format(paid)}\nBalance Due: ${CurrencyFormatter.format(ledger.balanceDue)}';
                SharePlus.instance.share(ShareParams(text: summary));
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }


}
