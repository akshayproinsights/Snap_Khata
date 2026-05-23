import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/shared/domain/models/invoice_group.dart';
import 'package:mobile/features/verified/domain/models/verified_models.dart';
import 'package:mobile/features/verified/presentation/providers/verified_provider.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mobile/core/utils/whatsapp_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/features/shared/presentation/widgets/payment_summary_card.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/settings/presentation/providers/shop_provider.dart';
import 'package:mobile/features/config/presentation/providers/config_provider.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_provider.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mobile/features/udhar/domain/models/udhar_models.dart';
import 'package:mobile/core/utils/receipt_share_link_utils.dart';
import 'package:mobile/features/review/presentation/widgets/customer_autocomplete_field.dart';

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
  late TextEditingController mobileCtrl;

  // Dynamic controllers for industry-specific extra fields (e.g. vehicle_number, site_name)
  // Keyed by the extra_fields JSON key. Empty if no industry is configured.
  final Map<String, TextEditingController> _extraFieldCtrls = {};

  List<ItemDetailCtrl> itemCtrls = [];

  // GST State
  GstMode _gstMode = GstMode.none;

  // Payment State
  String _paymentMode = 'Cash';
  double _receivedAmount = 0.0;
  bool _isReceivedChecked = false;
  late TextEditingController _receivedAmountController;
  late TextEditingController _totalAmountController;
  late TextEditingController _balanceDueController;
  late TextEditingController _creditDetailsController;

  bool _isLoading = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    if (widget.group.customerName == 'Loading...' && widget.group.date.isEmpty) {
      _loadGroupFromReceiptNumber();
    } else {
      _initControllers();
      _loadPersistedSettings();
    }
  }

  Future<void> _loadGroupFromReceiptNumber() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final repo = ref.read(verifiedRepositoryProvider);
      final records = await repo.getVerifiedInvoices(
        receiptNumber: widget.group.receiptNumber,
      );

      if (records.isEmpty) {
        throw Exception('Could not find order details for #${widget.group.receiptNumber}.');
      }

      final first = records.first;
      
      // Fetch ledgers if empty
      var udharState = ref.read(udharProvider);
      if (udharState.ledgers.isEmpty) {
        await ref.read(udharProvider.notifier).fetchLedgers();
        udharState = ref.read(udharProvider);
      }
      
      final sName = first.customerName.toLowerCase().trim();
      final sDetails = (first.customerDetails ?? '').toLowerCase().trim();
      
      CustomerLedger? match;
      for (final l in udharState.ledgers) {
        final lName = l.customerName.toLowerCase().trim();
        if (sName.isNotEmpty && lName == sName) {
          match = l;
          break;
        }
      }
      if (match == null && sDetails.isNotEmpty) {
        for (final l in udharState.ledgers) {
          final lName = l.customerName.toLowerCase().trim();
          if (lName == sDetails) {
            match = l;
            break;
          }
        }
      }
      
      double ledgerTotalPaid = 0.0;
      double ledgerBalanceDue = first.balanceDue ?? 0.0;
      String ledgerPaymentMode = first.paymentMode ?? 'Credit';
      
      if (match != null) {
        final transactions = await ref.read(udharProvider.notifier).fetchTransactions(match.id);
        final double ledgerInvoiceAmount = records.fold(0.0, (sum, item) => sum + item.amount);
        ledgerTotalPaid = transactions
            .where((t) =>
                t.transactionType == 'PAYMENT' &&
                t.receiptNumber == widget.group.receiptNumber)
            .fold(0.0, (sum, t) => sum + t.amount);
        ledgerBalanceDue = (ledgerInvoiceAmount - ledgerTotalPaid).clamp(0.0, double.infinity);
        ledgerPaymentMode = ledgerBalanceDue <= 0 ? 'Cash' : (first.paymentMode ?? 'Credit');
      } else {
        final double ledgerInvoiceAmount = records.fold(0.0, (sum, item) => sum + item.amount);
        ledgerTotalPaid = first.receivedAmount ?? 0.0;
        ledgerBalanceDue = first.balanceDue ?? (ledgerInvoiceAmount - ledgerTotalPaid).clamp(0.0, double.infinity);
        ledgerPaymentMode = first.paymentMode ?? (ledgerBalanceDue <= 0 ? 'Cash' : 'Credit');
      }

      // Mutate the group object passed to the widget
      widget.group.date = first.date.isNotEmpty ? first.date : first.uploadDate;
      widget.group.receiptLink = first.receiptLink;
      widget.group.customerName = first.customerName;
      widget.group.mobileNumber = first.mobileNumber.replaceAll(RegExp(r'\.0$'), '');
      widget.group.extraFields = first.extraFields;
      widget.group.uploadDate = first.uploadDate;
      widget.group.paymentMode = ledgerPaymentMode;
      widget.group.receivedAmount = ledgerTotalPaid;
      widget.group.balanceDue = ledgerBalanceDue;
      widget.group.customerDetails = first.customerDetails;
      widget.group.items = records;
      widget.group.totalAmount = records.fold(0.0, (sum, item) => sum + item.amount);

      if (mounted) {
        _initControllers();
        _loadPersistedSettings();
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString();
          _isLoading = false;
        });
      }
    }
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

  double _partsSubtotal(InvoiceGroup group) {
    if (isEditing && itemCtrls.isNotEmpty) {
      double total = 0;
      for (int i = 0; i < group.items.length; i++) {
        final ctrl = itemCtrls[i];
        final double amt = double.tryParse(ctrl.amtCtrl.text) ?? 0.0;
        final type = ctrl.typeCtrl.text.toUpperCase();
        if (!type.contains('LABOR') && !type.contains('LABOUR') && !type.contains('SERVICE')) {
          total += amt;
        }
      }
      return total;
    }
    return group.items
      .where((i) {
        final type = i.type.toUpperCase();
        return !type.contains('LABOR') && !type.contains('LABOUR') && !type.contains('SERVICE');
      })
      .fold(0.0, (s, i) => s + i.amount);
  }

  double _laborSubtotal(InvoiceGroup group) {
    if (isEditing && itemCtrls.isNotEmpty) {
      double total = 0;
      for (int i = 0; i < group.items.length; i++) {
        final ctrl = itemCtrls[i];
        final double amt = double.tryParse(ctrl.amtCtrl.text) ?? 0.0;
        final type = ctrl.typeCtrl.text.toUpperCase();
        if (type.contains('LABOR') || type.contains('LABOUR') || type.contains('SERVICE')) {
          total += amt;
        }
      }
      return total;
    }
    return group.items
      .where((i) {
        final type = i.type.toUpperCase();
        return type.contains('LABOR') || type.contains('LABOUR') || type.contains('SERVICE');
      })
      .fold(0.0, (s, i) => s + i.amount);
  }

  double _gstAmount(double amount) {
    if (_gstMode == GstMode.excluded) return amount * 0.18;
    if (_gstMode == GstMode.included) return amount * 18 / 118;
    return 0;
  }

  double _totalAfterGst(InvoiceGroup group) {
    // If we have an explicitly provided total (from review or ledger), prioritize it
    // when in view mode. This ensures ₹600 from review shows as ₹600 in details.
    if (!isEditing) {
      if (group.totalAmount > 0) return group.totalAmount;
      
      // Fallback: sum of payment fields (authoritative in database)
      final paymentTotal = (group.receivedAmount ?? 0) + (group.balanceDue ?? 0);
      if (paymentTotal > 0) return paymentTotal;
    }

    // Fallback/Editing mode: compute from actual line items
    final parts = _partsSubtotal(group);
    final labor = _laborSubtotal(group);
    final combined = parts + labor;
    if (_gstMode == GstMode.excluded) return combined + _gstAmount(combined);
    return combined;
  }

  /// Converts a snake_case key to a display label in Title Case.
  /// e.g. "vehicle_number" → "Vehicle Number", "site_name" → "Site Name"
  String _formatFieldLabel(String key) {
    return key
        .split('_')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  void _initControllers() {
    receiptCtrl = TextEditingController(text: widget.group.receiptNumber);
    dateCtrl = TextEditingController(text: widget.group.date);
    customerCtrl = TextEditingController(text: widget.group.customerName);
    mobileCtrl = TextEditingController(text: widget.group.mobileNumber.replaceAll(RegExp(r'\.0$'), ''));

    // Dynamically create controllers for each extra field provided by the backend.
    // No forced fallback — if extra_fields is empty, the section simply won't render.
    for (final entry in widget.group.extraFields.entries) {
      _extraFieldCtrls[entry.key] =
          TextEditingController(text: entry.value?.toString() ?? '');
    }

    // If paymentMode is null but balanceDue > 0, the order was created as credit
    // (e.g., via the ledger flow). Infer 'Credit' so UI reflects the actual state.
    final hasDue = (widget.group.balanceDue ?? 0) > 0;
    
    _paymentMode = widget.group.paymentMode ?? (hasDue ? 'Credit' : 'Cash');
    _receivedAmount = widget.group.receivedAmount ?? (hasDue ? (widget.group.totalAmount - (widget.group.balanceDue ?? 0)) : widget.group.totalAmount);
    _isReceivedChecked = _paymentMode == 'Credit' && _receivedAmount > 0;
    
    _receivedAmountController = TextEditingController(
        text: _paymentMode == 'Credit' ? (_receivedAmount > 0 ? _formatInput(_receivedAmount) : '') : '');
    
    final baseTotal = _totalAfterGst(widget.group);
    _totalAmountController = TextEditingController(text: _formatInput(baseTotal));
    _balanceDueController = TextEditingController(text: _formatInput(baseTotal - _receivedAmount));
    
    _creditDetailsController = TextEditingController(text: widget.group.customerDetails ?? '');

    itemCtrls = widget.group.items.map((item) {
      return ItemDetailCtrl(
        rowId: item.rowId,
        descCtrl: TextEditingController(text: item.description),
        typeCtrl: TextEditingController(text: item.type),
        qtyCtrl: TextEditingController(text: _formatInput(item.quantity)),
        rateCtrl: TextEditingController(text: _formatInput(item.rate)),
        amtCtrl: TextEditingController(text: _formatInput(item.amount)),
      );
    }).toList();
  }

  @override
  void dispose() {
    receiptCtrl.dispose();
    dateCtrl.dispose();
    customerCtrl.dispose();
    mobileCtrl.dispose();
    for (final ctrl in _extraFieldCtrls.values) {
      ctrl.dispose();
    }
    for (var ctrl in itemCtrls) {
      ctrl.dispose();
    }
    _receivedAmountController.dispose();
    _totalAmountController.dispose();
    _balanceDueController.dispose();
    _creditDetailsController.dispose();
    super.dispose();
  }

  void _recalculateTotals() {
    final grandTotal = _totalAfterGst(widget.group);
    
    _totalAmountController.text = _formatInput(grandTotal);
    
    final received = double.tryParse(_receivedAmountController.text) ?? 0.0;
    _balanceDueController.text = _formatInput(grandTotal - received);
    
    setState(() {});
  }

  Future<void> _saveChanges() async {
    FocusScope.of(context).unfocus();
    setState(() => isSaving = true);
    final notifier = ref.read(verifiedProvider.notifier);

    double newParts = 0;
    double newLabor = 0;
    
    // First pass: calculate totals from line items
    for (int i = 0; i < widget.group.items.length; i++) {
        final ctrl = itemCtrls[i];
        final double amt = double.tryParse(ctrl.amtCtrl.text) ?? widget.group.items[i].amount;
        final type = ctrl.typeCtrl.text.toUpperCase();
        if (type.contains('LABOUR') || type.contains('LABOR') || type.contains('SERVICE')) {
            newLabor += amt;
        } else {
            newParts += amt;
        }
    }
    
    // Use the manual total if edited, otherwise fallback to item sum
    final double manualGrandTotal = double.tryParse(_totalAmountController.text) ?? (newParts + newLabor);
    final double manualReceived = double.tryParse(_receivedAmountController.text) ?? 0.0;
    final double manualDue = double.tryParse(_balanceDueController.text) ?? (manualGrandTotal - manualReceived);

    double newTotal = 0;

    // Build updated extra_fields from dynamic controllers.
    // IMPORTANT: Do NOT persist 'total_bill_amount' into extra_fields — the AI sometimes
    // writes a wrong value there that would then override the correct line-item sum.
    // The source of truth for the total is always the sum of actual line items.
    final newGroupExtraFields = {
      for (final e in _extraFieldCtrls.entries)
        if (e.key != 'total_bill_amount' && e.key != 'total_amount') e.key: e.value.text,
    };

    final List<VerifiedInvoice> updatedItems = [];

    for (int i = 0; i < widget.group.items.length; i++) {
      final item = widget.group.items[i];
      final ctrl = itemCtrls[i];

      final double qty = double.tryParse(ctrl.qtyCtrl.text) ?? item.quantity;
      final double rate = double.tryParse(ctrl.rateCtrl.text) ?? item.rate;
      final double amt = double.tryParse(ctrl.amtCtrl.text) ?? item.amount;

      // Merge existing item extra fields with the dynamic group-level overrides
      final newExtraFields = Map<String, dynamic>.from(item.extraFields)
        ..addAll(newGroupExtraFields);

      final updatedItem = item.copyWith(
        receiptNumber: receiptCtrl.text,
        date: dateCtrl.text,
        customerName: customerCtrl.text,
        mobileNumber: mobileCtrl.text,
        description: ctrl.descCtrl.text,
        type: ctrl.typeCtrl.text,
        quantity: qty,
        rate: rate,
        amount: amt,
        paymentMode: _paymentMode,
        receivedAmount: _paymentMode == 'Cash' ? manualGrandTotal : manualReceived,
        balanceDue: _paymentMode == 'Cash' ? 0.0 : manualDue,
        totalBillAmount: manualGrandTotal,
        customerDetails: _creditDetailsController.text,
        extraFields: newExtraFields,
      );

      updatedItems.add(updatedItem);

      widget.group.items[i] = updatedItem;
      newTotal += amt;
    }

    if (updatedItems.isNotEmpty) {
      await notifier.updateRecordsBulk(updatedItems);
      // BUG FIX: Do NOT call fetchLedgersSilent() here — it was causing a blank
      // screen when navigating back because the udhar provider rebuild wiped
      // the navigation stack's widget tree mid-flight.
      // Dashboard totals refresh is safe since it doesn't affect current route.
      unawaited(ref.read(dashboardTotalsProvider.notifier).refresh());
    }

    widget.group.receiptNumber = receiptCtrl.text;
    widget.group.date = dateCtrl.text;
    widget.group.customerName = customerCtrl.text;
    widget.group.mobileNumber = mobileCtrl.text;
    widget.group.extraFields
      ..clear()
      ..addAll(newGroupExtraFields);
    widget.group.totalAmount = double.tryParse(_totalAmountController.text) ?? newTotal;
    widget.group.paymentMode = _paymentMode;
    widget.group.receivedAmount = _paymentMode == 'Cash' ? widget.group.totalAmount : manualReceived;
    widget.group.balanceDue = _paymentMode == 'Cash' ? 0.0 : manualDue;
    widget.group.customerDetails = _creditDetailsController.text;

    setState(() {
      isSaving = false;
      isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.surfaceColor,
        appBar: AppBar(
          title: const Text('Order Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              )),
          backgroundColor: context.surfaceColor,
          elevation: 0,
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMsg != null) {
      return Scaffold(
        backgroundColor: context.surfaceColor,
        appBar: AppBar(
          title: const Text('Order Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              )),
          backgroundColor: context.surfaceColor,
          elevation: 0,
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.alertCircle, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(_errorMsg!,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final config = ref.watch(configProvider).value;
    final isAutomobile = config?['industry'] == 'automobile';
    final hasLink = widget.group.receiptLink.isNotEmpty &&
        widget.group.receiptLink != 'null';

    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: context.surfaceColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Order Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            )),
        backgroundColor: context.surfaceColor,
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
              child: Text('Save',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.primary)),
            )
          else
            IconButton(
              icon: Icon(LucideIcons.edit, color: context.primaryColor),
              tooltip: 'Edit Details',
              onPressed: () => setState(() => isEditing = true),
            ),
          if (hasLink && !isEditing)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Icon(LucideIcons.eye, color: context.primaryColor),
                tooltip: 'View Original Receipt',
                onPressed: () => _showReceiptDialog(context),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: FaIcon(FontAwesomeIcons.whatsapp,
                  color: isSaving ? Colors.grey : context.primaryColor),
              tooltip: 'Share Receipt on WhatsApp',
              onPressed: isSaving
                  ? null
                  : () async {
                      HapticFeedback.lightImpact();

                      final shopProfile = ref.read(shopProvider);
                      final authState = ref.read(authProvider);
                      final username = authState.user?.username;

                      FocusScope.of(context).unfocus();

                      if (isEditing) {
                        _saveChanges();
                      }

                      // Load persisted GST mode for this receipt
                      final prefs = await SharedPreferences.getInstance();
                      final savedMode = prefs
                          .getString('gst_mode_order_${widget.group.receiptNumber}');

                      // Use current controller text as source of truth for the number
                      final currentPhone = mobileCtrl.text.trim();

                      // 📲 Lazy share link: fetch only now (not eagerly in initState)
                      final String? shareUrl =
                          await ReceiptShareLinkUtils.buildSignedOrLegacyLink(
                        receiptNumber: widget.group.receiptNumber,
                        username: username,
                        gstMode: savedMode,
                      );

                      if (shareUrl == null) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Could not generate receipt link.')));
                        return;
                      }

                      final shopName = shopProfile.name.isNotEmpty
                          ? shopProfile.name
                          : 'Our Shop';

                      final double totalAmount = _totalAfterGst(widget.group);
                      final double balanceDue = totalAmount - _receivedAmount;
                      final paymentMode = balanceDue > 0 ? 'Credit' : 'Cash';
                      OrderPaymentStatus status = paymentMode == 'Cash'
                          ? OrderPaymentStatus.fullyPaid
                          : (_receivedAmount > 0
                              ? OrderPaymentStatus.partiallyPaid
                              : OrderPaymentStatus.unpaid);

                      final caption = WhatsAppUtils.getWhatsAppCaption(
                        status: status,
                        customerName: customerCtrl.text.isNotEmpty
                            ? customerCtrl.text.trim()
                            : 'Customer',
                        businessName: shopName,
                        orderNumber: widget.group.receiptNumber.isNotEmpty
                            ? widget.group.receiptNumber
                            : 'Recent',
                        totalAmount: totalAmount,
                        paidAmount: _receivedAmount,
                        pendingAmount: balanceDue,
                      );

                      if (!context.mounted) return;
                      await WhatsAppUtils.shareReceiptWithOptions(
                        context,
                        phone: currentPhone,
                        shareUrl: shareUrl,
                        imageUrl: widget.group.receiptLink,
                        caption: caption,
                        shopName: shopName,
                      );
                    },
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
            _buildCustomerCard(),
            const SizedBox(height: 12),
            _buildItemsSection(isAutomobile),
            const SizedBox(height: 12),
            _buildTotalsCard(isAutomobile),
          ],
        ),
      ),
      bottomNavigationBar:
          _buildStickyBottomBar(_totalAfterGst(widget.group), keyboardInset),
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
        color: context.surfaceColor,
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use_from_same_package
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, -4),
            blurRadius: 20,
          )
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: isEditing 
            ? _buildEditPaymentSection(grandTotal) 
            : _buildViewSummarySection(grandTotal),
      ),
    ),
    );
  }

  Widget _buildViewSummarySection(double grandTotal) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Total Bill Amount', 
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(CurrencyFormatter.format(grandTotal),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: context.textColor, letterSpacing: -0.5)),
            if (_paymentMode == 'Credit') ...[
              const SizedBox(height: 4),
              Row(
                children: [
                   const Text('Balance Due: ', style: TextStyle(color: AppTheme.error, fontSize: 13, fontWeight: FontWeight.w600)),
                   Text(CurrencyFormatter.format(grandTotal - _receivedAmount), style: TextStyle(color: context.errorColor, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              )
            ]
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
             color: _paymentMode == 'Cash' ? Colors.green.shade50 : Colors.red.shade50,
             borderRadius: BorderRadius.circular(24),
             border: Border.all(
               color: _paymentMode == 'Cash' ? Colors.green.shade200 : Colors.red.shade200,
               width: 1,
             )
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_paymentMode == 'Cash' ? LucideIcons.checkCircle : LucideIcons.alertCircle, 
                   size: 18, color: _paymentMode == 'Cash' ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error),
              const SizedBox(width: 8),
              Text(_paymentMode == 'Cash' ? 'Cash' : 'Credit (Due)', style: TextStyle(color: _paymentMode == 'Cash' ? context.primaryColor : context.errorColor, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          )
        )
      ],
    );
  }

  Widget _buildEditPaymentSection(double grandTotal) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Payment Type',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            Container(
              decoration: BoxDecoration(
                color: context.isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PaymentToggleBtn(
                    title: 'Credit',
                    isSelected: _paymentMode == 'Credit',
                    onTap: () {
                      setState(() {
                        _paymentMode = 'Credit';
                        // BUG FIX: Clear received amount when switching to Credit so
                        // balance_due = full amount, not 0 (old Cash received_amount).
                        _receivedAmount = 0;
                        _receivedAmountController.clear();
                        _isReceivedChecked = false;
                        final total = double.tryParse(_totalAmountController.text) ?? grandTotal;
                        _balanceDueController.text = _formatInput(total);
                      });
                    },
                  ),
                  _PaymentToggleBtn(
                    title: 'Cash',
                    isSelected: _paymentMode == 'Cash',
                    onTap: () {
                      setState(() {
                        _paymentMode = 'Cash';
                        final total = double.tryParse(_totalAmountController.text) ?? grandTotal;
                        _receivedAmount = total;
                        _receivedAmountController.text = _formatInput(total);
                        _balanceDueController.text = '0';
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Text('Total Amount',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            const Text('₹ ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _totalAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: context.textColor),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  border: UnderlineInputBorder(borderSide: BorderSide(color: context.borderColor)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: context.primaryColor, width: 2)),
                ),
                onChanged: (val) {
                  final total = double.tryParse(val) ?? 0.0;
                  final received = double.tryParse(_receivedAmountController.text) ?? 0.0;
                  final due = total - received;
                  _balanceDueController.text = _formatInput(due);
                  setState(() {});
                },
              ),
            ),
          ],
        ),
        if (_paymentMode == 'Credit') ...[
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isReceivedChecked = !_isReceivedChecked;
                    if (!_isReceivedChecked) {
                      _receivedAmount = 0;
                      _receivedAmountController.clear();
                    } else {
                      _receivedAmount = grandTotal;
                      _receivedAmountController.text =
                          _formatAmount(grandTotal);
                    }
                  });
                },
                child: Row(
                  children: [
                    Icon(
                      _isReceivedChecked
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: _isReceivedChecked
                          ? context.primaryColor
                          : context.borderColor,
                    ),
                    const SizedBox(width: 8),
                    Text('Received', style: TextStyle(fontSize: 16, color: context.textColor)),
                  ],
                ),
              ),
              const Spacer(),
              const Text('₹ ',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _receivedAmountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 16, color: context.textColor),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                    border: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: context.primaryColor)),
                    fillColor: Colors.transparent,
                  ),
                  onChanged: (val) {
                    final received = double.tryParse(val) ?? 0.0;
                    final total = double.tryParse(_totalAmountController.text) ?? 0.0;
                    final due = total - received;
                    _balanceDueController.text = _formatInput(due);
                    setState(() {
                      _receivedAmount = received;
                      _isReceivedChecked = val.isNotEmpty && _receivedAmount > 0;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Balance Due',
                  style: TextStyle(
                      color: AppTheme.error,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              const Text('₹ ',
                  style: TextStyle(
                      color: AppTheme.error,
                      fontSize: 16,
                      fontWeight: FontWeight.w500)),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _balanceDueController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: context.errorColor),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    border: UnderlineInputBorder(borderSide: BorderSide(color: context.borderColor)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: context.errorColor, width: 2)),
                  ),
                  onChanged: (val) {
                    final due = double.tryParse(val) ?? 0.0;
                    final total = double.tryParse(_totalAmountController.text) ?? 0.0;
                    final received = total - due;
                    _receivedAmountController.text = _formatInput(received);
                    setState(() {
                      _receivedAmount = received;
                      _isReceivedChecked = received > 0;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1. Header Card (Receipt No & Date)
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: context.surfaceColor,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Receipt No
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Receipt Number',
                    style: TextStyle(
                        color: context.textSecondaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                if (isEditing)
                  _buildTextField(context, receiptCtrl, 'Receipt No')
                else
                  Text(
                      widget.group.receiptNumber.isNotEmpty
                          ? '#${widget.group.receiptNumber}'
                          : 'N/A',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: context.textColor)),
              ],
            ),
          ),
          // Divider
          Container(
            width: 1,
            height: 40,
            color: context.borderColor,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          // Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date',
                    style: TextStyle(
                        color: context.textSecondaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                if (isEditing)
                  _buildTextField(context, dateCtrl, 'Date')
                else
                  Text(_formattedDate(),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: context.textColor)),
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
    final hasExtraFields = _extraFieldCtrls.isNotEmpty;

    return Container(
      color: context.surfaceColor,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Customer Details',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: context.textColor)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              boxShadow: context.isDark
                  ? AppTheme.darkPremiumShadow
                  : AppTheme.premiumShadow,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.primaryColor.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.user, color: context.primaryColor, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Customer Name (always shown) ──
                      Text('Customer Name',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.textSecondaryColor,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      if (isEditing)
                        CustomerAutocompleteField(
                          initialValue: customerCtrl.text,
                          label: 'Name',
                          compact: true,
                          onSaved: (val) => customerCtrl.text = val,
                          onCustomerSelected: (party) {
                            setState(() {
                              customerCtrl.text = party.customerName;
                              if (party.customerPhone != null &&
                                  party.customerPhone!.isNotEmpty) {
                                mobileCtrl.text = party.customerPhone!
                                    .replaceAll('+91', '')
                                    .trim();
                              }
                            });
                          },
                        )
                      else
                        Text(
                            widget.group.customerName.isNotEmpty
                                ? widget.group.customerName
                                : 'Unknown',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: context.textColor),
                            overflow: TextOverflow.ellipsis),

                      const SizedBox(height: 12),
                      Text('Mobile Number',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.textSecondaryColor,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      if (isEditing)
                        _buildTextField(context, mobileCtrl, 'Mobile Number', isNumber: true)
                      else
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                  widget.group.mobileNumber.isNotEmpty
                                      ? widget.group.mobileNumber.replaceAll(RegExp(r'\.0$'), '')
                                      : '—',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: context.textColor),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (widget.group.mobileNumber.isNotEmpty)
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                icon: const FaIcon(FontAwesomeIcons.whatsapp,
                                    size: 20, color: Color(0xFF25D366)),
                                tooltip: 'Share on WhatsApp',
                                onPressed: () async {
                                  HapticFeedback.lightImpact();
                                  // Reuse the same logic as the AppBar button but for this specific number
                                  final shopProfile = ref.read(shopProvider);
                                  final authState = ref.read(authProvider);
                                  final username = authState.user?.username;

                                  final prefs = await SharedPreferences.getInstance();
                                  final savedMode = prefs.getString(
                                      'gst_mode_order_${widget.group.receiptNumber}');

                                  final shareUrl =
                                      await ReceiptShareLinkUtils.buildSignedOrLegacyLink(
                                    receiptNumber: widget.group.receiptNumber,
                                    username: username,
                                    gstMode: savedMode,
                                  );

                                  if (shareUrl == null) return;

                                  final double totalAmount = _totalAfterGst(widget.group);
                                  final double balanceDue = totalAmount - _receivedAmount;
                                  final paymentMode = balanceDue > 0 ? 'Credit' : 'Cash';
                                  OrderPaymentStatus status = paymentMode == 'Cash'
                                      ? OrderPaymentStatus.fullyPaid
                                      : (_receivedAmount > 0
                                          ? OrderPaymentStatus.partiallyPaid
                                          : OrderPaymentStatus.unpaid);

                                  final caption = WhatsAppUtils.getWhatsAppCaption(
                                    status: status,
                                    customerName: widget.group.customerName.isNotEmpty
                                        ? widget.group.customerName
                                        : 'Customer',
                                    businessName: shopProfile.name.isNotEmpty
                                        ? shopProfile.name
                                        : 'Our Shop',
                                    orderNumber: widget.group.receiptNumber.isNotEmpty
                                        ? widget.group.receiptNumber
                                        : 'Recent',
                                    totalAmount: totalAmount,
                                    paidAmount: _receivedAmount,
                                    pendingAmount: balanceDue,
                                  );

                                  if (mounted) {
                                    await WhatsAppUtils.shareReceiptWithOptions(
                                      context,
                                      phone: widget.group.mobileNumber.replaceAll(RegExp(r'\.0$'), ''),
                                      shareUrl: shareUrl,
                                      imageUrl: widget.group.receiptLink,
                                      caption: caption,
                                      shopName: shopProfile.name.isNotEmpty
                                          ? shopProfile.name
                                          : 'Our Shop',
                                    );
                                  }
                                },
                              ),
                          ],
                        ),

                      // ── Dynamic extra fields (only if industry provides them) ──
                      if (hasExtraFields) ...[
                        const SizedBox(height: 16),
                        Divider(height: 1, color: context.borderColor),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          children: _extraFieldCtrls.entries.where((e) {
                            final key = e.key.toLowerCase();
                            final ignored = [
                              'rate', 'quantity', 'amount', 'receipt_number',
                              'receipt_link', 'row_id', 'username', 'created_at',
                              'upload_date', 'balance_due', 'payment_mode',
                              'received_amount', 'id', 'customer_name',
                              'mobile_number', 'description', 'type', 'date',
                              'customer_details', 'is_paid', 'total_bill_amount',
                              'total_amount'
                            ];
                            return !ignored.contains(key);
                          }).map((entry) {
                            final label = _formatFieldLabel(entry.key);
                            return SizedBox(
                              width: 140,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(label,
                                      style: TextStyle(
                                          color: context.textSecondaryColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5)),
                                  const SizedBox(height: 4),
                                  if (isEditing)
                                    _buildTextField(context, entry.value, label)
                                  else
                                    Text(
                                        entry.value.text.isNotEmpty
                                            ? entry.value.text
                                            : '—',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: context.textColor),
                                        overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      // Notes / Additional Details section removed as per user request to save space

                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Credit Book shortcut (only for Credit orders, view mode) ──
          if (!isEditing && _paymentMode == 'Credit') ...[
            const SizedBox(height: 14),
            _CreditBookButton(
              customerName: widget.group.customerName,
              customerDetails: widget.group.customerDetails ?? '',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField(BuildContext context, TextEditingController controller, String hint,
      {bool isNumber = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textColor),
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.borderColor.withValues(alpha: 0.5), width: 0.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.borderColor.withValues(alpha: 0.5), width: 0.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.primaryColor, width: 1.5)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3. Items Section
  // ─────────────────────────────────────────────────────────────
  Widget _buildItemsSection(bool isAutomobile) {
    if (isEditing) {
      return Container(
        color: context.surfaceColor,
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
                isAutomobile: isAutomobile,
                onAmountChanged: _recalculateTotals,
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
            i.type.toUpperCase().contains('LABOR') ||
            i.type.toUpperCase().contains('SERVICE'))
        .toList();
    final others = widget.group.items
        .where((i) => !parts.contains(i) && !servicing.contains(i))
        .toList();

    return Container(
      color: context.surfaceColor,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildItemsHeader(),
          if (isAutomobile) ...[
            if (parts.isNotEmpty)
              _buildCategoryGroup(
                  'Spare Parts', parts, LucideIcons.package2, Theme.of(context).colorScheme.primary),
            if (servicing.isNotEmpty)
              _buildCategoryGroup(
                  'Servicing', servicing, LucideIcons.wrench, Theme.of(context).colorScheme.secondary),
            if (others.isNotEmpty)
              _buildCategoryGroup(
                  'Other Items', others, LucideIcons.box, Theme.of(context).colorScheme.outline),
          ] else ...[
            ...widget.group.items.asMap().entries.map((e) {
              return _ItemRow(
                index: e.key + 1,
                item: e.value,
                ctrl: itemCtrls[e.key],
                isLast: e.key == widget.group.items.length - 1,
                isEditing: false,
                isAutomobile: false,
              );
            }),
          ],
          if (widget.group.items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                  child: Text('No items found',
                      style: TextStyle(color: context.textSecondaryColor))),
            ),
        ],
      ),
    );
  }

  Widget _buildItemsHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.primaryColor, context.primaryColor.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
           Icon(LucideIcons.shoppingBag, color: Colors.white, size: 18),
          const SizedBox(width: 8),
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
      IconData icon, Color color) {
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
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Text(title.toUpperCase(),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: 1.0)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10)),
                child: Text('${items.length}',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold, color: context.textSecondaryColor)),
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
            isAutomobile: true,
          );
        }),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 4. Totals & Receipt
  // ─────────────────────────────────────────────────────────────
  Widget _buildTotalsCard(bool isAutomobile) {
    final grandTotal = _totalAfterGst(widget.group);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: PaymentSummaryCard(
        isAutomobile: isAutomobile,
        gstMode: _gstMode,
        partsSubtotal: _partsSubtotal(widget.group),
        laborSubtotal: _laborSubtotal(widget.group),
        gstAmount: _gstAmount(_partsSubtotal(widget.group) + _laborSubtotal(widget.group)),
        grandTotal: grandTotal,
        originalTotal: widget.group.totalAmount,
        onGstModeChanged: _saveGstMode,
      ),
    );
  }



  String _formatAmount(double amount) {
    return CurrencyFormatter.formatPlain(amount);
  }

  String _formatInput(double? amount) {
    return CurrencyFormatter.formatInput(amount);
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
                  color: Theme.of(context).colorScheme.surface,
                  child: Text('Failed to load receipt image.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
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
  final bool isAutomobile;
  final VoidCallback? onAmountChanged;

  const _ItemRow({
    required this.index,
    required this.item,
    required this.ctrl,
    required this.isLast,
    required this.isEditing,
    this.isAutomobile = false,
    this.onAmountChanged,
  });

  void _recalcAmount() {
    final qty = double.tryParse(ctrl.qtyCtrl.text) ?? 0.0;
    final rate = double.tryParse(ctrl.rateCtrl.text) ?? 0.0;
    final amt = qty * rate;
    ctrl.amtCtrl.text = amt == amt.truncateToDouble() ? amt.toInt().toString() : amt.toStringAsFixed(2);
    onAmountChanged?.call();
  }

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: isLast ? Colors.transparent : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
                width: 0.5)),
      ),
      child: isEditing ? _buildEditMode(context) : _buildViewMode(context),
    );
  }

  Widget _buildViewMode(BuildContext context) {
    final qtyStr = item.quantity == item.quantity.roundToDouble()
        ? item.quantity.toInt().toString()
        : item.quantity.toStringAsFixed(1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.description.isNotEmpty ? item.description : 'Unknown',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.textColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (isAutomobile)
                    _Badge(
                      text: item.type.toUpperCase().contains('PART') ? 'PART' : 'LABOR',
                      color: item.type.toUpperCase().contains('PART') 
                          ? Theme.of(context).colorScheme.primary 
                          : Theme.of(context).colorScheme.secondary,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    '$qtyStr  x  ${CurrencyFormatter.format(item.rate)}',
                    style: TextStyle(
                        color: context.textSecondaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Text(
          CurrencyFormatter.format(item.amount),
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.textColor),
        ),
      ],
    );
  }

  Widget _buildEditMode(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildIndexBadge(context),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(context, ctrl.descCtrl, 'Description')),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Row(
            children: [
              if (isAutomobile)
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
                          onTap: () => ctrl.typeCtrl.text = 'Labour',
                        ),
                        const SizedBox(width: 8),
                      ],
                    );
                  },
                ),
              Expanded(
                  flex: 1,
                  child: _buildTextField(context, ctrl.qtyCtrl, 'Qty', isNumber: true, onChanged: (_) => _recalcAmount())),
              const SizedBox(width: 8),
              Expanded(
                  flex: 2,
                  child: _buildTextField(context, ctrl.rateCtrl, 'Rate', isNumber: true, onChanged: (_) => _recalcAmount())),
              const SizedBox(width: 8),
              Expanded(
                  flex: 2,
                  child: _buildTextField(context, ctrl.amtCtrl, 'Amount', isNumber: true, readOnly: true)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIndexBadge(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5), width: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text('#$index',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                fontSize: 10)),
      ),
    );
  }

  Widget _buildTextField(BuildContext context, TextEditingController controller, String hint,
      {bool isNumber = false, bool readOnly = false, void Function(String)? onChanged}) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onChanged: onChanged,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: TextStyle(
          fontSize: 13, 
          fontWeight: FontWeight.w600,
          color: readOnly ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6) : Theme.of(context).colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        isDense: true,
        fillColor: readOnly ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3) : null,
        filled: readOnly,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4), width: 0.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4), width: 0.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: readOnly ? Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4) : Theme.of(context).colorScheme.primary, width: readOnly ? 0.5 : 1.2)),
      ),
    );
  }
}

class _PaymentToggleBtn extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentToggleBtn({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? context.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: context.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : context.textSecondaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _PartLaborToggle extends StatelessWidget {
  final bool isPart; // true = Part, false = Labor
  final bool selected;
  final VoidCallback onTap;

  const _PartLaborToggle({
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
            color: selected ? selectedColor : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 0.5,
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

// ─────────────────────────────────────────────────────────────────────────────
// Credit Book shortcut button
// ─────────────────────────────────────────────────────────────────────────────
class _CreditBookButton extends ConsumerWidget {
  final String customerName;
  final String customerDetails;

  const _CreditBookButton({
    required this.customerName,
    required this.customerDetails,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();

        CustomerLedger? findMatch(List<CustomerLedger> ledgers) {
          final sName = customerName.toLowerCase().trim();
          final sDetails = customerDetails.toLowerCase().trim();

          if (sName.isEmpty && sDetails.isEmpty) return null;

          // 1. Try exact match on Name
          if (sName.isNotEmpty && sName != 'unknown' && sName != 'unknown customer') {
            final matches = ledgers.where((l) => l.customerName.toLowerCase().trim() == sName);
            if (matches.isNotEmpty) return matches.first;
          }

          // 2. Try exact match on Details (if name didn't match or was generic)
          if (sDetails.isNotEmpty) {
            final matches = ledgers.where((l) => l.customerName.toLowerCase().trim() == sDetails);
            if (matches.isNotEmpty) return matches.first;
          }

          // 3. Try partial match on Name
          if (sName.isNotEmpty && sName != 'unknown' && sName != 'unknown customer') {
            final matches = ledgers.where((l) => l.customerName.toLowerCase().contains(sName));
            if (matches.isNotEmpty) return matches.first;
          }

          // 4. Try partial match on Details
          if (sDetails.isNotEmpty) {
            final matches = ledgers.where((l) => l.customerName.toLowerCase().contains(sDetails));
            if (matches.isNotEmpty) return matches.first;
          }

          return null;
        }

        final state = ref.read(udharProvider);
        CustomerLedger? match = findMatch(state.ledgers);

        // If no match found, try refreshing data once
        if (match == null) {
          await ref.read(udharProvider.notifier).fetchLedgers();
          final newState = ref.read(udharProvider);
          match = findMatch(newState.ledgers);
        }

        if (!context.mounted) return;

        if (match == null) {
          // No match found — navigate home and show a helpful message.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No credit book entry found for this customer yet.'),
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }

        context.push('/party/${match.id}', extra: match);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.15),
            width: 0.5,
          ),
          boxShadow: context.isDark
              ? AppTheme.darkPremiumShadow
              : AppTheme.premiumShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.bookOpen, size: 18, color: Colors.orange),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'View in Credit Book',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  Text(
                    'Check previous balances & history',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
