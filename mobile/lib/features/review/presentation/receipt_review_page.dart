import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/review/domain/models/review_models.dart';
import 'package:mobile/features/review/presentation/providers/review_provider.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/utils/whatsapp_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:mobile/features/shared/presentation/widgets/payment_summary_card.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/settings/presentation/providers/shop_provider.dart';
import 'package:mobile/features/config/presentation/providers/config_provider.dart';
import 'package:mobile/core/utils/receipt_share_link_utils.dart';


class ReceiptReviewPage extends ConsumerStatefulWidget {
  final InvoiceReviewGroup group;
  /// All groups from the pending list, used to navigate to the next receipt.
  final List<InvoiceReviewGroup> allGroups;
  /// Index of [group] inside [allGroups]. -1 when not launched from the list.
  final int currentIndex;

  const ReceiptReviewPage({
    super.key,
    required this.group,
    this.allGroups = const [],
    this.currentIndex = -1,
  });

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

  @override
  void initState() {
    super.initState();
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

  // ── GST computed helpers ─────────────────────────────────
  // Uses positive match for 'PART' — same logic as order_detail_page.dart
  // and the visual partsItems grouping below.
  // FALLBACK: if NO items have a recognized type (all null/empty), treat all
  // items as parts so the Payment Summary is never blank.
  double _partsSubtotal(InvoiceReviewGroup group) {
    final typed = group.lineItems.where((i) {
      final type = i.type?.toUpperCase() ?? '';
      return type.isNotEmpty;
    }).toList();

    // If no items have a type at all, sum every line item as "parts"
    if (typed.isEmpty) {
      return group.lineItems.fold(0.0, (s, i) => s + i.amount);
    }

    return group.lineItems
        .where((i) {
          final type = i.type?.toUpperCase() ?? '';
          // Untyped items also fall into parts bucket
          return type.contains('PART') || type.isEmpty;
        })
        .fold(0.0, (s, i) => s + i.amount);
  }

  double _laborSubtotal(InvoiceReviewGroup group) => group.lineItems
      .where((i) {
        final type = i.type?.toUpperCase() ?? '';
        return type.contains('LABOUR') || type.contains('LABOR') || type.contains('SERVICE');
      })
      .fold(0.0, (s, i) => s + i.amount);

  double _gstAmount(double totalSubtotal) {
    if (_gstMode == GstMode.excluded) return totalSubtotal * 0.18;
    if (_gstMode == GstMode.included) return totalSubtotal * 18 / 118;
    return 0;
  }

  double _totalAfterGst(InvoiceReviewGroup group) {
    final totalSubtotal = _partsSubtotal(group) + _laborSubtotal(group);
    if (_gstMode == GstMode.excluded) return totalSubtotal + _gstAmount(totalSubtotal);
    return totalSubtotal; // included or none: total unchanged
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
                  httpHeaders: const {
                    'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
                  },
                  placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(color: Colors.white)),
                  errorWidget: (context, url, error) => const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.imageOff,
                          color: Colors.white54,
                          size: 60),
                        SizedBox(height: 16),
                        Text(
                          'Image unavailable',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
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
    return CurrencyFormatter.format(amount);
  }

  Future<void> _saveCurrentState({String? updatePhoneNumber}) async {
    final notifier = ref.read(reviewProvider.notifier);
    // Read the LIVE group from provider state (not widget.group which is the
    // original navigation argument and may be stale after user edits).
    final liveState = ref.read(reviewProvider);
    final group = liveState.groups.firstWhere(
      (g) => g.receiptNumber == widget.group.receiptNumber,
      orElse: () => widget.group,
    );
    final header = group.header;

    // Always save the record, even with errors
    if (header != null) {
      final grandTotal = _totalAfterGst(group);
      final balanceDue = _paymentMode == 'Credit' ? grandTotal - _receivedAmount : 0.0;
      
      var newRecord = header.copyWith(
          verificationStatus: 'Done',
          paymentMode: _paymentMode,
          receivedAmount: _paymentMode == 'Credit' ? _receivedAmount : null,
          balanceDue: _paymentMode == 'Credit' ? balanceDue : null,
          customerDetails: _paymentMode == 'Credit' ? _creditDetailsController.text : null,
          gstMode: _gstMode.name,
      );

      if (updatePhoneNumber != null && updatePhoneNumber.isNotEmpty) {
        final newExtra = Map<String, dynamic>.from(newRecord.extraFields);
        newExtra['mobile_number'] = updatePhoneNumber;
        newRecord = newRecord.copyWith(
          extraFields: newExtra,
          mobileNumber: updatePhoneNumber,
        );
      }

      await notifier.updateDateRecord(newRecord);
    }

    final recordsToUpdate = <ReviewRecord>[];
    for (var item in group.lineItems) {
      if (item.verificationStatus != 'Done') {
        recordsToUpdate.add(item.copyWith(verificationStatus: 'Done'));
      }
    }
    
    if (recordsToUpdate.isNotEmpty) {
      await notifier.updateAmountRecordsBulk(recordsToUpdate);
    }
  }

  void _markAllDone() async {
    await _saveCurrentState();
    if (mounted) context.pop();
  }

  /// Navigate to the next receipt in the list WITHOUT saving this one.
  void _goToNextReceipt() {
    final nextIndex = widget.currentIndex + 1;
    if (nextIndex >= widget.allGroups.length) return;
    final nextGroup = widget.allGroups[nextIndex];
    // Use pushReplacement so the back button goes back to the list, not the
    // previous receipt — this keeps the nav stack clean.
    context.pushReplacement(
      '/receipt-review',
      extra: {
        'group': nextGroup,
        'allGroups': widget.allGroups,
        'currentIndex': nextIndex,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Read fresh group from state to reflect updates immediately
    final state = ref.watch(reviewProvider);
    final shopProfile = ref.watch(shopProvider);
    final configAsync = ref.watch(configProvider);
    final config = configAsync.value ?? {};
    final isAutomobile = config['industry'] == 'automobile';
    
    final group = state.groups.firstWhere(
        (g) => g.receiptNumber == widget.group.receiptNumber,
        orElse: () => widget.group);

    final header = group.header;
    final invoiceColumns = ref.watch(tableColumnsProvider('invoice_all'));

    // Line Item Hoisting: Red items (hasError) at the top!
    final sortedLineItems = List<ReviewRecord>.from(group.lineItems);
    sortedLineItems.sort((a, b) {
      if (a.hasError && !b.hasError) return -1;
      if (!a.hasError && b.hasError) return 1;
      // Sort in image order (top-to-bottom) using the lineItemBbox y-coordinate (index 1)
      final yA = (a.lineItemBbox != null && a.lineItemBbox!.length > 1) ? a.lineItemBbox![1] : double.infinity;
      final yB = (b.lineItemBbox != null && b.lineItemBbox!.length > 1) ? b.lineItemBbox![1] : double.infinity;
      
      if (yA != double.infinity && yB != double.infinity && (yA - yB).abs() > 0.001) {
        return yA.compareTo(yB);
      }
      return a.sortIndex.compareTo(b.sortIndex);
    });

    final laborItems = sortedLineItems.where((i) {
        final type = i.type?.toUpperCase() ?? '';
        return type.contains('LABOR') || type.contains('LABOUR') || type.contains('SERVICE');
    }).toList();

    // Items with null/empty type are grouped under Parts (same as _partsSubtotal)
    final partsItems = sortedLineItems.where((i) {
        final type = i.type?.toUpperCase() ?? '';
        return type.contains('PART') || (type.isEmpty && !laborItems.contains(i));
    }).toList();

    final otherItems = sortedLineItems.where((i) {
        return !partsItems.contains(i) && !laborItems.contains(i);
    }).toList();

    final hasAnyError = group.hasError;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text('Receipt #${group.receiptNumber}'),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.trash2, color: context.errorColor),
            tooltip: 'Delete Receipt',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Receipt'),
                  content: const Text(
                      'Are you sure you want to delete this receipt? This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => context.pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style:
                          FilledButton.styleFrom(backgroundColor: context.errorColor),
                      onPressed: () => context.pop(true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                await ref
                    .read(reviewProvider.notifier)
                    .deleteReceipt(group.receiptNumber);
                if (context.mounted) {
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Receipt deleted successfully')),
                  );
                }
              }
            },
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
                decoration: BoxDecoration(
                  color: context.surfaceColor,
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
                        httpHeaders: const {
                          'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
                        },
                        placeholder: (context, url) => const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white)),
                        errorWidget: (context, url, error) => Container(
                          color: context.surfaceColor,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                LucideIcons.imageOff,
                                color: Colors.white54,
                                size: 40),
                              const SizedBox(height: 8),
                              Text(
                                'Image unavailable',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                              ),
                            ],
                          ),
                        ),
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
                if (header != null) _buildHeaderCard(header, invoiceColumns),
                const SizedBox(height: 16),
                Text('Line Items',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.textSecondaryColor)),
                const SizedBox(height: 8),
                if (sortedLineItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                        child: Text('No line items found.',
                            style: TextStyle(color: context.textSecondaryColor))),
                  ),
                if (isAutomobile) ...[
                  if (partsItems.isNotEmpty) ...[
                    _buildCategoryHeader('Spare Parts', LucideIcons.package2, context.primaryColor),
                    ...partsItems.map((item) => _buildLineItemCard(item, isAutomobile)),
                    const SizedBox(height: 12),
                  ],
                  if (laborItems.isNotEmpty) ...[
                    _buildCategoryHeader('Servicing & Labor', LucideIcons.wrench, context.warningColor),
                    ...laborItems.map((item) => _buildLineItemCard(item, isAutomobile)),
                    const SizedBox(height: 12),
                  ],
                  if (otherItems.isNotEmpty) ...[
                    _buildCategoryHeader('Other Items', LucideIcons.box, context.textSecondaryColor),
                    ...otherItems.map((item) => _buildLineItemCard(item, isAutomobile)),
                    const SizedBox(height: 12),
                  ],
                ] else ...[
                  ...sortedLineItems.map((item) => _buildLineItemCard(item, isAutomobile)),
                  const SizedBox(height: 12),
                ],
                // ── Payment Summary ──────────────────────────────────────
                PaymentSummaryCard(
                  isAutomobile: isAutomobile,
                  gstMode: _gstMode,
                  partsSubtotal: _partsSubtotal(group),
                  laborSubtotal: _laborSubtotal(group),
                  gstAmount: _gstAmount(_partsSubtotal(group) + _laborSubtotal(group)),
                  grandTotal: _totalAfterGst(group),
                  originalTotal: group.header?.amount ??
                      (_partsSubtotal(group) + _laborSubtotal(group)),
                  onGstModeChanged: _saveGstMode,
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
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          boxShadow: [
            BoxShadow(
              color: context.textColor.withValues(alpha: context.isDark ? 0.3 : 0.05),
              offset: const Offset(0, -4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Total amount label ──────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Amount',
                    style: TextStyle(
                        color: context.textSecondaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(
                  '₹${_formatAmount(_totalAfterGst(group))}',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // ── Action buttons row ──────────────────────────────────
            Row(
              children: [
                // "Next Receipt →" — only shown when there is a next receipt
                if (widget.currentIndex >= 0 &&
                    widget.currentIndex < widget.allGroups.length - 1) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _goToNextReceipt,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.textSecondaryColor,
                        side: BorderSide(color: context.borderColor),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(LucideIcons.chevronsRight, size: 16),
                      label: const Text(
                        'Next Receipt',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                // "Confirm & Save" — always shown
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _markAllDone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasAnyError
                          ? context.warningColor
                          : context.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: hasAnyError
                        ? const Icon(LucideIcons.alertTriangle, size: 18)
                        : const Icon(LucideIcons.checkCircle, size: 18),
                    label: Text(
                      hasAnyError ? 'Save with Errors' : 'Confirm & Save ✨',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 18, color: Colors.white),
                label: const Text('Sync & Share', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  // ── Step 1: Flush any pending debounced edits ──────────────
                  // Dismissing the keyboard triggers _onFocusChange → _saveCurrentValue()
                  // immediately so state has the latest typed values.
                  FocusScope.of(context).unfocus();
                  await Future.delayed(const Duration(milliseconds: 150));
                  if (!context.mounted) return;

                  // ── Step 2: Re-read freshest state after flush ─────────────
                  final freshState = ref.read(reviewProvider);
                  final freshGroup = freshState.groups.firstWhere(
                    (g) => g.receiptNumber == widget.group.receiptNumber,
                    orElse: () => group,
                  );
                  final freshHeader = freshGroup.header;

                  // ── Step 3: Determine phone number & Ask if missing ────────
                  String phoneNumber = freshHeader
                          ?.extraFields['mobile_number']
                          ?.toString()
                          .trim() ??
                      '';
                  String? updatedPhoneNumber;

                  if (phoneNumber.isEmpty) {
                    final phoneController = TextEditingController();
                    // null → Cancelled | '' → Skip | '<digits>' → entered
                    final result = await showDialog<String?>(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => StatefulBuilder(
                        builder: (ctx, setDialogState) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF25D366)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const FaIcon(
                                    FontAwesomeIcons.whatsapp,
                                    color: Color(0xFF25D366),
                                    size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text('Send via WhatsApp',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No mobile number found for '
                                '${freshHeader?.customerName?.isNotEmpty == true ? freshHeader!.customerName! : "this customer"}.'
                                '\nEnter a number to share directly, or skip.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: context.textSecondaryColor,
                                    height: 1.5),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: phoneController,
                                keyboardType: TextInputType.phone,
                                autofocus: true,
                                decoration: InputDecoration(
                                  labelText: 'Mobile Number',
                                  hintText: '9876543210',
                                  prefixIcon: const Icon(
                                      LucideIcons.phone, size: 18),
                                  prefixText: '+91  ',
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 12),
                                ),
                                onChanged: (_) => setDialogState(() {}),
                              ),
                            ],
                          ),
                          actionsPadding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, null),
                              child: const Text('Cancel'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.pop(ctx, ''),
                              icon: const Icon(LucideIcons.skipForward,
                                  size: 14),
                              label: const Text('Skip'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: context.textSecondaryColor,
                                side: BorderSide(
                                    color: context.borderColor),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(8)),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: phoneController.text
                                      .trim()
                                      .isEmpty
                                  ? null
                                  : () => Navigator.pop(
                                      ctx, phoneController.text.trim()),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(8)),
                              ),
                              icon: const FaIcon(
                                  FontAwesomeIcons.whatsapp, size: 14),
                              label: const Text('Share'),
                            ),
                          ],
                        ),
                      ),
                    );

                    if (result == null) return; // Cancelled — abort

                    if (result.isNotEmpty) {
                      phoneNumber = result;
                      updatedPhoneNumber = result;
                    }
                    // result == '' → Skip: phoneNumber stays '' so WhatsApp
                    // opens the contact/share picker instead of a direct chat.
                  }

                  // ── Step 4: Build the WhatsApp message ────────────────────
                  double totalAmount = _totalAfterGst(freshGroup);
                  if (totalAmount == 0.0 && freshGroup.header != null) {
                    totalAmount = freshGroup.header!.amount;
                  }

                  final authState = ref.read(authProvider);
                  final username = authState.user?.username;

                  final double balanceDue =
                      _paymentMode == 'Credit' ? totalAmount - _receivedAmount : 0.0;

                  final shareUrl = await ReceiptShareLinkUtils.buildSignedOrLegacyLink(
                    receiptNumber: freshGroup.receiptNumber,
                    username: username,
                    gstMode: _gstMode.name,
                  );
                  if (shareUrl == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not generate secure receipt link. Please try again.'),
                        ),
                      );
                    }
                    return;
                  }

                  final shopName = shopProfile.name.isNotEmpty ? shopProfile.name : 'Our Shop';

                  OrderPaymentStatus status;
                  if (_paymentMode == 'Cash') {
                    status = OrderPaymentStatus.fullyPaid;
                  } else {
                    if (_receivedAmount >= totalAmount) {
                      status = OrderPaymentStatus.fullyPaid;
                    } else if (_receivedAmount > 0) {
                      status = OrderPaymentStatus.partiallyPaid;
                    } else {
                      status = OrderPaymentStatus.unpaid;
                    }
                  }

                  final Set<String> ignoredExtraFields = {
                    'total_bill_amount', 'total bill amount', 'amount',
                    'calculated_amount', 'amount_mismatch', 'receipt_number',
                    'date', 'customer_name', 'mobile_number', 'mobile number',
                    'mobile', 'receipt_link', 'audit_findings',
                    'taxable_row_ids', 'gst_mode',
                  };

                  final Map<String, String> resolvedExtraFields = {};
                  if (freshHeader?.extraFields != null) {
                    freshHeader!.extraFields.forEach((key, value) {
                      final configLabel = invoiceColumns.firstWhere(
                        (c) => c['db_column'] == key,
                        orElse: () => {'label': key},
                      )['label'].toString();
                      final lowerKey = key.toString().toLowerCase();
                      final lowerLabel = configLabel.toLowerCase();
                      if (value != null && value.toString().isNotEmpty &&
                          !ignoredExtraFields.contains(lowerKey) &&
                          !ignoredExtraFields.contains(lowerLabel)) {
                        resolvedExtraFields[configLabel] = value.toString();
                      }
                    });
                  }

                  final caption = WhatsAppUtils.getWhatsAppCaption(
                    status: status,
                    customerName: freshHeader?.customerName?.isNotEmpty == true
                        ? freshHeader!.customerName!
                        : 'Customer',
                    businessName: shopName,
                    orderNumber: freshGroup.receiptNumber,
                    totalAmount: totalAmount,
                    paidAmount: _receivedAmount,
                    pendingAmount: balanceDue,
                    extraFields: resolvedExtraFields,
                  );
                  final message =
                      '$caption\n\nView your complete digital receipt and order details here:\n$shareUrl\n\nThank you for your business!\n— *${shopName.trim()}*';

                  // ── Step 5: Open WhatsApp ──────────────────────────────────
                  if (!context.mounted) return;
                  final opened = await WhatsAppUtils.openWhatsAppChat(
                    phone: phoneNumber,
                    message: message,
                  );
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Could not open WhatsApp. Please ensure it is installed.')),
                    );
                  }

                  // ── Step 6: Sync & Finish (Save in background & Pop) ────────
                  _saveCurrentState(updatePhoneNumber: updatedPhoneNumber);
                  
                  if (context.mounted) {
                    if (widget.currentIndex >= 0 && widget.currentIndex < widget.allGroups.length - 1) {
                      _goToNextReceipt();
                    } else {
                      context.pop();
                    }
                  }
                },
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
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Payment Type',
                  style: TextStyle(
                      color: context.textSecondaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              Container(
                decoration: BoxDecoration(
                  color: context.isDark ? context.primaryColor.withValues(alpha: 0.1) : context.borderColor.withValues(alpha: 0.2),
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
                            ? context.primaryColor
                            : context.textSecondaryColor.withValues(alpha: 0.3),
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
                          borderSide: BorderSide(color: context.borderColor)),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: context.borderColor)),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: context.primaryColor)),
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
                Text('Balance Due',
                    style: TextStyle(
                        color: context.errorColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('₹ ',
                    style: TextStyle(
                        color: context.errorColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500)),
                SizedBox(
                  width: 100,
                  child: Text(
                    _formatAmount(grandTotal - _receivedAmount),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: context.errorColor,
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
                    TextStyle(fontSize: 14, color: context.textSecondaryColor),
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: context.borderColor)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: context.borderColor)),
              ),
              maxLines: 2,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCard(ReviewRecord header, List<dynamic> columns) {
    final isError = header.hasError;
    final isDone = header.verificationStatus == 'Done';

    Color borderColor = context.borderColor;
    Color bgColor = context.surfaceColor;
    if (isError) {
      borderColor = context.errorColor;
      bgColor = context.errorColor.withValues(alpha: 0.1);
    } else if (isDone) {
      borderColor = context.successColor;
      bgColor = context.successColor.withValues(alpha: 0.1);
    }

    final dynamicColumns = columns.where((c) {
      final dbCol = c['db_column'] as String?;
      final isEditable = c['editable'] == true || c['editable'] == 'true';
      final isStandardLineItem = ['description', 'quantity', 'rate', 'amount', 'amount_mismatch', 'verification_status', 'audit_findings', 'receipt_link'].contains(dbCol);
      final isStandardHeader = ['receipt_number', 'date'].contains(dbCol);
      return isEditable && dbCol != null && !isStandardLineItem && !isStandardHeader;
    }).toList();

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
              Icon(LucideIcons.fileText,
                  size: 16, color: context.textSecondaryColor),
              const SizedBox(width: 8),
              Text('Header Details',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: context.textSecondaryColor)),
              const Spacer(),
              if (isError)
                Icon(LucideIcons.alertCircle,
                    color: context.errorColor, size: 16),
              if (!isError && isDone)
                Icon(LucideIcons.checkCircle,
                    color: context.successColor, size: 16),
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
                                color: context.errorColor, width: 1.5),
                          )
                        : null,
                    focusedBorder: header.hasReceiptDoubt
                        ? OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: context.errorColor, width: 2),
                          )
                        : null,
                    fillColor: header.hasReceiptDoubt
                        ? context.errorColor.withValues(alpha: 0.1)
                        : context.surfaceColor,
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
                                    color: context.errorColor, width: 1.5),
                              )
                            : null,
                        focusedBorder: header.hasDateDoubt
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: context.errorColor, width: 2),
                              )
                            : null,
                        fillColor: header.hasDateDoubt
                            ? context.errorColor.withValues(alpha: 0.1)
                            : context.surfaceColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Dynamic fields
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: dynamicColumns.map((c) {
              final dbCol = c['db_column'] as String;
              final label = c['label'] as String;
              
              String value = '';
              if (dbCol == 'customer_name') {
                value = header.customerName ?? '';
              } else {
                value = header.extraFields[dbCol]?.toString() ?? '';
              }

              return FractionallySizedBox(
                widthFactor: ['customer_name'].contains(dbCol) ? 1.0 : 0.48,
                child: DebouncedReviewField(
                  initialValue: value,
                  keyboardType: (dbCol.contains('mobile') || dbCol.contains('phone')) ? TextInputType.phone : TextInputType.text,
                  decoration: _inputDecoration(label).copyWith(
                    prefixIcon: dbCol == 'customer_name' 
                      ? const Icon(LucideIcons.user, size: 16) 
                      : (dbCol.contains('vehicle') || dbCol.contains('car')) 
                        ? const Icon(LucideIcons.car, size: 16)
                        : (dbCol.contains('mobile') || dbCol.contains('phone'))
                          ? const Icon(LucideIcons.phone, size: 16)
                          : const Icon(LucideIcons.edit2, size: 16),
                    prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 0),
                  ),
                  onSaved: (val) {
                    if (val != value) {
                      ReviewRecord newRecord;
                      if (dbCol == 'customer_name') {
                        newRecord = header.copyWith(customerName: val);
                      } else if (dbCol == 'mobile_number') {
                        final newExtra = Map<String, dynamic>.from(header.extraFields);
                        newExtra[dbCol] = val;
                        newRecord = header.copyWith(
                          extraFields: newExtra,
                          mobileNumber: val, // Sync top-level field
                        );
                      } else {
                        final newExtra = Map<String, dynamic>.from(header.extraFields);
                        newExtra[dbCol] = val;
                        newRecord = header.copyWith(extraFields: newExtra);
                      }
                      ref.read(reviewProvider.notifier).updateDateRecord(newRecord);
                    }
                  },
                ),
              );
            }).toList(),
          ),
          if (header.verificationStatus == 'Duplicate Receipt Number')
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text('Error: Duplicate Receipt Number. Please fix it.',
                  style: TextStyle(
                      color: context.errorColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            )
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
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
                  color: color.withValues(alpha: context.isDark ? 0.9 : 1.0),
                  letterSpacing: 1.0)),
        ],
      ),
    );
  }

  Widget _buildLineItemCard(ReviewRecord item, bool isAutomobile) {
    final isError = item.hasError;
    final isDone = item.verificationStatus == 'Done';

    Color borderColor = context.borderColor;
    Color bgColor = context.surfaceColor;
    if (isError) {
      borderColor = context.errorColor;
      bgColor = context.errorColor.withValues(alpha: 0.1);
    } else if (isDone) {
      borderColor = context.successColor;
      bgColor = context.successColor.withValues(alpha: 0.1);
    }

    // Checking if amount mismatch exists
    final hasMismatch =
        item.amountMismatch != null && item.amountMismatch!.abs() >= 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isError ? 2 : 1),
        boxShadow: context.premiumShadow,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: context.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Item #${item.rowId}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.primaryColor,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Item'),
                      content: const Text(
                          'Are you sure you want to delete this item?'),
                      actions: [
                        TextButton(
                          onPressed: () => context.pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: context.errorColor),
                          onPressed: () => context.pop(true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && mounted) {
                    await ref
                        .read(reviewProvider.notifier)
                        .deleteRecord(item.rowId, item.receiptNumber);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Item deleted'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: context.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(LucideIcons.trash2, size: 14, color: context.errorColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: context.primaryColor),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text('×',
                      style: TextStyle(color: context.textSecondaryColor)),
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
                Icon(LucideIcons.alertTriangle,
                    size: 14, color: context.errorColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                      hasMismatch
                          ? 'Math Error: Qty × Rate ≠ Total'
                          : 'Missing required fields',
                      style: TextStyle(
                          color: context.errorColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
          if (isAutomobile) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _PartLaborToggle(
                  isPart: true,
                  selected: (item.type?.toLowerCase() ?? '') != 'labor' && 
                            (item.type?.toLowerCase() ?? '') != 'labour' && 
                            (item.type?.toLowerCase() ?? '') != 'service',
                  onTap: () {
                    final newRecord = item.copyWith(type: 'Part');
                    ref.read(reviewProvider.notifier).updateAmountRecord(newRecord);
                  },
                ),
                const SizedBox(width: 8),
                _PartLaborToggle(
                  isPart: false,
                  selected: (item.type?.toLowerCase() ?? '') == 'labor' || 
                            (item.type?.toLowerCase() ?? '') == 'labour' || 
                            (item.type?.toLowerCase() ?? '') == 'service',
                  onTap: () {
                    final newRecord = item.copyWith(type: 'Labor');
                    ref.read(reviewProvider.notifier).updateAmountRecord(newRecord);
                  },
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
      labelStyle: TextStyle(fontSize: 12, color: context.textSecondaryColor),
      filled: true,
      fillColor: context.surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: context.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: context.borderColor),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
    // Flush any pending edit before the widget is removed from the tree.
    // This covers the case where the debounce timer hasn't fired yet and the
    // user navigates away or the list rebuilds, which would otherwise silently
    // discard the last keystroke(s).
    _saveCurrentValue();
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
          color: isSelected ? context.successColor : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: context.successColor.withValues(alpha: 0.3),
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
            color: selected ? selectedColor : context.borderColor,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? selectedColor : context.textSecondaryColor,
          ),
        ),
      ),
    );
  }
}
