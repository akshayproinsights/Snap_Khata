import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import '../../domain/models/vendor_ledger_models.dart';
import '../providers/vendor_ledger_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/inventory_models.dart';
import '../inventory_review_page.dart';

class VendorLedgerDetailPage extends ConsumerStatefulWidget {
  final VendorLedger ledger;

  const VendorLedgerDetailPage({super.key, required this.ledger});

  @override
  ConsumerState<VendorLedgerDetailPage> createState() =>
      _VendorLedgerDetailPageState();
}

class ActivityItem {
  final DateTime date;
  final VendorLedgerTransaction? transaction;
  final Map<String, dynamic>? purchaseInvoice;
  final bool isPayment;

  ActivityItem({
    required this.date,
    this.transaction,
    this.purchaseInvoice,
    required this.isPayment,
  });
}

class _VendorLedgerDetailPageState
    extends ConsumerState<VendorLedgerDetailPage> {
  final currencyFormatter =
      NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');
  final dateFormatter = DateFormat('dd MMM yyyy');

  List<VendorLedgerTransaction>? _transactions;
  List<Map<String, dynamic>>? _purchaseInvoices;
  List<ActivityItem>? _activityItems;
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
        ref.read(vendorLedgerProvider.notifier).fetchTransactions(widget.ledger.id),
        ref.read(vendorLedgerProvider.notifier).fetchInventoryItemsByVendor(widget.ledger.vendorName),
      ]);

      transactions = results[0] as List<VendorLedgerTransaction>;
      purchaseInvoices = results[1] as List<Map<String, dynamic>>;
    }

    // Unify them
    final List<ActivityItem> activityItems = [];
    final Set<String> matchedInvoiceNumbers = {};

    // 1. Process ledger transactions
    for (var tx in transactions) {
      if (tx.linkedTransactionId != null) continue; // Skip auto-generated payments

      if (tx.transactionType == 'PAYMENT') {
        activityItems.add(ActivityItem(
          date: tx.createdAt,
          transaction: tx,
          isPayment: true,
        ));
      } else {
        Map<String, dynamic>? matchedInvoice;
        if (tx.invoiceNumber != null && tx.invoiceNumber!.isNotEmpty) {
          try {
            matchedInvoice = purchaseInvoices.firstWhere(
              (inv) => inv['invoice_number']?.toString() == tx.invoiceNumber
            );
            matchedInvoiceNumbers.add(tx.invoiceNumber!);
          } catch (_) {}
        }
        activityItems.add(ActivityItem(
          date: tx.createdAt,
          transaction: tx,
          purchaseInvoice: matchedInvoice,
          isPayment: false,
        ));
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

      activityItems.add(ActivityItem(
        date: date,
        purchaseInvoice: inv,
        isPayment: false,
      ));
    }

    // 3. Sort chronologically
    activityItems.sort((a, b) => b.date.compareTo(a.date));

    // Ensure descending date order for transactions (just in case they are used elsewhere)
    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    setState(() {
      _transactions = transactions;
      _purchaseInvoices = purchaseInvoices;
      _activityItems = activityItems;
      _isLoading = false;
    });
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
        title: Text(paid ? 'Mark as Paid' : 'Mark as Unpaid'),
        content: Text('Are you sure you want to mark ${_selectedIds.length} transactions as ${paid ? 'paid' : 'unpaid'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Confirm', style: TextStyle(color: paid ? Colors.green : Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(vendorLedgerProvider.notifier).batchTogglePaidStatus(_selectedIds.toList(), paid);
      if (success) {
        _clearSelection();
        _loadData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update transactions')));
      }
    }
  }

  Future<void> _handleBatchDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transactions'),
        content: Text('Are you sure you want to delete ${_selectedIds.length} transactions? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(vendorLedgerProvider.notifier).batchDeleteTransactions(_selectedIds.toList());
      if (success) {
        _clearSelection();
        _loadData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete transactions')));
      }
    }
  }


  /// Opens a dialog showing the original receipt photo for the given transaction.
  void _showReceiptPhotoDialog(VendorLedgerTransaction tx) async {
    if (tx.invoiceNumber == null) return;

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
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    const Icon(LucideIcons.receipt, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Invoice #${tx.invoiceNumber}',
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
              // Receipt photo area
              Expanded(
                child: FutureBuilder<String?>(
                  future: ref.read(vendorLedgerProvider.notifier).fetchReceiptLink(tx.invoiceNumber!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 12),
                            Text('Loading receipt...', style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      );
                    }

                    final receiptLink = snapshot.data;

                    if (receiptLink == null || receiptLink.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.imageOff, color: Colors.white38, size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'No receipt photo available',
                              style: TextStyle(color: Colors.white54, fontSize: 15),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Invoice #${tx.invoiceNumber}',
                              style: const TextStyle(color: Colors.white30, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: InteractiveViewer(
                        maxScale: 5.0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: receiptLink,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            placeholder: (context, url) => Container(
                              height: 300,
                              color: Colors.white10,
                              child: const Center(
                                child: CircularProgressIndicator(color: Colors.white),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: 200,
                              color: Colors.white10,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.alertTriangle, color: Colors.orange, size: 36),
                                  SizedBox(height: 8),
                                  Text('Could not load receipt image',
                                    style: TextStyle(color: Colors.white54)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Action buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _togglePaidStatus(tx, !tx.isPaid);
                        },
                        icon: Icon(
                          tx.isPaid ? LucideIcons.xCircle : LucideIcons.checkCircle,
                          size: 16,
                          color: tx.isPaid ? Colors.orange.shade300 : Colors.green.shade300,
                        ),
                        label: Text(
                          tx.isPaid ? 'Mark as Unpaid' : 'Mark as Paid',
                          style: TextStyle(
                            color: tx.isPaid ? Colors.orange.shade300 : Colors.green.shade300,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: tx.isPaid ? Colors.orange.shade300 : Colors.green.shade300,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddPaymentDialog(BuildContext context) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                      Text(
                        'Record Payment',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface),
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
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
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
                                    notesController.text, vendorName: widget.ledger.vendorName);

                            if (success && context.mounted) {
                              Navigator.pop(context);
                              _loadData();
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
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
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

    // Calculate aggregated stats from available transactions AND purchase invoices
    // Hide auto-generated payments by filtering out those with a linkedTransactionId
    final txList = _transactions?.where((tx) => tx.linkedTransactionId == null).toList() ?? [];

    // Calculate totals from ledger transactions (credit invoices)
    double ledgerTotalSpend = 0;
    int ledgerOrdersCount = 0;
    DateTime? ledgerLastOrderDate;

    for (var tx in txList) {
      if (tx.transactionType != 'PAYMENT') {
        ledgerTotalSpend += tx.amount;
        ledgerOrdersCount++;
        if (ledgerLastOrderDate == null || tx.createdAt.isAfter(ledgerLastOrderDate)) {
          ledgerLastOrderDate = tx.createdAt;
        }
      }
    }

    // Calculate totals from purchase invoices (inventory items)
    double purchaseTotalSpend = 0;
    int purchaseOrdersCount = _purchaseInvoices?.length ?? 0;
    DateTime? purchaseLastOrderDate;

    if (_purchaseInvoices != null) {
      for (var invoice in _purchaseInvoices!) {
        final amount = (invoice['total_amount'] as num?)?.toDouble() ?? 0.0;
        purchaseTotalSpend += amount;

        final dateStr = invoice['invoice_date']?.toString();
        if (dateStr != null && dateStr.isNotEmpty) {
          final date = DateTime.tryParse(dateStr);
          if (date != null && (purchaseLastOrderDate == null || date.isAfter(purchaseLastOrderDate))) {
            purchaseLastOrderDate = date;
          }
        }
      }
    }

    // Combine totals - use purchase invoices as primary source for spend/orders if available
    // since they represent actual purchase history
    final totalSpend = purchaseTotalSpend > 0 ? purchaseTotalSpend : ledgerTotalSpend;
    final ordersCount = purchaseOrdersCount > 0 ? purchaseOrdersCount : ledgerOrdersCount;
    final lastOrderDate = purchaseLastOrderDate ?? ledgerLastOrderDate;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        leading: _isSelectionMode 
          ? IconButton(icon: const Icon(LucideIcons.x), onPressed: _clearSelection)
          : IconButton(
              icon: const Icon(LucideIcons.arrowLeft),
              onPressed: () => Navigator.pop(context),
            ),
        title: _isSelectionMode ? Text('${_selectedIds.length} Selected') : null,
        actions: [
          if (!_isSelectionMode)
            IconButton(
              icon: const Icon(LucideIcons.moreVertical),
              onPressed: () {},
            )
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Profile
                Text(
                  currentLedger.vendorName,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final isPending = currentLedger.balanceDue > 0;
                    final statusColor = isPending ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.tertiary;
                    final statusText = isPending ? 'Pending' : 'Settled';
                    final statusIcon = isPending ? LucideIcons.clock : LucideIcons.checkCircle2;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            statusIcon,
                            size: 14,
                            color: statusColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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


                // Account Activity Section
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Account Activity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (_isSelectionMode)
                      // In selection mode: show Select All / Deselect All
                      TextButton(
                        onPressed: () {
                          final activityTxIds = (_activityItems ?? [])
                              .where((a) => !a.isPayment && a.transaction != null)
                              .map((a) => a.transaction!.id)
                              .toSet();
                          setState(() {
                            if (_selectedIds.containsAll(activityTxIds) && activityTxIds.isNotEmpty) {
                              _selectedIds.clear();
                            } else {
                              _selectedIds.addAll(activityTxIds);
                            }
                          });
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.primary,
                          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Builder(builder: (context) {
                          final activityTxIds = (_activityItems ?? [])
                              .where((a) => !a.isPayment && a.transaction != null)
                              .map((a) => a.transaction!.id)
                              .toSet();
                          final allSelected = _selectedIds.containsAll(activityTxIds) && activityTxIds.isNotEmpty;
                          return Text(
                            allSelected ? 'Deselect All' : 'Select All',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          );
                        }),
                      )
                    else
                      Row(
                        children: [
                          // Select button
                          TextButton(
                            onPressed: () {
                              final firstInvoiceTx = (_activityItems ?? []).firstWhere(
                                (a) => !a.isPayment && a.transaction != null,
                                orElse: () => ActivityItem(date: DateTime.now(), isPayment: false),
                              );
                              if (firstInvoiceTx.transaction != null) {
                                _toggleSelection(firstInvoiceTx.transaction!.id);
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.primary,
                              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(LucideIcons.checkSquare, size: 14),
                                SizedBox(width: 6),
                                Text('Select', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Pay button
                          TextButton(
                            onPressed: () => _showAddPaymentDialog(context),
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.primary,
                              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          ),
                        ],
                      )
                  ],
                ),
                const SizedBox(height: 16),

                // Unified Activity List
                _isLoading
                    ? const Center(child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ))
                    : (_activityItems == null || _activityItems!.isEmpty)
                        ? Center(
                            child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text('No account activity found',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ))
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _activityItems!.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _activityItems![index];
                              return _buildActivityCard(item);
                            },
                          ),

                const SizedBox(height: 100), // More padding for batch bar
              ],
            ),
          ),
          // Only show batch action bar if in selection mode AND ledger exists
          if (_isSelectionMode && widget.ledger.id >= 0)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: _buildBatchActionBar(),
            ),
        ],
      ),
    );
  }

  Widget _buildBatchActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildBatchActionButton(
            LucideIcons.checkCircle, 
            'Mark Paid', 
            Colors.green.shade400, 
            () => _handleBatchMarkAsPaid(true)
          ),
          Container(height: 24, width: 1, color: Colors.white24),
          _buildBatchActionButton(
            LucideIcons.xCircle, 
            'Mark Unpaid', 
            Colors.orange.shade400, 
            () => _handleBatchMarkAsPaid(false)
          ),
          Container(height: 24, width: 1, color: Colors.white24),
          _buildBatchActionButton(
            LucideIcons.trash2, 
            'Delete', 
            Colors.red.shade400, 
            _handleBatchDelete
          ),
        ],
      ),
    );
  }

  Widget _buildBatchActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.surface, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(ActivityItem item) {
    if (item.isPayment && item.transaction != null) {
      return _buildTransactionCard(item.transaction!, true);
    } else if (item.transaction != null) {
      return _buildTransactionCard(item.transaction!, false);
    } else if (item.purchaseInvoice != null) {
      return _buildPurchaseInvoiceCard(item.purchaseInvoice!);
    }
    return const SizedBox.shrink();
  }

  Widget _buildTransactionCard(VendorLedgerTransaction tx, bool isPayment) {
    final isSelected = _selectedIds.contains(tx.id);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant, width: isSelected ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onLongPress: () {
          // HapticFeedback.heavyImpact();
          _toggleSelection(tx.id);
        },
        onTap: () {
          if (_isSelectionMode) {
            _toggleSelection(tx.id);
          } else if (!isPayment && tx.invoiceNumber?.isNotEmpty == true) {
            _navigateToBillDetails(tx.invoiceNumber!);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isSelectionMode) ...[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 10, top: 4),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                          border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant, width: 2),
                        ),
                        child: Icon(LucideIcons.check, size: 12, color: isSelected ? Theme.of(context).colorScheme.onPrimary : Colors.transparent),
                      ),
                    ],
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isPayment ? Colors.green.withValues(alpha: 0.1) : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPayment ? LucideIcons.arrowUpRight : LucideIcons.receipt,
                        color: isPayment ? Colors.green : Theme.of(context).colorScheme.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  dateFormatter.format(tx.createdAt.toLocal()),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Theme.of(context).colorScheme.onSurface,
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
                                    borderRadius: BorderRadius.circular(4),
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
                            isPayment
                                ? 'Payment Sent'
                                : (tx.invoiceNumber?.isNotEmpty == true ? 'Invoice #${tx.invoiceNumber}' : 'Purchase Order'),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isPayment && !_isSelectionMode)
                               IconButton(
                                 icon: Icon(LucideIcons.eye, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                 padding: EdgeInsets.zero,
                                 constraints: const BoxConstraints(),
                                 onPressed: () => _showReceiptPhotoDialog(tx),
                                 tooltip: 'View Receipt Photo',
                               ),
                            const SizedBox(width: 8),
                            Text(
                              '${isPayment ? '-' : ''}${currencyFormatter.format(tx.amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isPayment ? Colors.green : (!tx.isPaid ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurface),
                              ),
                            ),
                            if (!isPayment && !_isSelectionMode && tx.isPaid) ...[
                               const SizedBox(width: 4),
                               PopupMenuButton<String>(
                                 icon: Icon(LucideIcons.moreVertical, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                 padding: EdgeInsets.zero,
                                 constraints: const BoxConstraints(),
                                 itemBuilder: (context) => [
                                   const PopupMenuItem(
                                     value: 'unpaid',
                                     child: Text('Mark as Unpaid'),
                                   ),
                                 ],
                                 onSelected: (value) {
                                   if (value == 'unpaid') _togglePaidStatus(tx, false);
                                 },
                               ),
                            ],
                          ],
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
                        if (!isPayment && !_isSelectionMode && !tx.isPaid)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: SizedBox(
                              height: 28,
                              child: ElevatedButton(
                                onPressed: () => _togglePaidStatus(tx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                child: const Text('Mark Paid', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  void _navigateToBillDetails(String invoiceNumber) {
    if (invoiceNumber.isEmpty) return;
    
    final invoice = _purchaseInvoices?.firstWhere(
      (inv) => inv['invoice_number']?.toString() == invoiceNumber,
      orElse: () => <String, dynamic>{},
    );

    if (invoice == null || invoice.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Invoice details not found for #$invoiceNumber')),
        );
      }
      return;
    }

    final itemsList = (invoice['items'] as List<dynamic>?)
        ?.map((item) => InventoryItem.fromJson(item as Map<String, dynamic>))
        .toList() ?? [];
              
    final totalAmount = (invoice['total_amount'] as num?)?.toDouble() ?? 0.0;
    final receiptLink = invoice['receipt_link']?.toString();
    final invoiceDate = invoice['invoice_date']?.toString() ?? '';

    final bundle = InventoryInvoiceBundle(
      invoiceNumber: invoiceNumber,
      date: invoiceDate,
      vendorName: invoice['vendor_name']?.toString() ?? widget.ledger.vendorName,
      receiptLink: receiptLink ?? '',
      items: itemsList,
      totalAmount: totalAmount,
      hasMismatch: false,
      isVerified: true,
      createdAt: invoice['upload_date']?.toString() ?? '',
    );
    
    context.pushNamed('vendor-delivery-detail', extra: bundle);
  }

  Future<void> _togglePaidStatus(VendorLedgerTransaction tx, bool markAsPaid) async {
    final success = await ref.read(vendorLedgerProvider.notifier).toggleTransactionPaidStatus(tx.id, markAsPaid);
    if (success) {
      _loadData();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update status')));
      }
    }
  }

  /// Builds a card for displaying a purchase invoice from inventory_items
  Widget _buildPurchaseInvoiceCard(Map<String, dynamic> invoice) {
    final invoiceNumber = invoice['invoice_number']?.toString() ?? '';
    final invoiceDate = invoice['invoice_date']?.toString() ?? '';
    final totalAmount = (invoice['total_amount'] as num?)?.toDouble() ?? 0.0;
    final itemCount = (invoice['item_count'] as num?)?.toInt() ?? 0;
    final receiptLink = invoice['receipt_link']?.toString();

    DateTime? parsedDate;
    if (invoiceDate.isNotEmpty) {
      parsedDate = DateTime.tryParse(invoiceDate);
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          if (invoiceNumber.isNotEmpty) {
            _navigateToBillDetails(invoiceNumber);
          } else if (receiptLink != null && receiptLink.isNotEmpty) {
            _showPurchaseInvoiceReceipt(receiptLink, invoiceNumber);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.package,
                      color: Color(0xFFF59E0B),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                invoiceNumber.isNotEmpty ? 'Invoice #$invoiceNumber' : 'Purchase Invoice',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          parsedDate != null
                              ? dateFormatter.format(parsedDate)
                              : invoiceDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (receiptLink != null && receiptLink.isNotEmpty)
                    IconButton(
                       icon: Icon(LucideIcons.eye, size: 18, color: Theme.of(context).colorScheme.primary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showPurchaseInvoiceReceipt(receiptLink, invoiceNumber),
                      tooltip: 'View Receipt',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                       Icon(LucideIcons.box, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        '$itemCount item${itemCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 13,
                           color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    currencyFormatter.format(totalAmount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
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

  /// Shows a modal with the purchase invoice receipt photo
  void _showPurchaseInvoiceReceipt(String receiptLink, String invoiceNumber) {
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
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    const Icon(LucideIcons.receipt, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        invoiceNumber.isNotEmpty ? 'Invoice #$invoiceNumber' : 'Purchase Receipt',
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
              // Receipt photo area
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: receiptLink,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      placeholder: (context, url) => Container(
                        height: 300,
                        color: Colors.white10,
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 200,
                        color: Colors.white10,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.alertTriangle, color: Colors.orange, size: 36),
                            SizedBox(height: 8),
                            Text('Could not load receipt image',
                              style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      ),
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
}
