import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/purchase_orders/domain/models/purchase_order_models.dart';
import 'package:mobile/features/purchase_orders/presentation/providers/purchase_order_provider.dart';
import 'package:mobile/shared/widgets/app_toast.dart';
import 'package:printing/printing.dart';
import 'package:mobile/features/purchase_orders/utils/pdf_generator.dart';

class PurchaseOrdersPage extends ConsumerStatefulWidget {
  const PurchaseOrdersPage({super.key});

  @override
  ConsumerState<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends ConsumerState<PurchaseOrdersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    // Load history when this page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(purchaseOrderProvider.notifier).loadHistory();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final state = ref.watch(purchaseOrderProvider);

    // Listen for success and show whatsapp share sheet
    ref.listen<PurchaseOrderState>(purchaseOrderProvider, (prev, next) {
      if (next.successPoNumber != null &&
          prev?.successPoNumber != next.successPoNumber) {
        _showPoSuccessSheet(next.successPoNumber!);
        ref.read(purchaseOrderProvider.notifier).clearSuccess();
      }
      if (next.error != null && prev?.error != next.error) {
        AppToast.showError(context, next.error!);
        ref.read(purchaseOrderProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Purchase Orders',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            Text('Draft basket & order history',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.normal)),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Draft'),
                  if (state.hasDraftItems) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${state.draftCount}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10)),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'History'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () {
              HapticFeedback.lightImpact();
              context.pushNamed('create-po');
            },
            tooltip: 'Add Item',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _DraftTab(currency: currency),
          _HistoryTab(currency: currency),
        ],
      ),
    );
  }

  void _showPoSuccessSheet(String poNumber) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PoSuccessSheet(poNumber: poNumber),
    );
  }
}

// ─── Draft Tab ────────────────────────────────────────────────────────────────

class _DraftTab extends ConsumerWidget {
  final NumberFormat currency;
  const _DraftTab({required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(purchaseOrderProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.draft.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.shoppingCart,
                size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text('Draft is empty',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            const Text('Add items from Low Stock Alerts\nor the + button below',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Items list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            itemCount: state.draft.items.length,
            itemBuilder: (context, i) {
              final item = state.draft.items[i];
              return _DraftItemCard(item: item, currency: currency);
            },
          ),
        ),

        // Cart Bottom Bar
        if (state.hasDraftItems)
          _CartBottomBar(
            currency: currency,
            onPlaceOrder: () =>
                _showProceedSheet(context, ref, state.suppliers),
          ),
      ],
    );
  }

  void _showProceedSheet(
      BuildContext context, WidgetRef ref, List<String> suppliers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProceedPoSheet(suppliers: suppliers),
    );
  }
}

// ─── Cart Bottom Bar ──────────────────────────────────────────────────────────

class _CartBottomBar extends ConsumerWidget {
  final NumberFormat currency;
  final VoidCallback onPlaceOrder;

  const _CartBottomBar({
    required this.currency,
    required this.onPlaceOrder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(purchaseOrderProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Total (${state.draft.totalItems} items)',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
                  Text(currency.format(state.draft.totalEstimatedCost),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: state.hasDraftItems ? onPlaceOrder : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Place Order',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Icon(LucideIcons.arrowRight, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Draft Item Card ──────────────────────────────────────────────────────────

class _DraftItemCard extends ConsumerWidget {
  final DraftPoItem item;
  final NumberFormat currency;
  const _DraftItemCard({required this.item, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priorityColor = _priorityColor(item.priority);

    return Dismissible(
      key: Key(item.partNumber),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(LucideIcons.trash2, color: AppTheme.error),
      ),
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        await ref
            .read(purchaseOrderProvider.notifier)
            .removeItem(item.partNumber);
        return false; // We handle UI optimistically in provider
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Priority badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(item.priority,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: priorityColor)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item.itemName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(item.partNumber,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Stock info
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stock: ${item.currentStock.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                    if (item.unitValue != null)
                      Text(
                          currency
                              .format((item.unitValue ?? 0) * item.reorderQty),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.trash2,
                          size: 18, color: AppTheme.error),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        ref
                            .read(purchaseOrderProvider.notifier)
                            .removeItem(item.partNumber);
                      },
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      constraints: const BoxConstraints(),
                    ),
                    // Qty stepper
                    _QtyStepper(
                      value: item.reorderQty,
                      onChanged: (qty) {
                        ref
                            .read(purchaseOrderProvider.notifier)
                            .updateQty(item.partNumber, qty);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'P0':
        return AppTheme.error;
      case 'P1':
        return AppTheme.warning;
      case 'P2':
        return AppTheme.primary;
      default:
        return AppTheme.textSecondary;
    }
  }
}

// ─── Qty Stepper ─────────────────────────────────────────────────────────────

class _QtyStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _QtyStepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _StepBtn(
            icon: LucideIcons.minus,
            onTap: value > 1 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 36,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          _StepBtn(
            icon: LucideIcons.plus,
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(icon,
            size: 14,
            color: onTap != null ? AppTheme.primary : AppTheme.textSecondary),
      ),
    );
  }
}

// ─── Proceed to PO Sheet ──────────────────────────────────────────────────────

class _ProceedPoSheet extends ConsumerStatefulWidget {
  final List<String> suppliers;
  const _ProceedPoSheet({required this.suppliers});

  @override
  ConsumerState<_ProceedPoSheet> createState() => _ProceedPoSheetState();
}

class _ProceedPoSheetState extends ConsumerState<_ProceedPoSheet> {
  final _notesCtrl = TextEditingController();
  final _customSupplierCtrl = TextEditingController();

  @override
  void dispose() {
    _notesCtrl.dispose();
    _customSupplierCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isProceeding =
        ref.watch(purchaseOrderProvider.select((s) => s.isProceeding));

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Finalise Purchase Order',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('This creates a PO and shares it via WhatsApp',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 20),

            // Supplier
            const Text('Supplier Name',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return widget.suppliers;
                }
                return widget.suppliers.where((String option) {
                  return option
                      .toLowerCase()
                      .contains(textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selection) {
                _customSupplierCtrl.text = selection;
              },
              // fieldViewBuilder to style the text field
              fieldViewBuilder: (context, textEditingController, focusNode,
                  onFieldSubmitted) {
                // Keep the underlying controller in sync so we can easily get the text on submit
                textEditingController.addListener(() {
                  _customSupplierCtrl.text = textEditingController.text;
                });
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Select or type supplier...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    suffixIcon: const Icon(LucideIcons.chevronDown, size: 20),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            // Notes
            const Text('Notes (optional)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Delivery instructions, urgency, etc.',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isProceeding ? null : _onGenerate,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: isProceeding
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Generate PO',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onGenerate() async {
    HapticFeedback.mediumImpact();
    final supplier = _customSupplierCtrl.text.trim().isEmpty
        ? null
        : _customSupplierCtrl.text.trim();

    final request = ProceedToPORequest(
      supplierName: supplier,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    if (mounted) Navigator.pop(context);
    await ref.read(purchaseOrderProvider.notifier).proceedToPO(request);
  }
}

// ─── PO Success + WhatsApp Share Sheet ───────────────────────────────────────

class _PoSuccessSheet extends ConsumerWidget {
  final String poNumber;
  const _PoSuccessSheet({required this.poNumber});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.checkCircle,
                color: AppTheme.success, size: 28),
          ),
          const SizedBox(height: 16),
          const Text('Purchase Order Created!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('PO Number: $poNumber',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary)),
          const SizedBox(height: 8),
          const Text(
              'Your PO has been saved. Share it with your supplier as a PDF.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(LucideIcons.fileText, size: 18),
              label: const Text('Send PDF',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  final history = ref.read(purchaseOrderProvider).history;
                  final po = history.firstWhere((p) => p.poNumber == poNumber);

                  final details = await ref
                      .read(purchaseOrderRepositoryProvider)
                      .getPurchaseOrderDetails(po.id);

                  if (details != null) {
                    final bytes = await MaterialRequestPdfGenerator.generate(
                        details, 'Adnak',
                        notes: po.notes);
                    await Printing.sharePdf(
                        bytes: bytes, filename: 'PO_${po.poNumber}.pdf');
                  } else {
                    if (context.mounted) {
                      AppToast.showError(context, 'Failed to generate PDF');
                    }
                  }
                } catch (e) {
                  debugPrint('PDF generation error: $e');
                }
              },
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }
}

// ─── History Tab ──────────────────────────────────────────────────────────────

class _HistoryTab extends ConsumerWidget {
  final NumberFormat currency;
  const _HistoryTab({required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(purchaseOrderProvider.select((s) => s.history));

    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.clipboardList,
                size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text('No purchase orders yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, i) {
        final po = history[i];
        return _PoHistoryCard(po: po, currency: currency);
      },
    );
  }
}

class _PoHistoryCard extends ConsumerStatefulWidget {
  final PurchaseOrder po;
  final NumberFormat currency;
  const _PoHistoryCard({required this.po, required this.currency});

  @override
  ConsumerState<_PoHistoryCard> createState() => _PoHistoryCardState();
}

class _PoHistoryCardState extends ConsumerState<_PoHistoryCard> {
  bool _expanded = false;

  Color _statusColor(String s) {
    switch (s) {
      case 'received':
        return AppTheme.success;
      case 'cancelled':
        return AppTheme.error;
      default:
        return AppTheme.primary;
    }
  }

  Future<void> _reshareWhatsApp() async {
    HapticFeedback.lightImpact();
    final po = widget.po;

    final details = await ref
        .read(purchaseOrderRepositoryProvider)
        .getPurchaseOrderDetails(po.id);

    if (details != null) {
      final bytes = await MaterialRequestPdfGenerator.generate(details, 'Adnak',
          notes: po.notes);
      await Printing.sharePdf(bytes: bytes, filename: 'PO_${po.poNumber}.pdf');
    } else {
      if (mounted) {
        AppToast.showError(context, 'Failed to generate PDF for sharing');
      }
    }
  }

  Future<void> _deletePo() async {
    HapticFeedback.lightImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Purchase Order',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text(
            'Are you sure you want to delete ${widget.po.poNumber}? This action is irreversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (mounted) {
      final success =
          await ref.read(purchaseOrderProvider.notifier).deletePO(widget.po.id);
      if (mounted) {
        if (success) {
          AppToast.showSuccess(context, 'Deleted ${widget.po.poNumber}');
        } else {
          AppToast.showError(context, 'Failed to delete PO');
        }
      }
    }
  }

  void _viewDetails() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _PoDetailsSheet(poId: widget.po.id, poNumber: widget.po.poNumber),
    );
  }

  @override
  Widget build(BuildContext context) {
    final po = widget.po;
    final statusColor = _statusColor(po.status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _expanded
              ? AppTheme.primary.withValues(alpha: 0.3)
              : AppTheme.border,
        ),
        boxShadow: _expanded
            ? [
                BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ]
            : [],
      ),
      child: Column(
        children: [
          // Main Card Row (tappable)
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _expanded = !_expanded);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.fileText,
                        color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(po.poNumber,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(
                            '${po.supplierName ?? 'No supplier'} · ${po.totalItems} items',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
                        Text(po.poDate,
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (po.totalEstimatedCost > 0)
                        Text(widget.currency.format(po.totalEstimatedCost),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.primary)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(po.statusLabel,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: statusColor)),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        _expanded
                            ? LucideIcons.chevronUp
                            : LucideIcons.chevronDown,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded Action Row
          if (_expanded) ...[
            const Divider(height: 1, indent: 14, endIndent: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: LucideIcons.list,
                          label: 'Details',
                          color: const Color(0xFF0EA5E9),
                          onTap: _viewDetails,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          icon: FontAwesomeIcons.whatsapp,
                          label: 'WhatsApp',
                          color: const Color(0xFF25D366),
                          onTap: _reshareWhatsApp,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          icon: LucideIcons.trash2,
                          label: 'Delete',
                          color: AppTheme.error,
                          onTap: _deletePo,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            if (icon != null) Icon(icon, size: 16, color: color),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

// ─── PO Details Sheet ─────────────────────────────────────────────────────────

class _PoDetailsSheet extends ConsumerStatefulWidget {
  final String poId;
  final String poNumber;

  const _PoDetailsSheet({required this.poId, required this.poNumber});

  @override
  ConsumerState<_PoDetailsSheet> createState() => _PoDetailsSheetState();
}

class _PoDetailsSheetState extends ConsumerState<_PoDetailsSheet> {
  PurchaseOrderDetail? _details;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final res = await ref
        .read(purchaseOrderRepositoryProvider)
        .getPurchaseOrderDetails(widget.poId);
    if (mounted) {
      setState(() {
        _details = res;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Items for ${widget.poNumber}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _details == null
                    ? const Center(
                        child: Text('Failed to load details',
                            style: TextStyle(color: AppTheme.error)))
                    : _details!.items.isEmpty
                        ? const Center(
                            child: Text('No items found.',
                                style:
                                    TextStyle(color: AppTheme.textSecondary)))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _details!.items.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, i) {
                              final item = _details!.items[i];
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'x${item.orderedQty}',
                                        style: const TextStyle(
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(item.itemName,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          Text('Part: ${item.partNumber}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppTheme.textSecondary)),
                                        ],
                                      ),
                                    ),
                                    if (item.unitValue != null)
                                      Text(
                                        NumberFormat.currency(
                                                locale: 'en_IN',
                                                symbol: 'Rs.',
                                                decimalDigits: 0)
                                            .format(item.unitValue! *
                                                item.orderedQty),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
