import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/shared/domain/models/invoice_group.dart';
import 'package:mobile/features/verified/domain/models/verified_models.dart';
import 'package:mobile/features/verified/presentation/providers/verified_provider.dart';

class OrderDetailPage extends ConsumerStatefulWidget {
  final InvoiceGroup group;

  const OrderDetailPage({super.key, required this.group});

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class ItemDetailCtrl {
  final String rowId;
  final TextEditingController descCtrl;
  final TextEditingController typeCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController rateCtrl;
  final TextEditingController amtCtrl;

  ItemDetailCtrl({
    required this.rowId,
    required this.descCtrl,
    required this.typeCtrl,
    required this.qtyCtrl,
    required this.rateCtrl,
    required this.amtCtrl,
  });

  void dispose() {
    descCtrl.dispose();
    typeCtrl.dispose();
    qtyCtrl.dispose();
    rateCtrl.dispose();
    amtCtrl.dispose();
  }
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  bool isEditing = false;
  bool isSaving = false;

  late TextEditingController receiptCtrl;
  late TextEditingController dateCtrl;
  late TextEditingController customerCtrl;
  late TextEditingController vehicleCtrl;

  List<ItemDetailCtrl> itemCtrls = [];

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    receiptCtrl = TextEditingController(text: widget.group.receiptNumber);
    dateCtrl = TextEditingController(text: widget.group.date);
    customerCtrl = TextEditingController(text: widget.group.customerName);
    vehicleCtrl = TextEditingController(text: widget.group.vehicleNumber);

    itemCtrls = widget.group.items.map((item) {
      return ItemDetailCtrl(
        rowId: item.rowId,
        descCtrl: TextEditingController(text: item.description),
        typeCtrl: TextEditingController(text: item.type),
        qtyCtrl: TextEditingController(
            text: item.quantity == item.quantity.roundToDouble()
                ? item.quantity.toInt().toString()
                : item.quantity.toStringAsFixed(1)),
        rateCtrl: TextEditingController(text: item.rate.toString()),
        amtCtrl: TextEditingController(text: item.amount.toString()),
      );
    }).toList();
  }

  @override
  void dispose() {
    receiptCtrl.dispose();
    dateCtrl.dispose();
    customerCtrl.dispose();
    vehicleCtrl.dispose();
    for (var ctrl in itemCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => isSaving = true);
    final notifier = ref.read(verifiedProvider.notifier);

    double newTotal = 0;

    for (int i = 0; i < widget.group.items.length; i++) {
      final item = widget.group.items[i];
      final ctrl = itemCtrls[i];

      final double qty = double.tryParse(ctrl.qtyCtrl.text) ?? item.quantity;
      final double rate = double.tryParse(ctrl.rateCtrl.text) ?? item.rate;
      final double amt = double.tryParse(ctrl.amtCtrl.text) ?? item.amount;

      final updatedItem = item.copyWith(
        receiptNumber: receiptCtrl.text,
        date: dateCtrl.text,
        customerName: customerCtrl.text,
        vehicleNumber: vehicleCtrl.text,
        description: ctrl.descCtrl.text,
        type: ctrl.typeCtrl.text,
        quantity: qty,
        rate: rate,
        amount: amt,
      );

      await notifier.updateRecord(updatedItem);

      widget.group.items[i] = updatedItem;
      newTotal += amt;
    }

    widget.group.receiptNumber = receiptCtrl.text;
    widget.group.date = dateCtrl.text;
    widget.group.customerName = customerCtrl.text;
    widget.group.vehicleNumber = vehicleCtrl.text;
    widget.group.totalAmount = newTotal;

    setState(() {
      isSaving = false;
      isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasLink = widget.group.receiptLink.isNotEmpty &&
        widget.group.receiptLink != 'null';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Order Details',
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
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildCustomerCard(),
            const SizedBox(height: 12),
            _buildItemsSection(),
            const SizedBox(height: 12),
            _buildTotalsCard(),
          ],
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
          // Receipt No
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Receipt Number',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                if (isEditing)
                  _buildTextField(receiptCtrl, 'Receipt No')
                else
                  Text(
                      widget.group.receiptNumber.isNotEmpty
                          ? '#${widget.group.receiptNumber}'
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
                  Text(_formattedDate(),
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

  String _formattedDate() {
    final dt = DateTime.tryParse(widget.group.date) ?? DateTime.now();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  // ─────────────────────────────────────────────────────────────
  // 2. Customer Card
  // ─────────────────────────────────────────────────────────────
  Widget _buildCustomerCard() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Customer Details',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.04),
              border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppTheme.primary.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: const Icon(LucideIcons.user, color: AppTheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Customer Name',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 4),
                            if (isEditing)
                              _buildTextField(customerCtrl, 'Name')
                            else
                              Text(
                                  widget.group.customerName.isNotEmpty
                                      ? widget.group.customerName
                                      : 'Unknown',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary),
                                  overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Vehicle No.',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 4),
                            if (isEditing)
                              _buildTextField(vehicleCtrl, 'Vehicle')
                            else
                              Text(
                                  widget.group.vehicleNumber.isNotEmpty
                                      ? widget.group.vehicleNumber
                                      : '-',
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
            ...widget.group.items.asMap().entries.map((e) {
              return _ItemRow(
                index: e.key + 1,
                item: e.value,
                ctrl: itemCtrls[e.key],
                isLast: e.key == widget.group.items.length - 1,
                isEditing: true,
              );
            }),
          ],
        ),
      );
    }

    final parts = widget.group.items
        .where((i) => i.type.toUpperCase().contains('PART'))
        .toList();
    final servicing = widget.group.items
        .where((i) =>
            i.type.toUpperCase().contains('LABOUR') ||
            i.type.toUpperCase().contains('SERVICE'))
        .toList();
    final others = widget.group.items
        .where((i) => !parts.contains(i) && !servicing.contains(i))
        .toList();

    return Container(
      color: Colors.white,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildItemsHeader(),
          if (parts.isNotEmpty)
            _buildCategoryGroup(
                'Spare Parts', parts, LucideIcons.package2, Colors.blue),
          if (servicing.isNotEmpty)
            _buildCategoryGroup(
                'Servicing', servicing, LucideIcons.wrench, Colors.orange),
          if (others.isNotEmpty)
            _buildCategoryGroup(
                'Other Items', others, LucideIcons.box, Colors.grey),
          if (widget.group.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                  child: Text('No items found',
                      style: TextStyle(color: AppTheme.textSecondary))),
            ),
        ],
      ),
    );
  }

  Widget _buildItemsHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Row(
        children: [
          Icon(LucideIcons.shoppingBag, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Ordered Items',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCategoryGroup(String title, List<VerifiedInvoice> items,
      IconData icon, MaterialColor color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: color.shade50,
                    borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, size: 14, color: color.shade700),
              ),
              const SizedBox(width: 8),
              Text(title.toUpperCase(),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: color.shade700,
                      letterSpacing: 1.0)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10)),
                child: Text('${items.length}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        ...items.asMap().entries.map((entry) {
          final idx = widget.group.items.indexOf(entry.value);
          return _ItemRow(
            index: idx + 1,
            item: entry.value,
            ctrl: itemCtrls[idx],
            isLast: entry.key == items.length - 1,
            isEditing: false,
          );
        }),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 4. Totals & Receipt
  // ─────────────────────────────────────────────────────────────
  Widget _buildTotalsCard() {
    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final hasLink = widget.group.receiptLink.isNotEmpty &&
        widget.group.receiptLink != 'null';

    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary)),
              Text(
                currencyFormat.format(widget.group.totalAmount),
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary),
              ),
            ],
          ),
          if (hasLink && !isEditing) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(),
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _showReceiptDialog(context),
                icon: const Icon(LucideIcons.eye),
                label: const Text('View Original Receipt',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ]
        ],
      ),
    );
  }

  void _showReceiptDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                widget.group.receiptLink,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  padding: const EdgeInsets.all(32),
                  color: AppTheme.surface,
                  child: const Text('Failed to load receipt image.'),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.xCircle,
                  color: Colors.white, size: 32),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final int index;
  final VerifiedInvoice item;
  final ItemDetailCtrl ctrl;
  final bool isLast;
  final bool isEditing;

  const _ItemRow({
    required this.index,
    required this.item,
    required this.ctrl,
    required this.isLast,
    required this.isEditing,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: isLast ? Colors.transparent : Colors.grey.shade200)),
      ),
      child: isEditing ? _buildEditMode() : _buildViewMode(currencyFormat),
    );
  }

  Widget _buildViewMode(NumberFormat currencyFormat) {
    final qtyStr = item.quantity == item.quantity.roundToDouble()
        ? item.quantity.toInt().toString()
        : item.quantity.toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIndexBadge(),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                  item.description.isNotEmpty ? item.description : 'Unknown',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.textPrimary)),
            ),
            const SizedBox(width: 8),
            Text(currencyFormat.format(item.amount),
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppTheme.textPrimary)),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4)),
                child: Text('${item.type} ',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
              ),
              const SizedBox(width: 8),
              Text(
                '$qtyStr  x  ${currencyFormat.format(item.rate)}',
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildIndexBadge(),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(ctrl.descCtrl, 'Description')),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Row(
            children: [
              Expanded(flex: 2, child: _buildTextField(ctrl.typeCtrl, 'Type')),
              const SizedBox(width: 8),
              Expanded(
                  flex: 1,
                  child: _buildTextField(ctrl.qtyCtrl, 'Qty', isNumber: true)),
              const SizedBox(width: 8),
              Expanded(
                  flex: 2,
                  child:
                      _buildTextField(ctrl.rateCtrl, 'Rate', isNumber: true)),
              const SizedBox(width: 8),
              Expanded(
                  flex: 2,
                  child:
                      _buildTextField(ctrl.amtCtrl, 'Amount', isNumber: true)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIndexBadge() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text('#$index',
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                fontSize: 10)),
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
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
    );
  }
}
