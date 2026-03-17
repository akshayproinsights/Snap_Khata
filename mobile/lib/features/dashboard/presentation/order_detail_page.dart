import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/shared/domain/models/invoice_group.dart';
import 'package:mobile/features/verified/domain/models/verified_models.dart';
import 'package:mobile/features/verified/presentation/providers/verified_provider.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mobile/core/utils/whatsapp_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/features/shared/presentation/widgets/payment_summary_card.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';

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

  // GST State
  GstMode _gstMode = GstMode.none;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadPersistedSettings();
  }



  Future<void> _loadPersistedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final receipt = widget.group.receiptNumber;

    final savedMode = prefs.getString('gst_mode_order_$receipt');
    if (savedMode != null && mounted) {
      setState(() {
        _gstMode = GstMode.values.firstWhere(
          (e) => e.name == savedMode,
          orElse: () => GstMode.none,
        );
      });
    }
  }

  Future<void> _saveGstMode(GstMode mode) async {
    setState(() => _gstMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'gst_mode_order_${widget.group.receiptNumber}', mode.name);
  }

  double _partsSubtotal(InvoiceGroup group) => group.items
      .where((i) {
        final type = i.type.toUpperCase();
        return !type.contains('LABOR') && !type.contains('LABOUR') && !type.contains('SERVICE');
      })
      .fold(0.0, (s, i) => s + i.amount);

  double _laborSubtotal(InvoiceGroup group) => group.items
      .where((i) {
        final type = i.type.toUpperCase();
        return type.contains('LABOR') || type.contains('LABOUR') || type.contains('SERVICE');
      })
      .fold(0.0, (s, i) => s + i.amount);

  double _gstAmount(double partsSubtotal) {
    if (_gstMode == GstMode.excluded) return partsSubtotal * 0.18;
    if (_gstMode == GstMode.included) return partsSubtotal * 18 / 118;
    return 0;
  }

  double _totalAfterGst(InvoiceGroup group) {
    final parts = _partsSubtotal(group);
    final labor = _laborSubtotal(group);
    if (_gstMode == GstMode.excluded) return parts + _gstAmount(parts) + labor;
    return parts + labor;
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
          if (!isEditing)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const FaIcon(FontAwesomeIcons.whatsapp,
                    color: AppTheme.primary),
                tooltip: 'Share Receipt on WhatsApp',
                onPressed: () async {
                  HapticFeedback.lightImpact();

                  final gstParam = _gstMode == GstMode.none
                      ? ''
                      : '&gst_mode=${_gstMode.name}';

                  final authState = ref.read(authProvider);
                  final usernameParam = authState.user?.username != null
                      ? '&u=${authState.user!.username}'
                      : '';

                  final link =
                      'https://mydigientry.com/receipt.html?id=${widget.group.receiptNumber}$gstParam$usernameParam';

                  final customerNameMsg = widget
                              .group.customerName.isNotEmpty &&
                          widget.group.customerName.toLowerCase() != 'unknown'
                      ? widget.group.customerName
                      : 'Customer';

                  final prefs = await SharedPreferences.getInstance();
                  final shopName =
                      prefs.getString('shop_title')?.isNotEmpty == true
                          ? prefs.getString('shop_title')!
                          : 'Our Shop';

                  final caption = WhatsAppUtils.getWhatsAppCaption(
                    status: OrderPaymentStatus.fullyPaid,
                    customerName: customerNameMsg,
                    businessName: shopName,
                    orderNumber: widget.group.receiptNumber.isNotEmpty
                        ? widget.group.receiptNumber
                        : 'Recent',
                    totalAmount: _totalAfterGst(widget.group),
                  );
                  final message =
                      '$caption\n\nView your complete digital receipt and order details here:\n$link\n\nThank you for your business!\n— $shopName';

                  final phoneController =
                      TextEditingController(text: widget.group.mobileNumber);

                  if (!context.mounted) return;

                  final result = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Share Receipt'),
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
                          onPressed: () =>
                              Navigator.pop(context, phoneController.text),
                          child: const Text('Share to WhatsApp'),
                        ),
                      ],
                    ),
                  );

                  if (result != null && result.isNotEmpty && context.mounted) {
                    final opened = await WhatsAppUtils.openWhatsAppChat(
                      phone: result,
                      message: message,
                    );

                    if (!opened && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Could not open WhatsApp. Please ensure it is installed.')),
                      );
                    }
                  }
                },
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
              color: AppTheme.primary.withValues(alpha: 0.04),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
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
                          color: AppTheme.primary.withValues(alpha: 0.1),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: PaymentSummaryCard(
        gstMode: _gstMode,
        partsSubtotal: _partsSubtotal(widget.group),
        laborSubtotal: _laborSubtotal(widget.group),
        gstAmount: _gstAmount(_partsSubtotal(widget.group)),
        grandTotal: _totalAfterGst(widget.group),
        originalTotal: widget.group.totalAmount,
        onGstModeChanged: _saveGstMode,
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
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: ctrl.typeCtrl,
                builder: (context, value, child) {
                  final text = value.text.toLowerCase();
                  final isPart = text.isEmpty || (text != 'labor' && text != 'labour' && text != 'service');
                  return Row(
                    children: [
                      _PartLaborToggle(
                        isPart: true,
                        selected: isPart,
                        onTap: () => ctrl.typeCtrl.text = 'Part',
                      ),
                      const SizedBox(width: 4),
                      _PartLaborToggle(
                        isPart: false,
                        selected: !isPart,
                        onTap: () => ctrl.typeCtrl.text = 'Labor',
                      ),
                    ],
                  );
                },
              ),
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

class _PartLaborToggle extends StatelessWidget {
  final bool isPart; // true = Part, false = Labor
  final bool selected;
  final VoidCallback onTap;

  const _PartLaborToggle({
    super.key,
    required this.isPart,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = isPart ? '\u2699\uFE0F Part' : '\uD83D\uDD27 Labor';
    final selectedColor =
        isPart ? const Color(0xFF3B82F6) : const Color(0xFF6B7280);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:
              selected ? selectedColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? selectedColor : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? selectedColor : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}
