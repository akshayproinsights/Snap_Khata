import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';
import 'package:mobile/features/inventory/presentation/inventory_review_page.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:mobile/shared/widgets/app_toast.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ItemDetailCtrl {
  final int rowId;
  final TextEditingController descCtrl;
  final TextEditingController partCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController rateCtrl;
  final TextEditingController amtCtrl;

  ItemDetailCtrl({
    required this.rowId,
    required this.descCtrl,
    required this.partCtrl,
    required this.qtyCtrl,
    required this.rateCtrl,
    required this.amtCtrl,
  });

  void dispose() {
    descCtrl.dispose();
    partCtrl.dispose();
    qtyCtrl.dispose();
    rateCtrl.dispose();
    amtCtrl.dispose();
  }
}

class VendorDeliveryDetailPage extends ConsumerStatefulWidget {
  final InventoryInvoiceBundle bundle;

  const VendorDeliveryDetailPage({super.key, required this.bundle});

  @override
  ConsumerState<VendorDeliveryDetailPage> createState() =>
      _VendorDeliveryDetailPageState();
}

class _VendorDeliveryDetailPageState
    extends ConsumerState<VendorDeliveryDetailPage> {
  bool isEditing = false;
  bool isSaving = false;

  late TextEditingController invoiceNumberCtrl;
  late TextEditingController dateCtrl;
  late TextEditingController vendorCtrl;

  List<ItemDetailCtrl> itemCtrls = [];

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    invoiceNumberCtrl =
        TextEditingController(text: widget.bundle.invoiceNumber);

    String initialDate = widget.bundle.date;
    try {
      final parsed = DateTime.tryParse(initialDate);
      if (parsed != null) {
        initialDate = DateFormat('dd/MM/yyyy').format(parsed);
      }
    } catch (_) {}
    dateCtrl = TextEditingController(text: initialDate);

    vendorCtrl = TextEditingController(text: widget.bundle.vendorName);

    itemCtrls = widget.bundle.items.map((item) {
      return ItemDetailCtrl(
        rowId: item.id,
        descCtrl: TextEditingController(text: item.description),
        partCtrl: TextEditingController(text: item.partNumber),
        qtyCtrl: TextEditingController(
            text: item.qty == item.qty.roundToDouble()
                ? item.qty.toInt().toString()
                : item.qty.toStringAsFixed(1)),
        rateCtrl: TextEditingController(text: item.rate.toString()),
        amtCtrl: TextEditingController(text: item.netBill.toString()),
      );
    }).toList();
  }

  @override
  void dispose() {
    invoiceNumberCtrl.dispose();
    dateCtrl.dispose();
    vendorCtrl.dispose();
    for (var ctrl in itemCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return NumberFormat('#,##0', 'en_IN').format(amount);
    }
    return NumberFormat('#,##0.00', 'en_IN').format(amount);
  }

  Future<void> _saveChanges() async {
    setState(() => isSaving = true);
    final notifier = ref.read(inventoryProvider.notifier);

    try {
      for (int i = 0; i < widget.bundle.items.length; i++) {
        final item = widget.bundle.items[i];
        final ctrl = itemCtrls[i];

        final double qty = double.tryParse(ctrl.qtyCtrl.text) ?? item.qty;
        final double rate = double.tryParse(ctrl.rateCtrl.text) ?? item.rate;
        final double amt = double.tryParse(ctrl.amtCtrl.text) ?? item.netBill;

        final calculatedAmount = qty * rate;
        final mismatch = calculatedAmount - amt;
        final isMismatch = mismatch.abs() > 1.0;

        final updateMap = {
          'invoice_number': invoiceNumberCtrl.text,
          'date': dateCtrl.text,
          'vendor_name': vendorCtrl.text,
          'description': ctrl.descCtrl.text,
          'part_number': ctrl.partCtrl.text,
          'qty': qty,
          'rate': rate,
          'net_bill': amt,
          'amount_mismatch': isMismatch,
          'verification_status': 'Done',
        };

        if (item.invoiceNumber != invoiceNumberCtrl.text ||
            item.invoiceDate != dateCtrl.text ||
            item.vendorName != vendorCtrl.text ||
            item.description != ctrl.descCtrl.text ||
            item.partNumber != ctrl.partCtrl.text ||
            item.qty != qty ||
            item.rate != rate ||
            item.netBill != amt ||
            item.verificationStatus != 'Done') {
          await notifier.updateItem(item.id, updateMap);
        }
      }

      await notifier.refresh();

      if (mounted) {
        AppToast.showSuccess(context, 'Bill verified & saved successfully');
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to save changes');
      }
    }

    setState(() {
      isSaving = false;
      isEditing = false;
    });
  }

  void _showReceiptDialog(BuildContext context) {
    if (widget.bundle.receiptLink.isEmpty || widget.bundle.receiptLink == 'null') return;
    
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
              child: CachedNetworkImage(
                imageUrl: widget.bundle.receiptLink,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
                errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLink = widget.bundle.receiptLink.isNotEmpty &&
        widget.bundle.receiptLink != 'null';

    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final totalAmount = widget.bundle.totalAmount;

    return Scaffold(
      backgroundColor: AppTheme.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Bill Details',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        actions: [
          if (isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (isEditing)
            TextButton(
              onPressed: _saveChanges,
              child: const Text('Save',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primary)),
            )
          else
            IconButton(
              icon: const Icon(LucideIcons.edit, color: AppTheme.primary),
              tooltip: 'Edit Details',
              onPressed: () => setState(() => isEditing = true),
            ),
          if (hasLink && !isEditing)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(LucideIcons.eye, color: AppTheme.primary),
                tooltip: 'View Original Receipt',
                onPressed: () => _showReceiptDialog(context),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildVendorCard(),
            const SizedBox(height: 12),
            _buildItemsSection(),
          ],
        ),
      ),
      bottomNavigationBar:
          _buildStickyBottomBar(totalAmount, keyboardInset),
    );
  }

  Widget _buildStickyBottomBar(double grandTotal, double keyboardInset) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              offset: const Offset(0, -4),
              blurRadius: 20,
            )
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Bill Amount',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text('₹${_formatAmount(grandTotal)}',
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.5)),
                    ],
                  ),
                  if (!widget.bundle.isVerified)
                    FilledButton.icon(
                      onPressed: isEditing ? _saveChanges : () => setState(() => isEditing = true),
                      icon: Icon(isEditing ? LucideIcons.save : LucideIcons.checkCircle, size: 18),
                      label: Text(isEditing ? 'Save & Verify' : 'Verify'),
                      style: FilledButton.styleFrom(
                        backgroundColor: isEditing ? AppTheme.primary : Colors.orange.shade600,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.green.shade200,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.checkCircle2,
                              size: 18, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Text('Verified',
                              style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                        ],
                      ),
                    )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1. Header Card (Receipt No & Date)
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Invoice No
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Invoice Number',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                if (isEditing)
                  _buildTextField(invoiceNumberCtrl, 'Invoice No')
                else
                  Text(
                      widget.bundle.invoiceNumber.isNotEmpty
                          ? '#${widget.bundle.invoiceNumber}'
                          : 'N/A',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppTheme.textPrimary)),
              ],
            ),
          ),
          // Divider
          Container(
            width: 1,
            height: 40,
            color: Colors.grey.shade200,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          // Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Date',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                if (isEditing)
                  _buildTextField(dateCtrl, 'Date')
                else
                  Text(widget.bundle.date.isNotEmpty ? widget.bundle.date : 'N/A',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppTheme.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. Vendor Card
  // ─────────────────────────────────────────────────────────────
  Widget _buildVendorCard() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vendor Details',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.04),
              border:
                  Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: const Icon(LucideIcons.store, color: AppTheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Vendor Name',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      if (isEditing)
                        _buildTextField(vendorCtrl, 'Vendor Name')
                      else
                        Text(
                            widget.bundle.vendorName.isNotEmpty
                                ? widget.bundle.vendorName
                                : 'Unknown Vendor',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary),
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint,
      {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.primary)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3. Items Section
  // ─────────────────────────────────────────────────────────────
  Widget _buildItemsSection() {
    if (isEditing) {
      return Container(
        color: Colors.white,
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildItemsHeader(),
            ...widget.bundle.items.asMap().entries.map((e) {
              return _ItemRow(
                index: e.key + 1,
                item: e.value,
                ctrl: itemCtrls[e.key],
                isEditing: true,
              );
            }),
          ],
        ),
      );
    }

    return Container(
      color: Colors.white,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildItemsHeader(),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.bundle.items.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 20, endIndent: 20),
            itemBuilder: (context, index) {
              return _ItemRow(
                index: index + 1,
                item: widget.bundle.items[index],
                ctrl: itemCtrls[index],
                isEditing: false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItemsHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          Text('Item Details',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          Spacer(),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final int index;
  final InventoryItem item;
  final ItemDetailCtrl ctrl;
  final bool isEditing;

  const _ItemRow({
    required this.index,
    required this.item,
    required this.ctrl,
    required this.isEditing,
  });

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return NumberFormat('#,##0', 'en_IN').format(amount);
    }
    return NumberFormat('#,##0.00', 'en_IN').format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final hasMismatch = item.amountMismatch.abs() > 1.0;

    if (isEditing) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('$index',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary)),
                ),
                const SizedBox(width: 12),
                Expanded(
                    flex: 3,
                    child: _buildTextField(ctrl.descCtrl, 'Description')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Qty',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      _buildTextField(ctrl.qtyCtrl, 'Qty', isNumber: true),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Rate',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      _buildTextField(ctrl.rateCtrl, 'Rate', isNumber: true),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Amount',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      _buildTextField(ctrl.amtCtrl, 'Amount', isNumber: true),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$index',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.description.isNotEmpty ? item.description : item.partNumber,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                        '${item.qty == item.qty.roundToDouble() ? item.qty.toInt() : item.qty.toStringAsFixed(2)} x ₹${_formatAmount(item.rate)}',
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary)),
                    if (hasMismatch)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Mismatch',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFEF4444))),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
               Text('₹${_formatAmount(item.netBill)}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
               if (hasMismatch) ...[
                 const SizedBox(height: 2),
                 const Text('+Tax/Fees', style: TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.w600)),
               ]
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint,
      {bool isNumber = false}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 36),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          isDense: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppTheme.primary)),
        ),
      ),
    );
  }
}
