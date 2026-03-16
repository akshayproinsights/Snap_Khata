import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/review/domain/models/review_models.dart';
import 'package:mobile/features/review/presentation/providers/review_provider.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/utils/whatsapp_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:mobile/features/shared/presentation/widgets/payment_summary_card.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';

class ReceiptReviewPage extends ConsumerStatefulWidget {
  final InvoiceReviewGroup group;

  const ReceiptReviewPage({super.key, required this.group});

  @override
  ConsumerState<ReceiptReviewPage> createState() => _ReceiptReviewPageState();
}

class _ReceiptReviewPageState extends ConsumerState<ReceiptReviewPage> {
  // ── GST / Payment Summary state ──────────────────────────────────────────
  GstMode _gstMode = GstMode.none;

  // ── Payment Mode state ───────────────────────────────────────────────────
  String _paymentMode = 'Cash';
  bool _isReceivedChecked = false;
  final TextEditingController _receivedAmountController = TextEditingController();
  final TextEditingController _creditDetailsController = TextEditingController();
  double _receivedAmount = 0.0;

  /// Row IDs of line items the user has marked as taxable (Parts).
  /// Defaults to ALL items being taxable — user unticks Labor/Service items.
  Set<String> _taxableRowIds = {};

  @override
  void initState() {
    super.initState();
    // Default: mark all line items as taxable (Parts) unless marked Labour/Service
    _taxableRowIds = widget.group.lineItems
        .where((i) {
          final type = i.type?.toLowerCase() ?? '';
          return type != 'labor' && type != 'labour' && type != 'service';
        })
        .map((i) => i.rowId)
        .toSet();
    _loadPersistedSettings();
  }

  @override
  void dispose() {
    _receivedAmountController.dispose();
    _creditDetailsController.dispose();
    super.dispose();
  }

  Future<void> _loadPersistedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final receipt = widget.group.receiptNumber;

    // Load payment mode
    final savedPaymentMode = prefs.getString('payment_mode_$receipt');
    if (savedPaymentMode != null && mounted) {
      setState(() {
        _paymentMode = savedPaymentMode;
      });
    }

    // Load received amount
    final savedReceivedAmount = prefs.getDouble('received_amount_$receipt');
    if (savedReceivedAmount != null && mounted) {
      setState(() {
        _receivedAmount = savedReceivedAmount;
        _isReceivedChecked = savedReceivedAmount > 0;
        _receivedAmountController.text = _formatAmount(savedReceivedAmount);
      });
    }

    // Load credit details
    final savedCreditDetails = prefs.getString('credit_details_$receipt');
    if (savedCreditDetails != null && mounted) {
      setState(() {
        _creditDetailsController.text = savedCreditDetails;
      });
    }

    // Load GST mode
    final savedMode = prefs.getString('gst_mode_$receipt');
    if (savedMode != null && mounted) {
      setState(() {
        _gstMode = GstMode.values.firstWhere(
          (e) => e.name == savedMode,
          orElse: () => GstMode.none,
        );
      });
    }

    // Load taxable item overrides (stored as comma-separated row IDs)
    final savedTaxable = prefs.getString('gst_taxable_$receipt');
    if (savedTaxable != null && mounted) {
      setState(() {
        _taxableRowIds =
            savedTaxable.isEmpty ? <String>{} : savedTaxable.split(',').toSet();
      });
    }
  }

  Future<void> _savePaymentMode(String mode) async {
    setState(() => _paymentMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('payment_mode_${widget.group.receiptNumber}', mode);
  }

  Future<void> _saveReceivedAmount(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('received_amount_${widget.group.receiptNumber}', amount);
  }

  Future<void> _saveCreditDetails(String details) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('credit_details_${widget.group.receiptNumber}', details);
  }

  Future<void> _saveGstMode(GstMode mode) async {
    setState(() => _gstMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gst_mode_${widget.group.receiptNumber}', mode.name);
  }

  Future<void> _toggleTaxable(String rowId, bool taxable) async {
    setState(() {
      if (taxable) {
        _taxableRowIds.add(rowId);
      } else {
        _taxableRowIds.remove(rowId);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'gst_taxable_${widget.group.receiptNumber}',
      _taxableRowIds.join(','),
    );
  }

  // ── GST computed helpers (on PARTS only) ─────────────────────────────────
  double _partsSubtotal(InvoiceReviewGroup group) => group.lineItems
      .where((i) => _taxableRowIds.contains(i.rowId))
      .fold(0.0, (s, i) => s + i.amount);

  double _laborSubtotal(InvoiceReviewGroup group) => group.lineItems
      .where((i) => !_taxableRowIds.contains(i.rowId))
      .fold(0.0, (s, i) => s + i.amount);

  double _gstAmount(double partsSubtotal) {
    if (_gstMode == GstMode.excluded) return partsSubtotal * 0.18;
    if (_gstMode == GstMode.included) return partsSubtotal * 18 / 118;
    return 0;
  }

  double _totalAfterGst(InvoiceReviewGroup group) {
    final parts = _partsSubtotal(group);
    final labor = _laborSubtotal(group);
    if (_gstMode == GstMode.excluded) return parts + _gstAmount(parts) + labor;
    return parts + labor; // included or none: total unchanged
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
            title: const Text('Receipt Image'),
          ),
          body: InteractiveViewer(
            child: Center(
              child: Hero(
                tag: 'receipt_image_${widget.group.receiptNumber}',
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(color: Colors.white)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatAmount(double? amount) {
    if (amount == null) return '';
    String formatted = amount.toStringAsFixed(2);
    if (formatted.endsWith('.00')) {
      return formatted.substring(0, formatted.length - 3);
    }
    return formatted;
  }

  void _markAllDone() {
    final group = widget.group;
    final header = group.header;

    // Always save the record, even with errors
    if (header != null) {
      final grandTotal = _totalAfterGst(group);
      final balanceDue = _paymentMode == 'Credit' ? grandTotal - _receivedAmount : 0.0;
      
      final newRecord = header.copyWith(
          verificationStatus: 'Done',
          paymentMode: _paymentMode,
          receivedAmount: _paymentMode == 'Credit' ? _receivedAmount : null,
          balanceDue: _paymentMode == 'Credit' ? balanceDue : null,
          customerDetails: _paymentMode == 'Credit' ? _creditDetailsController.text : null,
          gstMode: _gstMode.name,
          taxableRowIds: _taxableRowIds.join(','),
      );
      ref.read(reviewProvider.notifier).updateDateRecord(newRecord);
    }

    for (var item in group.lineItems) {
      if (item.verificationStatus != 'Done') {
        final newRecord = item.copyWith(verificationStatus: 'Done');
        ref.read(reviewProvider.notifier).updateAmountRecord(newRecord);
      }
    }

    // Automatically go back after marking done
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    // Read fresh group from state to reflect updates immediately
    final state = ref.watch(reviewProvider);
    final group = state.groups.firstWhere(
        (g) => g.receiptNumber == widget.group.receiptNumber,
        orElse: () => widget.group);

    final header = group.header;

    // Line Item Hoisting: Red items (hasError) at the top!
    final sortedLineItems = List<ReviewRecord>.from(group.lineItems);
    sortedLineItems.sort((a, b) {
      if (a.hasError && !b.hasError) return -1;
      if (!a.hasError && b.hasError) return 1;
      // Sort in image order (top-to-bottom) using the lineItemBbox y-coordinate (index 1)
      final yA = (a.lineItemBbox != null && a.lineItemBbox!.length > 1) ? a.lineItemBbox![1] : double.infinity;
      final yB = (b.lineItemBbox != null && b.lineItemBbox!.length > 1) ? b.lineItemBbox![1] : double.infinity;
      return yA.compareTo(yB);
    });

    final hasAnyError = group.hasError;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Receipt #${group.receiptNumber}'),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.whatsapp,
                color: AppTheme.primary),
            onPressed: () async {
              // Calculate total amount from line items, fallback to header amount if line items total is zero
              double totalAmount = _totalAfterGst(group);
              if (totalAmount == 0.0 && group.header != null) {
                totalAmount = group.header!.amount;
              }

              final gstParam =
                  _gstMode == GstMode.none ? '' : '&gst_mode=${_gstMode.name}';

              final authState = ref.read(authProvider);
              final usernameParam = authState.user?.username != null
                  ? '&u=${authState.user!.username}'
                  : '';

              final shareUrl =
                  'https://mydigientry.com/receipt.html?id=${group.receiptNumber}$gstParam$usernameParam';

              final prefs = await SharedPreferences.getInstance();
              final shopName = prefs.getString('shop_title')?.isNotEmpty == true
                  ? prefs.getString('shop_title')!
                  : 'Our Shop';

              final caption = WhatsAppUtils.getWhatsAppCaption(
                status: OrderPaymentStatus.fullyPaid,
                customerName: header?.customerName?.isNotEmpty == true
                    ? header!.customerName!
                    : 'Customer',
                businessName: shopName,
                orderNumber: group.receiptNumber,
                totalAmount: totalAmount,
              );
              final message =
                  '$caption\n\nView your complete digital receipt and order details here:\n$shareUrl\n\nThank you for your business!\n— $shopName';

              // Open custom input dialog for phone number (pre-filled if available from DB)
              final phoneController =
                  TextEditingController(text: header?.mobileNumber ?? '');

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
                      onPressed: () => context.pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => context.pop(phoneController.text),
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
            tooltip: 'Share via WhatsApp',
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Image Viewer
          if (header != null && header.receiptLink.isNotEmpty)
            GestureDetector(
              onTap: () => _showFullImage(header.receiptLink),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.25,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.black,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'receipt_image_${group.receiptNumber}',
                      child: CachedNetworkImage(
                        imageUrl: header.receiptLink,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        placeholder: (context, url) => const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white)),
                        errorWidget: (context, url, error) => const Icon(
                            LucideIcons.imageOff,
                            color: Colors.white54,
                            size: 40),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.maximize,
                                color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text('Tap to expand',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Scrollable Fields
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (header != null) _buildHeaderCard(header),
                const SizedBox(height: 16),
                const Text('Line Items',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                if (sortedLineItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                        child: Text('No line items found.',
                            style: TextStyle(color: AppTheme.textSecondary))),
                  ),
                ...sortedLineItems.map((item) => _buildLineItemCard(item)),
                const SizedBox(height: 16),
                // ── Payment Summary ──────────────────────────────────────
                PaymentSummaryCard(
                  gstMode: _gstMode,
                  taxableRowIds: _taxableRowIds,
                  partsSubtotal: _partsSubtotal(group),
                  laborSubtotal: _laborSubtotal(group),
                  gstAmount: _gstAmount(_partsSubtotal(group)),
                  grandTotal: _totalAfterGst(group),
                  originalTotal: group.header?.amount ??
                      (_partsSubtotal(group) + _laborSubtotal(group)),
                  lineItems: sortedLineItems
                      .map((item) => PaymentSummaryItem(
                            rowId: item.rowId,
                            description: item.description,
                            amount: item.amount,
                          ))
                      .toList(),
                  onGstModeChanged: _saveGstMode,
                  onToggleTaxable: _toggleTaxable,
                ),
                _buildPaymentSection(_totalAfterGst(group)),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Amount:',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text('₹${_formatAmount(_totalAfterGst(group))}',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5)),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _markAllDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasAnyError
                    ? Colors.orange
                    : const Color(0xFF2A7678), // Deep teal
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: hasAnyError
                  ? const Icon(LucideIcons.alertTriangle, size: 18)
                  : const SizedBox.shrink(),
              label: Text(
                hasAnyError ? 'Save with Errors' : 'Confirm & Save ✨',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSection(double grandTotal) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
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
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PaymentToggleBtn(
                      title: 'Credit',
                      isSelected: _paymentMode == 'Credit',
                      onTap: () => _savePaymentMode('Credit'),
                    ),
                    _PaymentToggleBtn(
                      title: 'Cash',
                      isSelected: _paymentMode == 'Cash',
                      onTap: () {
                        _savePaymentMode('Cash');
                        setState(() {
                          _receivedAmount = grandTotal;
                          _receivedAmountController.text =
                              _formatAmount(grandTotal);
                        });
                        _saveReceivedAmount(grandTotal);
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
                width: 100,
                child: Text(
                  _formatAmount(grandTotal),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
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
                        _saveReceivedAmount(0);
                      } else {
                        _receivedAmount = grandTotal;
                        _receivedAmountController.text =
                            _formatAmount(grandTotal);
                        _saveReceivedAmount(grandTotal);
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
                            ? AppTheme.primary
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 8),
                      const Text('Received', style: TextStyle(fontSize: 16)),
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
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                      border: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.primary)),
                      fillColor: Colors.transparent,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _receivedAmount = double.tryParse(val) ?? 0.0;
                        _isReceivedChecked = val.isNotEmpty && _receivedAmount > 0;
                      });
                      _saveReceivedAmount(double.tryParse(val) ?? 0.0);
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
                        color: AppTheme.success,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                const Text('₹ ',
                    style: TextStyle(
                        color: AppTheme.success,
                        fontSize: 16,
                        fontWeight: FontWeight.w500)),
                SizedBox(
                  width: 100,
                  child: Text(
                    _formatAmount(grandTotal - _receivedAmount),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: AppTheme.success,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _creditDetailsController,
              onChanged: (val) => _saveCreditDetails(val),
              decoration: InputDecoration(
                labelText: 'Customer Details / Notes',
                labelStyle:
                    TextStyle(fontSize: 14, color: Colors.grey.shade600),
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
              maxLines: 2,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCard(ReviewRecord header) {
    final isError = header.hasError;
    final isDone = header.verificationStatus == 'Done';

    Color borderColor = AppTheme.border;
    Color bgColor = Colors.white;
    if (isError) {
      borderColor = Colors.red.shade400;
      bgColor = Colors.red.shade50;
    } else if (isDone) {
      borderColor = Colors.green.shade400;
      bgColor = Colors.green.shade50;
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: borderColor, width: isError || isDone ? 2 : 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.fileText,
                  size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              const Text('Header Details',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.textSecondary)),
              const Spacer(),
              if (isError)
                const Icon(LucideIcons.alertCircle,
                    color: Colors.red, size: 16),
              if (!isError && isDone)
                const Icon(LucideIcons.checkCircle,
                    color: Colors.green, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 9,
                child: DebouncedReviewField(
                  initialValue: header.receiptNumber,
                  decoration: _inputDecoration('Receipt No.').copyWith(
                    errorText:
                        header.receiptNumber.trim().isEmpty ? 'Required' : null,
                    enabledBorder: header.hasReceiptDoubt
                        ? OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: Colors.red.shade400, width: 1.5),
                          )
                        : null,
                    focusedBorder: header.hasReceiptDoubt
                        ? OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: Colors.red.shade400, width: 2),
                          )
                        : null,
                    fillColor: header.hasReceiptDoubt
                        ? Colors.red.shade50
                        : Colors.white,
                  ),
                  onSaved: (val) {
                    if (val != header.receiptNumber) {
                      final newRecord = header.copyWith(receiptNumber: val);
                      ref
                          .read(reviewProvider.notifier)
                          .updateDateRecord(newRecord);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 11,
                child: InkWell(
                  onTap: () async {
                    DateTime? initialDate;
                    try {
                      if (header.date.isNotEmpty) {
                        try {
                          initialDate =
                              DateFormat('dd-MM-yyyy').parseStrict(header.date);
                        } catch (e) {
                          initialDate = DateTime.parse(header.date);
                        }
                      }
                    } catch (_) {}

                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initialDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );

                    if (picked != null) {
                      final formattedDate =
                          DateFormat('dd-MM-yyyy').format(picked);
                      if (formattedDate != header.date) {
                        final newRecord = header.copyWith(date: formattedDate);
                        ref
                            .read(reviewProvider.notifier)
                            .updateDateRecord(newRecord);
                      }
                    }
                  },
                  child: IgnorePointer(
                    child: TextFormField(
                      key: ValueKey('date_${header.date}'),
                      initialValue: header.date,
                      readOnly: true,
                      decoration: _inputDecoration('Date').copyWith(
                        errorText:
                            header.date.trim().isEmpty ? 'Required' : null,
                        suffixIcon: const Icon(LucideIcons.calendar, size: 16),
                        enabledBorder: header.hasDateDoubt
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Colors.red.shade400, width: 1.5),
                              )
                            : null,
                        focusedBorder: header.hasDateDoubt
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Colors.red.shade400, width: 2),
                              )
                            : null,
                        fillColor: header.hasDateDoubt
                            ? Colors.red.shade50
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DebouncedReviewField(
            initialValue: header.customerName ?? '',
            decoration: _inputDecoration('Customer Name').copyWith(
              prefixIcon: const Icon(LucideIcons.user, size: 16),
            ),
            onSaved: (val) {
              if (val != header.customerName) {
                final newRecord = header.copyWith(customerName: val);
                ref.read(reviewProvider.notifier).updateDateRecord(newRecord);
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DebouncedReviewField(
                  initialValue: header.vehicleNumber ?? '',
                  decoration: _inputDecoration('Vehicle Number').copyWith(
                    prefixIcon: const Icon(LucideIcons.car, size: 16),
                  ),
                  onSaved: (val) {
                    if (val != header.vehicleNumber) {
                      final newRecord = header.copyWith(vehicleNumber: val);
                      ref.read(reviewProvider.notifier).updateDateRecord(newRecord);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DebouncedReviewField(
                  initialValue: header.mobileNumber ?? '',
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration('Mobile Number').copyWith(
                    prefixIcon: const Icon(LucideIcons.phone, size: 16),
                    errorText: (header.mobileNumber != null && header.mobileNumber!.trim().isNotEmpty && header.mobileNumber!.trim().length != 10) ? 'Must be 10 digits' : null,
                    enabledBorder: (header.mobileNumber != null && header.mobileNumber!.trim().isNotEmpty && header.mobileNumber!.trim().length != 10)
                        ? OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: Colors.red.shade400, width: 1.5),
                          )
                        : null,
                    focusedBorder: (header.mobileNumber != null && header.mobileNumber!.trim().isNotEmpty && header.mobileNumber!.trim().length != 10)
                        ? OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: Colors.red.shade400, width: 2),
                          )
                        : null,
                    fillColor: (header.mobileNumber != null && header.mobileNumber!.trim().isNotEmpty && header.mobileNumber!.trim().length != 10)
                        ? Colors.red.shade50
                        : Colors.white,
                  ),
                  onSaved: (val) {
                    if (val != header.mobileNumber) {
                      final newRecord = header.copyWith(mobileNumber: val);
                      ref.read(reviewProvider.notifier).updateDateRecord(newRecord);
                    }
                  },
                ),
              ),
            ],
          ),
          if (header.verificationStatus == 'Duplicate Receipt Number')
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text('Error: Duplicate Receipt Number. Please fix it.',
                  style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            )
        ],
      ),
    );
  }

  Widget _buildLineItemCard(ReviewRecord item) {
    final isError = item.hasError;
    final isDone = item.verificationStatus == 'Done';

    Color borderColor = AppTheme.border;
    Color bgColor = Colors.white;
    if (isError) {
      borderColor = Colors.red.shade400;
      bgColor = Colors.red.shade50;
    } else if (isDone) {
      borderColor = Colors.green.shade400;
      bgColor = Colors.green.shade50;
    }

    // Checking if amount mismatch exists
    final hasMismatch =
        item.amountMismatch != null && item.amountMismatch!.abs() > 0.01;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isError ? 2 : 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: DebouncedReviewField(
                  initialValue: item.description,
                  decoration: _inputDecoration('Description').copyWith(
                    errorText:
                        item.description.trim().isEmpty ? 'Required' : null,
                  ),
                  maxLines: null,
                  onSaved: (val) {
                    if (val != item.description) {
                      final newRecord = item.copyWith(description: val);
                      ref
                          .read(reviewProvider.notifier)
                          .updateAmountRecord(newRecord);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DebouncedReviewField(
                  initialValue: _formatAmount(item.amount),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppTheme.primary),
                  decoration: _inputDecoration('Total (₹)'),
                  onSaved: (val) {
                    final newAmount = double.tryParse(val);
                    if (newAmount != null && newAmount != item.amount) {
                      final newRecord = item.copyWith(amount: newAmount, amountMismatch: 0);
                      ref
                          .read(reviewProvider.notifier)
                          .updateAmountRecord(newRecord);
                    }
                  },
                ),
              ),
            ],
          ),
          if (item.quantity != null && item.rate != null && item.rate! > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: DebouncedReviewField(
                  initialValue: _formatAmount(item.quantity),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDecoration('Qty'),
                  onSaved: (val) {
                    final newQty = double.tryParse(val);
                    if (newQty != null) {
                      // recalculate mismatch
                      final newMismatch = (newQty * item.rate!) - item.amount;
                      final newRecord = item.copyWith(quantity: newQty, amountMismatch: newMismatch);
                      ref
                          .read(reviewProvider.notifier)
                          .updateAmountRecord(newRecord);
                    }
                  },
                )),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text('×',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ),
                Expanded(
                    child: DebouncedReviewField(
                  initialValue: _formatAmount(item.rate),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDecoration('Rate (₹)'),
                  onSaved: (val) {
                    final newRate = double.tryParse(val);
                    if (newRate != null && item.quantity != null) {
                      final newMismatch =
                          (item.quantity! * newRate) - item.amount;
                      final newRecord = item.copyWith(rate: newRate, amountMismatch: newMismatch);
                      ref
                          .read(reviewProvider.notifier)
                          .updateAmountRecord(newRecord);
                    }
                  },
                )),
                const Spacer(),
              ],
            ),
          ],
          if (isError) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(LucideIcons.alertTriangle,
                    size: 14, color: Colors.red),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                      hasMismatch
                          ? 'Math Error: Qty × Rate ≠ Total'
                          : 'Missing required fields',
                      style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}

class DebouncedReviewField extends StatefulWidget {
  final String initialValue;
  final InputDecoration decoration;
  final TextInputType? keyboardType;
  final TextAlign textAlign;
  final TextStyle? style;
  final int? maxLines;
  final ValueChanged<String> onSaved;

  const DebouncedReviewField({
    super.key,
    required this.initialValue,
    required this.decoration,
    this.keyboardType,
    this.textAlign = TextAlign.start,
    this.style,
    this.maxLines = 1,
    required this.onSaved,
  });

  @override
  State<DebouncedReviewField> createState() => _DebouncedReviewFieldState();
}

class _DebouncedReviewFieldState extends State<DebouncedReviewField> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  String _lastSavedValue = '';

  @override
  void initState() {
    super.initState();
    _lastSavedValue = widget.initialValue;
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant DebouncedReviewField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _lastSavedValue != widget.initialValue) {
      if (!_focusNode.hasFocus) {
        _controller.text = widget.initialValue;
        _lastSavedValue = widget.initialValue;
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _saveCurrentValue();
    }
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 4), () {
      _saveCurrentValue();
    });
  }

  void _saveCurrentValue() {
    _debounceTimer?.cancel();
    final currentValue = _controller.text;
    if (currentValue != _lastSavedValue) {
      _lastSavedValue = currentValue;
      widget.onSaved(currentValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      decoration: widget.decoration,
      keyboardType: widget.keyboardType,
      textAlign: widget.textAlign,
      style: widget.style,
      maxLines: widget.maxLines,
      onChanged: _onChanged,
      onFieldSubmitted: (_) {
        _saveCurrentValue();
      },
      onTapOutside: (event) {
        _focusNode.unfocus();
      },
      textInputAction: TextInputAction.done,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// END
// ─────────────────────────────────────────────────────────────────────────────

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
          color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
