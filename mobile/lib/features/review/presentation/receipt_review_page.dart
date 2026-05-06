import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/shared/widgets/robust_receipt_image.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/review/domain/models/review_models.dart';
import 'package:mobile/features/review/presentation/providers/review_provider.dart';
import 'package:mobile/core/utils/whatsapp_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:mobile/features/shared/presentation/widgets/payment_summary_card.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/settings/presentation/providers/shop_provider.dart';
import 'package:mobile/features/config/presentation/providers/config_provider.dart';
import 'package:mobile/core/utils/receipt_share_link_utils.dart';
import 'package:mobile/features/review/presentation/widgets/customer_autocomplete_field.dart';
import 'package:mobile/shared/widgets/app_toast.dart';



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
  // ── Payment Summary state ──────────────────────────────────────────
  GstMode _gstMode = GstMode.none;

  final TextEditingController _creditDetailsController = TextEditingController();

  // ── Mobile Number ──────────────────────────────────────────────────
  final TextEditingController _mobileController = TextEditingController();
  final FocusNode _mobileFocusNode = FocusNode();

  double _receivedAmount = 0.0;
  double? _manualTotalAmount;
  bool _isTotalManuallyEdited = false;

  /// True when the user tried to save without a customer name.
  /// Turns the customer banner field red until user fills it in.
  bool _customerNameMissing = false;

  /// Snapshot of allGroups taken at initState — immune to provider clears.
  /// This prevents _goToNextReceipt() from breaking when syncAndFinish()
  /// clears groups while we are still mounted.
  late List<InvoiceReviewGroup> _localAllGroups;

  /// True when we have initiated navigation away — suppresses rebuilds
  /// that happen during the GoRouter transition (blank screen guard).
  bool _isNavigatingAway = false;

  /// Currently selected party from the top customer banner.
  /// Null means name is typed but not matched to an existing party.

  @override
  void initState() {
    super.initState();
    _localAllGroups = List<InvoiceReviewGroup>.from(widget.allGroups);
    _loadPersistedSettings();
    _initMobileNumber();
    // NOTE: Share link pre-fetch removed from initState().
    // It is now lazy — fetched only when WhatsApp button is tapped.
  }

  void _initMobileNumber() {
    final header = widget.group.header;
    if (header == null) return;
    // Priority: direct column > extraFields > empty
    final mobile = header.mobileNumber?.trim().isNotEmpty == true
        ? header.mobileNumber!
        : (header.extraFields['mobile_number']?.toString().trim() ?? '');
    _mobileController.text = mobile;
    // Auto-save when user leaves the field
    _mobileFocusNode.addListener(() {
      if (!_mobileFocusNode.hasFocus) {
        _saveMobileNumberFromController();
      }
    });
  }

  @override
  void dispose() {
    _creditDetailsController.dispose();
    _mobileController.dispose();
    _mobileFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPersistedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final receipt = widget.group.receiptNumber;

    // Load manual total amount (AIGemini extracted Total Bill)
    final savedTotalAmount = prefs.getDouble('total_amount_$receipt');
    if (savedTotalAmount != null && mounted) {
      setState(() {
        _manualTotalAmount = savedTotalAmount;
        _isTotalManuallyEdited = true;
      });
    } else if (widget.group.header?.totalBillAmount != null && widget.group.header!.totalBillAmount! > 0 && mounted) {
      setState(() {
        _manualTotalAmount = widget.group.header!.totalBillAmount;
        _isTotalManuallyEdited = true;
      });
    }

    // Load received amount (Priority: Saved > Computed from balance_due > Extracted Received)
    // IMPORTANT: receivedAmount from DB may be 0 when AI didn't extract it correctly.
    // If balance_due is set (which is more reliable), compute received = total - balance_due.
    final savedReceivedAmount = prefs.getDouble('received_amount_$receipt');
    final header = widget.group.header;
    if (savedReceivedAmount != null && mounted) {
      // User previously saved a value — trust it completely
      setState(() {
        _receivedAmount = savedReceivedAmount;
      });
    } else if (header?.balanceDue != null && header!.balanceDue! > 0 && mounted) {
      // balance_due is more reliably extracted by AI (it's a clear field on the bill)
      // Compute received = total_bill - balance_due
      final total = _activeTotalAmount(widget.group);
      final computed = (total - header.balanceDue!).clamp(0.0, total);
      setState(() {
        _receivedAmount = computed;
      });
    } else if (header?.receivedAmount != null && header!.receivedAmount! > 0 && mounted) {
      // AI explicitly extracted a non-zero received amount
      setState(() {
        _receivedAmount = header.receivedAmount!;
      });
    } else if (mounted) {
      // Default: full payment (no credit info found)
      setState(() {
        _receivedAmount = _activeTotalAmount(widget.group);
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

  Future<void> _saveReceivedAmount(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('received_amount_${widget.group.receiptNumber}', amount);
  }

  Future<void> _saveTotalAmount(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('total_amount_${widget.group.receiptNumber}', amount);
  }

  Future<void> _saveGstMode(GstMode mode) async {
    setState(() => _gstMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gst_mode_${widget.group.receiptNumber}', mode.name);
  }

  // ── GST computed helpers ─────────────────────────────────
  double _partsSubtotal(InvoiceReviewGroup group) {
    final typed = group.lineItems.where((i) {
      final type = i.type?.toUpperCase() ?? '';
      return type.isNotEmpty;
    }).toList();

    if (typed.isEmpty) {
      return group.lineItems.fold(0.0, (s, i) => s + i.amount);
    }

    return group.lineItems
        .where((i) {
          final type = i.type?.toUpperCase() ?? '';
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
    return totalSubtotal;
  }

  double _activeTotalAmount(InvoiceReviewGroup group) {
    if (_isTotalManuallyEdited && _manualTotalAmount != null) {
      return _manualTotalAmount!;
    }
    return _totalAfterGst(group);
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/review');
    }
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
              child: RobustReceiptImageFullScreen(
                imageUrl: imageUrl,
                heroTag: 'receipt_image_${widget.group.receiptNumber}',
                maxRetries: 3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatInput(double? amount) {
    return CurrencyFormatter.formatInput(amount);
  }

  Future<void> _saveCurrentState({String? updatePhoneNumber}) async {
    final notifier = ref.read(reviewProvider.notifier);
    final liveState = ref.read(reviewProvider);
    final group = liveState.groups.firstWhere(
      (g) => g.receiptNumber == widget.group.receiptNumber,
      orElse: () => widget.group,
    );
    final header = group.header;

    if (header != null) {
      final grandTotal = _activeTotalAmount(group);
      final balanceDue = grandTotal - _receivedAmount;
      final paymentMode = balanceDue > 0 ? 'Credit' : 'Cash';
      
      var newRecord = header.copyWith(
          verificationStatus: 'Done',
          paymentMode: paymentMode,
          amount: grandTotal,
          receivedAmount: _receivedAmount,
          balanceDue: balanceDue,
          totalBillAmount: grandTotal,
          customerDetails: balanceDue > 0 ? _creditDetailsController.text : null,
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
    // ── Validation: customer name is required ─────────────────────────
    final liveState = ref.read(reviewProvider);
    final liveGroup = liveState.groups.firstWhere(
      (g) => g.receiptNumber == widget.group.receiptNumber,
      orElse: () => widget.group,
    );
    final customerName = liveGroup.header?.customerName?.trim() ?? '';
    if (customerName.isEmpty) {
      setState(() => _customerNameMissing = true);
      AppToast.showError(
        context,
        'Please enter the customer name before saving.',
        title: 'Customer Required',
      );
      // Scroll to the top so the red field is visible
      return;
    }

    if (liveGroup.hasError) {
      // Gather specific error messages
      final List<String> errorMessages = [];
      if (liveGroup.header?.verificationStatus.toLowerCase() == 'duplicate receipt number') {
        errorMessages.add('• Duplicate receipt number');
      }
      if (liveGroup.header?.date.trim().isEmpty == true) {
        errorMessages.add('• Receipt date is missing');
      }
      
      int mismatchCount = 0;
      for (var item in liveGroup.lineItems) {
        if (item.amountMismatch != null && item.amountMismatch!.abs() >= 1.0) {
          mismatchCount++;
        }
      }
      if (mismatchCount > 0) {
        errorMessages.add('• $mismatchCount line item(s) have amount mismatches');
      }

      if (errorMessages.isEmpty) {
        errorMessages.add('• Some fields have errors');
      }

      // Show dialog
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(LucideIcons.alertTriangle, color: context.errorColor),
              const SizedBox(width: 8),
              const Text('Errors Found', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please review the following errors before saving:'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.errorColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  errorMessages.join('\n'),
                  style: TextStyle(color: context.errorColor, fontWeight: FontWeight.w600, height: 1.5, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Are you sure you want to save with these errors?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: context.errorColor),
              onPressed: () => context.pop(true),
              child: const Text('Save Anyway'),
            ),
          ],
        ),
      );

      if (proceed != true) {
        return; // User cancelled
      }
    }

    await _saveCurrentState();
    if (!mounted) return;

    final isLast = widget.currentIndex == -1 ||
                   widget.currentIndex == _localAllGroups.length - 1;

    if (isLast) {
      // ⚡ Option B: Navigate home FIRST, then sync in background.
      // This eliminates the blank screen caused by groups being cleared
      // while this page is still in the widget tree.
      setState(() => _isNavigatingAway = true);
      AppToast.showSuccess(context, 'Syncing your receipts in background…',
          title: 'Saved ✔');
      context.go('/');
      // Sync after navigation — the home screen shows a banner if needed
      ref.read(reviewProvider.notifier).syncAndFinish();
    } else {
      await _goToNextReceipt();
    }
  }

  Future<void> _goToNextReceipt() async {
    await _saveCurrentState();
    if (!mounted) return;
    
    final nextIndex = widget.currentIndex + 1;
    if (nextIndex >= _localAllGroups.length) return;
    final nextGroup = _localAllGroups[nextIndex];
    setState(() => _isNavigatingAway = true);
    context.pushReplacement(
      '/receipt-review',
      extra: {
        'group': nextGroup,
        'allGroups': _localAllGroups,
        'currentIndex': nextIndex,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Blank-screen guard: if we have already initiated navigation away
    // (e.g. after Sync & Finish), return an empty transparent scaffold so
    // there is zero grey flash during the GoRouter transition.
    if (_isNavigatingAway) {
      return Scaffold(backgroundColor: context.backgroundColor);
    }

    final state = ref.watch(reviewProvider);
    final configAsync = ref.watch(configProvider);

    // ✅ Config loading guard: configProvider re-fetches every time authProvider
    // changes (e.g. _checkInitialAuth() completing). While it's loading, show a
    // skeleton screen rather than building with incomplete data — this prevents
    // the "visible for < 1 second then blank" race condition caused by column
    // config resolving AFTER first render and triggering a crash in _buildHeaderCard.
    if (configAsync.isLoading) {
      return Scaffold(
        backgroundColor: context.backgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: _handleBack,
          ),
          title: Text('Receipt #${widget.group.receiptNumber}'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final config = configAsync.value ?? {};
    final isAutomobile = config['industry'] == 'automobile';

    ref.listen<ReviewState>(reviewProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        AppToast.showError(context, next.error!, title: 'Sync Failed');
      }
    });
    
    // Use live group from provider; fall back to widget.group only if still present.
    // When groups are cleared after sync, _isNavigatingAway is already true so
    // we never reach here with an empty groups list.
    final group = state.groups.firstWhere(
        (g) => g.receiptNumber == widget.group.receiptNumber,
        orElse: () => widget.group);

    final header = group.header;
    final invoiceColumns = ref.watch(tableColumnsProvider('invoice_all'));

    final sortedLineItems = List<ReviewRecord>.from(group.lineItems);
    sortedLineItems.sort((a, b) {
      if (a.hasError && !b.hasError) return -1;
      if (!a.hasError && b.hasError) return 1;
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

    final partsItems = sortedLineItems.where((i) {
        final type = i.type?.toUpperCase() ?? '';
        return type.contains('PART') || (type.isEmpty && !laborItems.contains(i));
    }).toList();

    final otherItems = sortedLineItems.where((i) {
        return !partsItems.contains(i) && !laborItems.contains(i);
    }).toList();

    final hasAnyError = group.hasError;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: context.backgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: _handleBack,
          ),
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
                        style: FilledButton.styleFrom(
                            backgroundColor: context.errorColor),
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
                    _handleBack();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Receipt deleted successfully')),
                    );
                  }
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // ── Customer Name banner — always at the very top ──────────────
                  if (header != null)
                    _buildTopCustomerBanner(header),
                  if (header != null && header.receiptLink.isNotEmpty)
                    GestureDetector(
                      onTap: () => _showFullImage(header.receiptLink),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.25,
                        width: double.infinity,
                        decoration: BoxDecoration(color: context.surfaceColor),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            RobustReceiptImage(
                              imageUrl: header.receiptLink,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              heroTag: 'receipt_image_${group.receiptNumber}',
                              maxRetries: 3,
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.maximize, color: Colors.white, size: 14),
                                    SizedBox(width: 6),
                                    Text('Tap to expand', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (header != null)
                          _buildHeaderCard(header, invoiceColumns, isAutomobile),
                        const SizedBox(height: 16),
                        Text('Line Items',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: context.textSecondaryColor)),
                        const SizedBox(height: 8),
                        if (sortedLineItems.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: Text('No line items found.')),
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
                        PaymentSummaryCard(
                          isAutomobile: isAutomobile,
                          gstMode: _gstMode,
                          partsSubtotal: _partsSubtotal(group),
                          laborSubtotal: _laborSubtotal(group),
                          gstAmount: _gstAmount(_partsSubtotal(group) + _laborSubtotal(group)),
                          grandTotal: _activeTotalAmount(group),
                          originalTotal: group.header?.amount ?? (_partsSubtotal(group) + _laborSubtotal(group)),
                          onGstModeChanged: _saveGstMode,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildActionPanel(group, hasAnyError),
          ],
        ),
      ),
    );
  }

  Widget _buildActionPanel(InvoiceReviewGroup group, bool hasAnyError) {
    final state = ref.watch(reviewProvider);
    final total = _activeTotalAmount(group);
    final balance = total - _receivedAmount;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: context.textColor.withValues(alpha: context.isDark ? 0.3 : 0.08),
            offset: const Offset(0, -6),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text('Total (₹)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.textSecondaryColor)),
                    ),
                    DebouncedReviewField(
                      initialValue: _formatInput(total),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.borderColor)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.primaryColor, width: 2)),
                        fillColor: context.surfaceColor,
                        filled: true,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      onSaved: (val) {
                        final nt = double.tryParse(val);
                        if (nt != null) {
                          final wasPaid = (total - _receivedAmount).abs() < 0.01;
                          setState(() {
                            _manualTotalAmount = nt;
                            _isTotalManuallyEdited = true;
                            if (wasPaid) _receivedAmount = nt;
                          });
                          _saveTotalAmount(nt);
                          if (wasPaid) _saveReceivedAmount(nt);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text('Received (₹)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.primaryColor)),
                    ),
                    DebouncedReviewField(
                      initialValue: _formatInput(_receivedAmount),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.primaryColor.withValues(alpha: 0.5))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.primaryColor, width: 2)),
                        fillColor: context.primaryColor.withValues(alpha: 0.05),
                        filled: true,
                      ),
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: context.primaryColor),
                      onSaved: (val) {
                        final nr = double.tryParse(val) ?? 0.0;
                        setState(() => _receivedAmount = nr);
                        _saveReceivedAmount(nr);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text('Balance (₹)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.errorColor)),
                    ),
                    DebouncedReviewField(
                      initialValue: _formatInput(balance),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.errorColor.withValues(alpha: 0.5))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.errorColor, width: 2)),
                        fillColor: context.errorColor.withValues(alpha: 0.05),
                        filled: true,
                      ),
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: context.errorColor),
                      onSaved: (val) {
                        final nb = double.tryParse(val) ?? 0.0;
                        final nr = (total - nb).clamp(0.0, total);
                        setState(() => _receivedAmount = nr);
                        _saveReceivedAmount(nr);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [context.primaryColor, context.primaryColor.withValues(alpha: 0.8)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: state.isSyncing ? null : _markAllDone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: state.isSyncing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(LucideIcons.checkCircle, size: 20),
                    label: Text(
                      state.isSyncing
                          ? 'Saving...'
                          : (widget.currentIndex == -1 || widget.currentIndex == widget.allGroups.length - 1
                              ? 'Sync & Finish'
                              : 'Save & Next'),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
                ),
                child: IconButton(
                  icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 24, color: Color(0xFF25D366)),
                  onPressed: state.isSyncing ? null : _handleWhatsAppShare,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleWhatsAppShare() async {
    final state = ref.read(reviewProvider);
    final group = state.groups.firstWhere(
      (g) => g.receiptNumber == widget.group.receiptNumber,
      orElse: () => widget.group,
    );
    final shopProfile = ref.read(shopProvider);

    FocusScope.of(context).unfocus();
    await _saveCurrentState();

    final freshState = ref.read(reviewProvider);
    final freshGroup = freshState.groups.firstWhere(
      (g) => g.receiptNumber == widget.group.receiptNumber,
      orElse: () => group,
    );
    final freshHeader = freshGroup.header;

    String phoneNumber = freshHeader?.extraFields['mobile_number']?.toString().trim() ?? '';
    double totalAmount = _activeTotalAmount(freshGroup);
    if (totalAmount == 0.0 && freshGroup.header != null) {
      totalAmount = freshGroup.header!.amount;
    }

    final authState = ref.read(authProvider);
    final username = authState.user?.username;
    final double balanceDue = totalAmount - _receivedAmount;

    // 📲 Lazy share link: fetch only now (not eagerly in initState)
    final String? shareUrl = await ReceiptShareLinkUtils.buildSignedOrLegacyLink(
      receiptNumber: freshGroup.receiptNumber,
      username: username,
    );

    if (shareUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not generate receipt link.')));
      }
      return;
    }

    final shopName = shopProfile.name.isNotEmpty ? shopProfile.name : 'Our Shop';
    final paymentMode = balanceDue > 0 ? 'Credit' : 'Cash';
    OrderPaymentStatus status = paymentMode == 'Cash'
        ? OrderPaymentStatus.fullyPaid
        : (_receivedAmount > 0 ? OrderPaymentStatus.partiallyPaid : OrderPaymentStatus.unpaid);

    final Map<String, String> resolvedExtraFields = {};
    if (freshHeader?.extraFields != null) {
      final Set<String> ignored = {'total_bill_amount', 'amount', 'receipt_number', 'date', 'customer_name', 'mobile_number', 'receipt_link', 'gst_mode'};
      freshHeader!.extraFields.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty && !ignored.contains(key.toString().toLowerCase())) {
          resolvedExtraFields[key.toString()] = value.toString();
        }
      });
    }

    final caption = WhatsAppUtils.getWhatsAppCaption(
      status: status,
      customerName: freshHeader?.customerName?.isNotEmpty == true ? freshHeader!.customerName! : 'Customer',
      businessName: shopName,
      orderNumber: freshGroup.receiptNumber,
      totalAmount: totalAmount,
      paidAmount: _receivedAmount,
      pendingAmount: balanceDue,
      extraFields: resolvedExtraFields,
    );

    if (!mounted) return;
    final shareResult = await WhatsAppUtils.shareReceiptWithOptions(
      context,
      phone: phoneNumber,
      shareUrl: shareUrl,
      imageUrl: freshHeader?.receiptLink,
      caption: caption,
      shopName: shopName,
    );

    if (shareResult == null) return;
    if (shareResult.isNotEmpty && shareResult != phoneNumber) {
      await _saveCurrentState(updatePhoneNumber: shareResult);
    }

    // ✅ WhatsApp is a side-action, not a terminal action.
    // Stay on this page so the user can continue reviewing the remaining receipts.
    // They will explicitly tap "Sync & Finish" / "Save & Next" when ready.
    if (mounted) {
      AppToast.showSuccess(
        context,
        'Receipt shared! Continue reviewing, then tap Sync & Finish when done.',
        title: 'Sent on WhatsApp ✓',
      );
    }
  }

  Widget _buildCategoryHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: color.withValues(alpha: 0.2))),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(ReviewRecord header, List<dynamic> columns, bool isAutomobile) {
    final fields = <Widget>[];
    for (var col in columns) {
      // Safe-cast: skip malformed column entries to prevent TypeError → blank screen
      final key = col['name']?.toString();
      final label = col['label']?.toString();
      if (key == null || key.isEmpty || label == null) continue;
      if (key == 'customer_name') continue;
      if (key == 'mobile_number') continue;
      if (key == 'amount' || key == 'total_bill_amount') continue;
      if (key == 'receipt_number' || key == 'date') continue;

      final value = header.extraFields[key]?.toString() ?? '';
      if (value.isNotEmpty) {
        fields.add(_buildHeaderField(label, value));
      }
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), 
        side: BorderSide(color: context.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── DATE + RECEIPT # row — both fully editable ───────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DATE',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: context.textSecondaryColor)),
                      const SizedBox(height: 4),
                      TextFormField(
                        key: ValueKey('date_${header.date}'),
                        initialValue: header.date,
                        readOnly: true,
                        onTap: () async {
                          DateTime initialDate = DateTime.now();
                          try {
                            final parts = header.date.split('-');
                            if (parts.length == 3) {
                              if (parts[0].length == 4) {
                                initialDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
                              } else {
                                initialDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
                              }
                            } else if (header.date.contains('/')) {
                               final parts2 = header.date.split('/');
                               if (parts2.length == 3) {
                                 if (parts2[0].length == 4) {
                                   initialDate = DateTime(int.parse(parts2[0]), int.parse(parts2[1]), int.parse(parts2[2]));
                                 } else {
                                   initialDate = DateTime(int.parse(parts2[2]), int.parse(parts2[1]), int.parse(parts2[0]));
                                 }
                               }
                            }
                          } catch (_) {}
                          
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: initialDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2101),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: context.isDark ? ColorScheme.dark(
                                    primary: context.primaryColor,
                                  ) : ColorScheme.light(
                                    primary: context.primaryColor,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            final formattedDate = "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";
                            final notifier = ref.read(reviewProvider.notifier);
                            notifier.updateDateRecord(header.copyWith(date: formattedDate));
                          }
                        },
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: header.hasDateDoubt
                                      ? context.warningColor
                                      : context.borderColor)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: context.primaryColor, width: 2)),
                          fillColor: header.hasDateDoubt
                              ? context.warningColor.withValues(alpha: 0.06)
                              : context.surfaceColor,
                          filled: true,
                          hintText: 'DD-MM-YYYY',
                          suffixIcon: header.hasDateDoubt
                              ? Tooltip(
                                  message: 'Low confidence — please verify',
                                  child: Icon(Icons.warning_amber_rounded,
                                      size: 16, color: context.warningColor))
                              : Icon(LucideIcons.calendarDays, size: 16, color: context.textSecondaryColor),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RECEIPT #',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: context.textSecondaryColor)),
                      const SizedBox(height: 4),
                      DebouncedReviewField(
                        initialValue: header.receiptNumber,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: header.hasReceiptDoubt
                                      ? context.warningColor
                                      : context.borderColor)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: context.primaryColor, width: 2)),
                          fillColor: header.hasReceiptDoubt
                              ? context.warningColor.withValues(alpha: 0.06)
                              : context.surfaceColor,
                          filled: true,
                          hintText: 'Receipt #',
                          suffixIcon: header.hasReceiptDoubt
                              ? Tooltip(
                                  message: 'Low confidence — please verify',
                                  child: Icon(Icons.warning_amber_rounded,
                                      size: 16, color: context.warningColor))
                              : null,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        onSaved: (val) {
                          if (val.trim().isNotEmpty) {
                            final notifier = ref.read(reviewProvider.notifier);
                            notifier.updateDateRecord(header.copyWith(receiptNumber: val.trim()));
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (fields.isNotEmpty) ...[
              const Divider(height: 24),
              ...fields,
            ],
          ],
        ),
      ),
    );
  }

  /// Top-of-page customer banner — the most prominent element after the AppBar.
  /// Encourages owners to tag the customer before anything else.
  Widget _buildTopCustomerBanner(ReviewRecord header) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _customerNameMissing
            ? context.errorColor.withValues(alpha: 0.05)
            : context.primaryColor.withValues(alpha: 0.05),
        border: _customerNameMissing
            ? Border(
                left: BorderSide(color: context.errorColor, width: 3),
              )
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.userPlus,
                  size: 16,
                  color: _customerNameMissing
                      ? context.errorColor
                      : context.primaryColor),
              const SizedBox(width: 8),
              Text(
                'CUSTOMER DETAILS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: _customerNameMissing
                      ? context.errorColor
                      : context.primaryColor,
                ),
              ),
              if (_customerNameMissing) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.errorColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'REQUIRED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_customerNameMissing)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text(
                'Customer name is required before saving.',
                style: TextStyle(fontSize: 11, color: context.errorColor, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 12),
          CustomerAutocompleteField(
            initialValue: header.customerName ?? '',
            label: 'Search or enter customer name...',
            hasError: _customerNameMissing,
            onSaved: (val) {
              if (val.isNotEmpty && _customerNameMissing) {
                setState(() => _customerNameMissing = false);
              }
              final notifier = ref.read(reviewProvider.notifier);
              notifier.updateDateRecord(header.copyWith(customerName: val));
            },
            onCustomerSelected: (party) {
              // Clear the error as soon as a customer is selected
              if (_customerNameMissing) setState(() => _customerNameMissing = false);
              // Sync mobile field when a party with a phone is selected
              if (party.customerPhone != null && party.customerPhone!.isNotEmpty) {
                _mobileController.text = party.customerPhone!.replaceAll('+91', '').trim();
              }
              final notifier = ref.read(reviewProvider.notifier);
              notifier.updateDateRecord(header.copyWith(
                customerName: party.customerName,
                mobileNumber: party.customerPhone,
              ));
            },
          ),
          const SizedBox(height: 12),
          _buildMobileNumberField(header),
        ],
      ),
    );
  }

  void _saveMobileNumberFromController() {
    final val = _mobileController.text.trim();
    final liveState = ref.read(reviewProvider);
    final group = liveState.groups.firstWhere(
      (g) => g.receiptNumber == widget.group.receiptNumber,
      orElse: () => widget.group,
    );
    final header = group.header;
    if (header == null) return;
    // Save to provider (which calls the backend PUT /review/dates/update)
    final notifier = ref.read(reviewProvider.notifier);
    final newExtra = Map<String, dynamic>.from(header.extraFields)
      ..['mobile_number'] = val;
    notifier.updateDateRecord(header.copyWith(
      mobileNumber: val,
      extraFields: newExtra,
    ));
  }

  Widget _buildMobileNumberField(ReviewRecord header) {
    final phoneVal = _mobileController.text;
    final isValid = phoneVal.length == 10;
    final isEmpty = phoneVal.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.smartphone, size: 14, color: context.primaryColor),
            const SizedBox(width: 6),
            Text(
              'MOBILE NUMBER',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: context.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // +91 prefix chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color: context.primaryColor.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                border: Border(
                  top: BorderSide(color: context.primaryColor.withValues(alpha: 0.3)),
                  left: BorderSide(color: context.primaryColor.withValues(alpha: 0.3)),
                  bottom: BorderSide(color: context.primaryColor.withValues(alpha: 0.3)),
                ),
              ),
              child: Text(
                '+91',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: context.primaryColor,
                ),
              ),
            ),
            // Number input
            Expanded(
              child: TextField(
                controller: _mobileController,
                focusNode: _mobileFocusNode,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 1.2),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  hintText: '98765 43210',
                  hintStyle: TextStyle(
                    color: context.textSecondaryColor.withValues(alpha: 0.4),
                    fontWeight: FontWeight.normal,
                    letterSpacing: 0,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    borderSide: BorderSide(
                      color: context.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    borderSide: BorderSide(color: context.primaryColor, width: 2),
                  ),
                  fillColor: context.primaryColor.withValues(alpha: 0.03),
                  filled: true,
                  suffixIcon: isEmpty
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            isValid ? LucideIcons.checkCircle2 : LucideIcons.alertCircle,
                            size: 18,
                            color: isValid ? context.successColor : context.warningColor,
                          ),
                        ),
                ),
                onChanged: (_) => setState(() {}), // Refresh validation icon
                onSubmitted: (_) => _saveMobileNumberFromController(),
                onTapOutside: (_) {
                  _mobileFocusNode.unfocus();
                },
                textInputAction: TextInputAction.done,
              ),
            ),
          ],
        ),
        if (!isEmpty && !isValid)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              'Enter 10-digit mobile number',
              style: TextStyle(fontSize: 11, color: context.warningColor),
            ),
          ),
      ],
    );
  }

  Widget _buildHeaderField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: TextStyle(fontSize: 12, color: context.textSecondaryColor))),
          Expanded(flex: 3, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildLineItemCard(ReviewRecord item, bool isAutomobile) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      color: item.hasError ? context.errorColor.withValues(alpha: 0.05) : context.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: item.hasError ? context.errorColor.withValues(alpha: 0.3) : context.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: Description (left) + Amount (right) ──────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: DebouncedReviewField(
                    initialValue: item.description,
                    decoration: InputDecoration(
                      hintText: 'Item description',
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: context.textSecondaryColor.withValues(alpha: 0.5)),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: null,
                    onSaved: (val) {
                      ref.read(reviewProvider.notifier).updateAmountRecord(item.copyWith(description: val));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Amount — right-aligned, primary color, editable
                SizedBox(
                  width: 80,
                  child: DebouncedReviewField(
                    initialValue: _formatInput(item.amount),
                    textAlign: TextAlign.right,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: context.primaryColor.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: context.primaryColor, width: 2),
                      ),
                      fillColor: context.primaryColor.withValues(alpha: 0.05),
                      filled: true,
                      hintText: '0',
                      prefixText: '₹',
                      prefixStyle: TextStyle(fontWeight: FontWeight.w700, color: context.primaryColor, fontSize: 13),
                    ),
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: context.primaryColor),
                    onSaved: (val) {
                      final amt = double.tryParse(val) ?? 0.0;
                      ref.read(reviewProvider.notifier).updateAmountRecord(item.copyWith(amount: amt));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // ── Row 2: QTY chip + RATE chip + (Part/Labor toggle if automobile) ──
            Row(
              children: [
                // QTY — always visible
                Container(
                  padding: const EdgeInsets.only(left: 6, top: 2, bottom: 2, right: 4),
                  decoration: BoxDecoration(
                    color: context.backgroundColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: context.borderColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Q:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: context.textSecondaryColor)),
                      const SizedBox(width: 2),
                      SizedBox(
                        width: 38,
                        child: DebouncedReviewField(
                          initialValue: _formatInput(item.quantity),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            hintText: '1',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          onSaved: (val) {
                            final qty = double.tryParse(val);
                            double amt = item.amount;
                            if (qty != null && item.rate != null && item.rate! > 0) {
                              amt = qty * item.rate!;
                            }
                            ref.read(reviewProvider.notifier).updateAmountRecord(item.copyWith(quantity: qty, amount: amt));
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // RATE
                Container(
                  padding: const EdgeInsets.only(left: 6, top: 2, bottom: 2, right: 4),
                  decoration: BoxDecoration(
                    color: context.backgroundColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: context.borderColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('₹:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: context.textSecondaryColor)),
                      const SizedBox(width: 2),
                      SizedBox(
                        width: 62,
                        child: DebouncedReviewField(
                          initialValue: _formatInput(item.rate),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            hintText: '-',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          onSaved: (val) {
                            final rate = double.tryParse(val);
                            double amt = item.amount;
                            if (rate != null && item.quantity != null && item.quantity! > 0) {
                              amt = item.quantity! * rate;
                            }
                            ref.read(reviewProvider.notifier).updateAmountRecord(item.copyWith(rate: rate, amount: amt));
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Error badge
                if (item.hasError) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.warning_amber_rounded, size: 14, color: context.errorColor),
                ],
                const Spacer(),
                // Part/Labor toggle — only for automobile, moved to same row
                if (isAutomobile) ...[
                  _PartLaborToggle(
                    isPart: true,
                    selected: item.type?.toUpperCase().contains('PART') ?? false,
                    onTap: () => ref.read(reviewProvider.notifier).updateAmountRecord(item.copyWith(type: 'PART')),
                  ),
                  const SizedBox(width: 6),
                  _PartLaborToggle(
                    isPart: false,
                    selected: (item.type?.toUpperCase().contains('LABOR') ?? false) ||
                        (item.type?.toUpperCase().contains('LABOUR') ?? false) ||
                        (item.type?.toUpperCase().contains('SERVICE') ?? false),
                    onTap: () => ref.read(reviewProvider.notifier).updateAmountRecord(item.copyWith(type: 'LABOR')),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
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
  void didUpdateWidget(DebouncedReviewField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue && widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
      _lastSavedValue = widget.initialValue;
    }
  }

  @override
  void dispose() {
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
      scrollPadding: const EdgeInsets.only(bottom: 220),
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

class _PartLaborToggle extends StatelessWidget {
  final bool isPart;
  final bool selected;
  final VoidCallback onTap;

  const _PartLaborToggle({
    required this.isPart,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = isPart ? '⚙ Part' : '🔧 Labor';
    final selectedColor = isPart ? const Color(0xFF3B82F6) : const Color(0xFF6B7280);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? selectedColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? selectedColor : context.borderColor, width: 1),
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

// ─────────────────────────────────────────────────────────────────────────────
// END
// ─────────────────────────────────────────────────────────────────────────────
