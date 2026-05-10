import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/shared/widgets/universal_image.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';
import 'package:mobile/features/inventory/domain/models/invoice_item_v2_model.dart';
import 'package:mobile/features/inventory/presentation/inventory_review_page.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:mobile/features/inventory/presentation/widgets/edit_item_modal.dart';
import 'package:mobile/features/inventory/presentation/widgets/header_adjustments_section.dart';
import 'package:mobile/features/inventory/presentation/widgets/invoice_item_card.dart';
import 'package:mobile/features/inventory/presentation/widgets/supplier_autocomplete_field.dart';
import 'package:mobile/shared/widgets/app_toast.dart';
import 'package:intl/intl.dart';
import 'providers/vendor_ledger_provider.dart';
import 'providers/inventory_items_provider.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mobile/features/upload/presentation/providers/upload_provider.dart';

class InventoryInvoiceReviewPage extends ConsumerStatefulWidget {
  final InventoryInvoiceBundle bundle;
  final List<InventoryInvoiceBundle> allBundles;
  final int currentIndex;

  const InventoryInvoiceReviewPage({
    super.key,
    required this.bundle,
    this.allBundles = const [],
    this.currentIndex = -1,
  });

  @override
  ConsumerState<InventoryInvoiceReviewPage> createState() =>
      _InventoryInvoiceReviewPageState();
}

class _InventoryInvoiceReviewPageState
    extends ConsumerState<InventoryInvoiceReviewPage> {
  // ── Header Details state ──────────────────────────────────────────
  late final TextEditingController _vendorNameController;
  late final TextEditingController _invoiceNumberController;
  late final TextEditingController _dateController;
  late final TextEditingController _paidAmountController;

  String _paymentMode = 'Credit';
  bool _isLoading = false;
  bool _isNavigatingAway = false;

  late List<HeaderAdjustment> _adjustments;
  double? _targetTotal;

  @override
  void initState() {
    super.initState();
    _vendorNameController =
        TextEditingController(text: widget.bundle.vendorName);
    _invoiceNumberController =
        TextEditingController(text: widget.bundle.invoiceNumber);

    String initialDate = widget.bundle.date;
    try {
        final parsed = DateTime.tryParse(initialDate);
        if (parsed != null) {
            initialDate = DateFormat('dd/MM/yyyy').format(parsed);
        }
    } catch (_) {}
    _dateController = TextEditingController(text: initialDate);
    _paidAmountController = TextEditingController(text: '0');
    _adjustments = List<HeaderAdjustment>.from(widget.bundle.headerAdjustments);
  }

  @override
  void dispose() {
    _vendorNameController.dispose();
    _invoiceNumberController.dispose();
    _dateController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  Future<void> _deleteItem(InventoryItem item) async {
    HapticFeedback.mediumImpact();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text('Delete "${item.description}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(inventoryProvider.notifier).deleteItem(item.id);
      ref.invalidate(inventoryItemsProvider);
      ref.invalidate(vendorLedgerProvider);
      ref.invalidate(dashboardTotalsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${item.description}" deleted'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteInvoice(List<InventoryItem> items) async {
    HapticFeedback.mediumImpact();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entire Invoice?'),
        content: Text('Delete invoice with ${items.length} items? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final ids = items.map((i) => i.id).toList();
      await ref.read(inventoryProvider.notifier).bulkDeleteItems(ids);
      ref.invalidate(inventoryItemsProvider);
      ref.invalidate(vendorLedgerProvider);
      ref.invalidate(dashboardTotalsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice deleted')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete invoice: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showEditAdjustmentDialog(int index, HeaderAdjustment adj) {
    final controller = TextEditingController(text: adj.amount.abs().round().toString());
    final type = adj.adjustmentType;
    final isDeduction = adj.amount < 0 || type == 'HEADER_DISCOUNT' || type == 'SCHEME';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${adj.description ?? adj.adjustmentType}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                prefixText: '₹ ',
                suffixText: isDeduction ? '(Deduction)' : '(Addition)',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(controller.text) ?? 0.0;
              setState(() {
                _adjustments[index] = adj.copyWith(amount: isDeduction ? -val.abs() : val.abs());
                _targetTotal = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showEditTotalDialog(double currentCalculatedTotal) {
    final controller = TextEditingController(text: (_targetTotal ?? currentCalculatedTotal).round().toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adjust Grand Total'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the correct total from the bill. We will adjust the extras to match.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Total Bill Amount (₹)',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _targetTotal = null;
                _adjustments.removeWhere((a) => a.description == 'Manual Correction');
              });
              Navigator.pop(context);
            },
            child: const Text('Reset to Auto'),
          ),
          FilledButton(
            onPressed: () {
              final newTotal = double.tryParse(controller.text);
              if (newTotal != null) {
                setState(() {
                  _targetTotal = newTotal;
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Update Total'),
          ),
        ],
      ),
    );
  }

  void _showFullImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Invoice Image'),
          ),
          body: InteractiveViewer(
            child: Center(
              child: Hero(
                tag: 'inv_img_${widget.bundle.invoiceNumber}',
                child: UniversalImage(
                  path: imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    DateTime? initialDate;
    try {
      initialDate = DateFormat('dd/MM/yyyy').parse(_dateController.text);
    } catch (_) {
      try {
        initialDate = DateTime.tryParse(_dateController.text) ?? DateTime.now();
      } catch (_) {
        initialDate = DateTime.now();
      }
    }
    
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _saveInvoice(List<InventoryItem> items, double totalAmount) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final paidAmount = double.tryParse(_paidAmountController.text) ?? 0.0;
      final data = {
        'invoice_number': _invoiceNumberController.text.trim(),
        'vendor_name': _vendorNameController.text.trim(),
        'invoice_date': _dateController.text.trim(),
        'payment_mode': _paymentMode,
        'balance_owed': (totalAmount - paidAmount).clamp(0.0, double.infinity),
        'amount_paid': paidAmount,
        'item_ids': items.map((i) => i.id).toList(),
        'final_total': totalAmount,
        'adjustments': _adjustments.map((a) => a.toJson()).toList(),
      };

      await ref.read(inventoryProvider.notifier).verifyInvoice(data);
      ref.read(uploadProvider.notifier).unlockBlocking();

      if (!mounted) return;

      AppToast.showSuccess(
        context,
        'Invoice saved successfully.',
        title: 'Saved',
      );

      _goToNextInvoice();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.showError(context, e.toString(), title: 'Save Failed');
      }
    }
  }

  void _goToNextInvoice() {
    if (_isNavigatingAway) return;
    
    final pendingBundles = widget.allBundles
        .where((b) => !b.isVerified)
        .toList();
    
    // Find next bundle after the current index
    InventoryInvoiceBundle? nextBundle;
    int nextIdx = -1;
    
    if (widget.currentIndex != -1 && widget.currentIndex < widget.allBundles.length - 1) {
        for (int i = widget.currentIndex + 1; i < widget.allBundles.length; i++) {
            if (!widget.allBundles[i].isVerified) {
                nextBundle = widget.allBundles[i];
                nextIdx = i;
                break;
            }
        }
    }
    
    // If no next found, pick the first pending one that isn't the current one
    if (nextBundle == null && pendingBundles.isNotEmpty) {
        for (final b in pendingBundles) {
            if (b.invoiceNumber != widget.bundle.invoiceNumber) {
                nextBundle = b;
                nextIdx = widget.allBundles.indexOf(b);
                break;
            }
        }
    }

    setState(() => _isNavigatingAway = true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (nextBundle != null) {
        context.pushReplacement('/inventory-invoice-review', extra: {
          'bundle': nextBundle,
          'allBundles': widget.allBundles,
          'currentIndex': nextIdx,
        });
      } else {
        // Auto-sync and navigate to dashboard when no more pending bills
        ref.read(inventoryProvider.notifier).syncAndFinish().then((_) {
          if (mounted) {
            context.go('/');
          }
        });
      }
    });
  }



  Widget _buildActionPanel(double totalAmount) {
    final paidAmount = double.tryParse(_paidAmountController.text) ?? 0.0;
    final balance = (totalAmount - paidAmount).clamp(0.0, double.infinity);
    final hasNext = widget.allBundles.any((b) => !b.isVerified && b.invoiceNumber != widget.bundle.invoiceNumber);

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(top: BorderSide(color: context.borderColor, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Total (Tap to Edit)
              Expanded(
                child: GestureDetector(
                  onTap: () => _showEditTotalDialog(totalAmount),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Bill', style: TextStyle(fontSize: 11, color: context.textSecondaryColor)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text('₹${totalAmount.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          const SizedBox(width: 4),
                          Icon(LucideIcons.pencil, size: 12, color: context.primaryColor.withValues(alpha: 0.6)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Paid Input
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _paidAmountController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  onChanged: (val) {
                    final paid = double.tryParse(val) ?? 0.0;
                    setState(() {
                      _paymentMode = paid >= totalAmount ? 'Cash' : 'Credit';
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Amount Paid',
                    labelStyle: TextStyle(fontSize: 10, color: context.textSecondaryColor),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Balance
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Balance Due', style: TextStyle(fontSize: 11, color: context.textSecondaryColor)),
                  const SizedBox(height: 2),
                  Text('₹${balance.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: balance > 0 ? context.errorColor : context.successColor,
                      )),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Cash', label: Text('Cash')),
                    ButtonSegment(value: 'Credit', label: Text('Credit')),
                  ],
                  selected: {_paymentMode},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _paymentMode = newSelection.first;
                      if (_paymentMode == 'Cash') {
                        _paidAmountController.text = totalAmount.round().toString();
                      } else {
                        _paidAmountController.text = '0';
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _isLoading ? null : () => _saveInvoice(widget.bundle.items, totalAmount),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            hasNext ? 'Save & Next' : 'Save & Finish',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMetadata() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Invoice Date
          Expanded(
            child: GestureDetector(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.borderColor),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.calendar, size: 16, color: context.textSecondaryColor),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bill Date', style: TextStyle(fontSize: 10, color: context.textSecondaryColor)),
                        Text(_dateController.text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Invoice Number
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderColor),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.hash, size: 16, color: context.textSecondaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bill No.', style: TextStyle(fontSize: 10, color: context.textSecondaryColor)),
                        TextField(
                          controller: _invoiceNumberController,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isNavigatingAway) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Saving...', style: TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
    }

    final state = ref.watch(inventoryProvider);
    final providerItemById = { for (final i in state.items) i.id: i };
    
    final providerHasThisInvoice = state.items.any((i) {
      final key = i.invoiceNumber.isNotEmpty
          ? i.invoiceNumber
          : '${i.invoiceDate}_${i.vendorName ?? ''}';
      final invoiceKey = widget.bundle.invoiceNumber.isNotEmpty
          ? widget.bundle.invoiceNumber
          : '${widget.bundle.date}_${widget.bundle.vendorName}';
      return key == invoiceKey;
    });

    final currentItems = widget.bundle.items.where((bundleItem) {
      if (providerHasThisInvoice && !providerItemById.containsKey(bundleItem.id)) {
        return false;
      }
      return true;
    }).map((bundleItem) {
      return providerItemById[bundleItem.id] ?? bundleItem;
    }).toList();

    final sortedItems = List<InventoryItem>.from(currentItems);
    sortedItems.sort((a, b) {
      final aMis = a.amountMismatch.abs() > 1.0;
      final bMis = b.amountMismatch.abs() > 1.0;
      if (aMis && !bMis) return -1;
      if (!aMis && bMis) return 1;
      return a.id.compareTo(b.id);
    });

    final hasPerItemDiscount = sortedItems.any(
      (i) => (i.discAmount ?? 0.0) > 0.01 || (i.discPercent ?? 0.0) > 0.01,
    );

    final nonDiscountAdjTotal = _adjustments.fold<double>(
      0.0,
      (double sum, HeaderAdjustment adj) {
        final type = adj.adjustmentType.toUpperCase();
        if (type == 'ROUND_OFF' || type == 'OTHER') {
          return sum + (adj.amount);
        }
        return sum;
      },
    );

    double baseItemsTotal;
    if (hasPerItemDiscount) {
      baseItemsTotal = sortedItems.fold(0.0, (sum, item) => sum + (item.netAmount ?? item.netBill));
    } else {
      final totalGross = sortedItems.fold(0.0, (sum, item) => sum + (item.grossAmount ?? (item.quantity * item.rate)));
      final headerDiscountAmt = _adjustments.fold<double>(0.0, (double sum, HeaderAdjustment adj) {
        final type = adj.adjustmentType.toUpperCase();
        if (type == 'HEADER_DISCOUNT' || type == 'SCHEME') return sum + adj.amount.abs();
        return sum;
      });
      final totalTaxable = (totalGross - headerDiscountAmt).clamp(0.0, double.infinity);
      final originalTaxableBase = sortedItems.fold<double>(0.0, (sum, item) => sum + (item.taxableAmount ?? item.grossAmount ?? (item.quantity * item.rate)));
      final totalGst = sortedItems.fold<double>(0.0, (sum, item) => sum + (item.cgstAmount ?? 0.0) + (item.sgstAmount ?? 0.0) + (item.igstAmount ?? 0.0));
      final scaledGst = originalTaxableBase > 0 ? totalGst * (totalTaxable / originalTaxableBase) : totalGst;
      baseItemsTotal = totalTaxable + scaledGst;
    }

    double totalAmount = baseItemsTotal + nonDiscountAdjTotal;
    if (_targetTotal != null) {
        final diff = _targetTotal! - totalAmount;
        if (diff.abs() > 0.001) {
            final idx = _adjustments.indexWhere((HeaderAdjustment a) => a.description == 'Manual Correction');
            if (idx != -1) {
                _adjustments[idx] = _adjustments[idx].copyWith(amount: _adjustments[idx].amount + diff);
            } else {
                _adjustments.add(HeaderAdjustment(adjustmentType: 'OTHER', amount: diff, description: 'Manual Correction'));
            }
            totalAmount = _targetTotal!;
        }
    }

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leadingWidth: 40,
        titleSpacing: 0,
        title: SupplierAutocompleteField(
          initialValue: _vendorNameController.text,
          label: 'Supplier Name',
          compact: true,
          showOnFocus: true,
          onSaved: (val) => _vendorNameController.text = val,
          onSupplierSelected: (s) {
            setState(() => _vendorNameController.text = s.vendorName);
            HapticFeedback.mediumImpact();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.trash2, color: Colors.red, size: 20),
            onPressed: _isLoading ? null : () => _deleteInvoice(sortedItems),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Image Section
          if (widget.bundle.receiptLink.isNotEmpty)
            GestureDetector(
              onTap: () => _showFullImage(widget.bundle.receiptLink),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                height: 150,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'inv_img_${widget.bundle.invoiceNumber}',
                        child: UniversalImage(
                          path: widget.bundle.receiptLink,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                        ),
                      ),
                      Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.1))),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                          child: const Icon(LucideIcons.maximize, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          _buildCompactMetadata(),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Line Items', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: context.textColor)),
                    const Spacer(),
                    Text('${sortedItems.length} items', style: TextStyle(fontSize: 12, color: context.textSecondaryColor, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                ...sortedItems.map((item) => InvoiceItemCard(
                  item: item,
                  onEdit: () {
                    EditItemModal.show(context, item, (updatedItem) {
                      ref.read(inventoryProvider.notifier).updateItem(updatedItem.id, updatedItem.toJson());
                    });
                  },
                  onDelete: () => _deleteItem(item),
                )),
                HeaderAdjustmentsSection(
                  adjustments: _adjustments,
                  hasPerItemDiscount: hasPerItemDiscount,
                  onEdit: _showEditAdjustmentDialog,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
          _buildActionPanel(totalAmount),
        ],
      ),
    );
  }
}
