import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile/shared/widgets/robust_receipt_image.dart';
import 'package:mobile/core/theme/app_theme.dart';
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
import 'package:mobile/core/utils/contact_utils.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_provider.dart';




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
  late final TextEditingController _paidAmountController;

  String _paymentMode = 'Credit';
  double _receivedAmount = 0.0; // Still kept for internal logic
  double? _manualTotalAmount;
  bool _isTotalManuallyEdited = false;

  /// Live local amount overrides keyed by rowId — updated on every keystroke
  /// so the grand total reflects the user's edits without waiting for a server save.
  final Map<String, double> _localAmountOverrides = {};

  /// True when the user tried to save without a customer name.
  /// Turns the customer banner field red until user fills it in.

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
    _paidAmountController = TextEditingController(text: '0');
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
    _mobileController.text = mobile.replaceAll(RegExp(r'\.0$'), '');
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
    _paidAmountController.dispose();
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

    // Load received amount
    final savedReceivedAmount = prefs.getDouble('received_amount_$receipt');
    final header = widget.group.header;
    double initialReceived = 0.0;

    if (savedReceivedAmount != null) {
      initialReceived = savedReceivedAmount;
    } else if (header?.balanceDue != null && header!.balanceDue! > 0) {
      final total = _activeTotalAmount(widget.group);
      initialReceived = (total - header.balanceDue!).clamp(0.0, total);
    } else if (header?.receivedAmount != null && header!.receivedAmount! > 0) {
      initialReceived = header.receivedAmount!;
    } else {
      initialReceived = 0.0;
    }

    if (mounted) {
      setState(() {
        _receivedAmount = initialReceived;
        _paidAmountController.text = initialReceived.toStringAsFixed(0);
        final total = _activeTotalAmount(widget.group);
        _paymentMode = (total - initialReceived).abs() < 0.01 ? 'Cash' : 'Credit';
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
    double amountFor(ReviewRecord i) => _localAmountOverrides[i.rowId] ?? i.amount;
    final typed = group.lineItems.where((i) {
      final type = i.type?.toUpperCase() ?? '';
      return type.isNotEmpty;
    }).toList();

    if (typed.isEmpty) {
      return group.lineItems.fold(0.0, (s, i) => s + amountFor(i));
    }

    return group.lineItems
        .where((i) {
          final type = i.type?.toUpperCase() ?? '';
          return type.contains('PART') || type.isEmpty;
        })
        .fold(0.0, (s, i) => s + amountFor(i));
  }

  double _laborSubtotal(InvoiceReviewGroup group) => group.lineItems
      .where((i) {
        final type = i.type?.toUpperCase() ?? '';
        return type.contains('LABOUR') || type.contains('LABOR') || type.contains('SERVICE');
      })
      .fold(0.0, (s, i) => s + (_localAmountOverrides[i.rowId] ?? i.amount));

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

  void _showEditTotalDialog(double currentCalculatedTotal) {
    final controller = TextEditingController(text: (_manualTotalAmount ?? currentCalculatedTotal).round().toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adjust Grand Total'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the correct total from the bill. We will adjust the extras to match.',
              style: TextStyle(fontSize: 12, color: context.textSecondaryColor),
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
                _manualTotalAmount = null;
                _isTotalManuallyEdited = false;
              });
              Navigator.pop(context);
            },
            child: const Text('Reset to Auto'),
          ),
          FilledButton(
            onPressed: () {
              final newTotal = double.tryParse(controller.text);
              if (newTotal != null) {
                final wasPaid = (currentCalculatedTotal - _receivedAmount).abs() < 0.01;
                setState(() {
                  _manualTotalAmount = newTotal;
                  _isTotalManuallyEdited = true;
                  if (wasPaid) {
                    _receivedAmount = newTotal;
                    _paidAmountController.text = newTotal.toStringAsFixed(0);
                  }
                });
                _saveTotalAmount(newTotal);
                if (wasPaid) _saveReceivedAmount(newTotal);
              }
              Navigator.pop(context);
            },
            child: const Text('Update Total'),
          ),
        ],
      ),
    );
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
      final receivedFromInput = double.tryParse(_paidAmountController.text) ?? _receivedAmount;
      final balanceDue = (grandTotal - receivedFromInput).clamp(0.0, double.infinity);
      final paymentMode = _paymentMode;
      
      var customerName = header.customerName?.trim() ?? '';
      if (customerName.isEmpty) {
        customerName = 'Counter';
      }

      var newRecord = header.copyWith(
          verificationStatus: 'Done',
          paymentMode: paymentMode,
          amount: grandTotal,
          receivedAmount: receivedFromInput,
          balanceDue: balanceDue,
          totalBillAmount: grandTotal,
          customerDetails: _paymentMode == 'Credit' ? _creditDetailsController.text : null,
          gstMode: _gstMode.name,
          customerName: customerName,
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
      final overrideAmount = _localAmountOverrides[item.rowId];
      final recordToSave = overrideAmount != null 
          ? item.copyWith(amount: overrideAmount, verificationStatus: 'Done')
          : item.copyWith(verificationStatus: 'Done');
      
      if (item.verificationStatus != 'Done' || overrideAmount != null) {
        recordsToUpdate.add(recordToSave);
      }
    }
    
    if (recordsToUpdate.isNotEmpty) {
      await notifier.updateAmountRecordsBulk(recordsToUpdate);
    }
  }

  void _markAllDone() async {
    final liveState = ref.read(reviewProvider);
    final liveGroup = liveState.groups.firstWhere(
      (g) => g.receiptNumber == widget.group.receiptNumber,
      orElse: () => widget.group,
    );
    // Only block for genuinely broken data — amount mismatches are NOT an error.
    if (liveGroup.hasError) {
      final List<String> errorMessages = [];
      if (liveGroup.header?.verificationStatus.toLowerCase() == 'duplicate receipt number') {
        errorMessages.add('\u2022 Duplicate receipt number detected');
      }
      if (liveGroup.header?.date.trim().isEmpty == true) {
        errorMessages.add('\u2022 Receipt date is missing');
      }
      if (errorMessages.isEmpty) errorMessages.add('\u2022 Some fields have errors');

      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(LucideIcons.alertTriangle, color: context.errorColor),
              const SizedBox(width: 8),
              const Text('Check Before Saving', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please fix the following before saving:'),
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
            ],
          ),
          actions: [
            TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: context.errorColor),
              onPressed: () => context.pop(true),
              child: const Text('Save Anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
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

      // ⚡ Optimistic ledger update — inject the new/updated party card into
      // local state RIGHT NOW so the home screen is already populated when
      // the user lands there, without waiting for the backend sync to finish.
      final liveState2 = ref.read(reviewProvider);
      final liveGroup2 = liveState2.groups.firstWhere(
        (g) => g.receiptNumber == widget.group.receiptNumber,
        orElse: () => widget.group,
      );
      final optimisticHeader = liveGroup2.header;
      if (optimisticHeader != null) {
        final grandTotal = _activeTotalAmount(liveGroup2);
        final receivedFromInput =
            double.tryParse(_paidAmountController.text) ?? _receivedAmount;
        final optimisticBalance =
            (grandTotal - receivedFromInput).clamp(0.0, double.infinity);
        final optimisticName =
            (optimisticHeader.customerName?.trim().isNotEmpty == true)
                ? optimisticHeader.customerName!.trim()
                : 'Counter';

        ref.read(udharProvider.notifier).addOrUpdateLedgerOptimistic(
          customerName: optimisticName,
          totalBilled: grandTotal,
          balanceDue: optimisticBalance,
          receiptNumber: liveGroup2.receiptNumber,
          mobileNumber: optimisticHeader.mobileNumber?.trim().isNotEmpty == true
              ? optimisticHeader.mobileNumber
              : _mobileController.text.trim().isNotEmpty
                  ? _mobileController.text.trim()
                  : null,
        );
      }

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

    // Individual item-edit errors are silently swallowed — optimistic updates
    // keep the UI consistent and errors will surface if the user retries sync.
    // We only surface errors from syncAndFinish, which are handled on the home screen.

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
    final paidAmount = double.tryParse(_paidAmountController.text) ?? 0.0;
    final balance = (total - paidAmount).clamp(0.0, double.infinity);
    final hasNext = widget.currentIndex != -1 && widget.currentIndex < _localAllGroups.length - 1;

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
                  onTap: () => _showEditTotalDialog(total),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Bill', style: TextStyle(fontSize: 11, color: context.textSecondaryColor)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text('₹${total.toStringAsFixed(0)}',
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
                      _receivedAmount = paid;
                      _paymentMode = (total - paid).abs() < 0.01 ? 'Cash' : 'Credit';
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
                        _paidAmountController.text = total.round().toString();
                        _receivedAmount = total;
                      } else {
                        _paidAmountController.text = '0';
                        _receivedAmount = 0;
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
                  child: FilledButton.icon(
                    onPressed: state.isSyncing ? null : _markAllDone,
                    style: FilledButton.styleFrom(
                      backgroundColor: context.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: state.isSyncing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(LucideIcons.checkCircle, size: 20),
                    label: Text(
                      state.isSyncing
                          ? 'Saving...'
                          : (hasNext ? 'Save & Next Bill' : 'Save & Finish'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
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
      whatsappCustomNote: shopProfile.whatsappCustomNote,
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
        color: context.primaryColor.withValues(alpha: 0.05),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.userPlus, size: 16, color: context.primaryColor),
              const SizedBox(width: 8),
              Text(
                'CUSTOMER DETAILS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: context.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CustomerAutocompleteField(
            initialValue: header.customerName ?? '',
            label: 'Search or enter customer name...',
            onSaved: (val) {
              final notifier = ref.read(reviewProvider.notifier);
              notifier.updateDateRecord(header.copyWith(customerName: val));
            },
            onCustomerSelected: (party) {
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
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(LucideIcons.contact, color: context.primaryColor),
                        onPressed: () async {
                          final phone = await ContactUtils.pickContactPhone();
                          if (phone != null && mounted) {
                            setState(() {
                              _mobileController.text = phone;
                            });
                            _saveMobileNumberFromController();
                          }
                        },
                      ),
                      if (!isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            isValid ? LucideIcons.checkCircle2 : LucideIcons.alertCircle,
                            size: 18,
                            color: isValid ? context.successColor : context.warningColor,
                          ),
                        ),
                    ],
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
    return _LineItemInlineEditor(
      key: ValueKey(item.rowId),
      item: item,
      isAutomobile: isAutomobile,
      onAmountChanged: (rowId, amount) {
        // Live update — just refresh local overrides so grand total recomputes
        setState(() {
          final oldTotal = _activeTotalAmount(widget.group);
          final wasPaid = (oldTotal - _receivedAmount).abs() < 0.01;
          
          _localAmountOverrides[rowId] = amount;
          _isTotalManuallyEdited = false;
          _manualTotalAmount = null;
          
          if (wasPaid) {
            final newTotal = _activeTotalAmount(widget.group);
            _receivedAmount = newTotal;
            _paidAmountController.text = newTotal.toStringAsFixed(0);
          }
        });
      },
      onSaved: (updatedItem) {
        // Persist to provider (optimistic update, server save in background)
        ref.read(reviewProvider.notifier).updateAmountRecord(updatedItem);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LineItemInlineEditor — handles live qty × rate → price with last-edit-wins
// ─────────────────────────────────────────────────────────────────────────────


class _LineItemInlineEditor extends StatefulWidget {
  final ReviewRecord item;
  final bool isAutomobile;
  /// Called on every keystroke with the new computed amount for live grand total.
  final void Function(String rowId, double amount) onAmountChanged;
  /// Called on focus-out to persist the updated record to the provider.
  final void Function(ReviewRecord updatedItem) onSaved;

  const _LineItemInlineEditor({
    super.key,
    required this.item,
    required this.isAutomobile,
    required this.onAmountChanged,
    required this.onSaved,
  });

  @override
  State<_LineItemInlineEditor> createState() => _LineItemInlineEditorState();
}

class _LineItemInlineEditorState extends State<_LineItemInlineEditor> {
  late final TextEditingController _descCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _rateCtrl;
  late final TextEditingController _priceCtrl;

  final _descFocus = FocusNode();
  final _qtyFocus = FocusNode();
  final _rateFocus = FocusNode();
  final _priceFocus = FocusNode();

  bool get _anyFocused =>
      _descFocus.hasFocus || _qtyFocus.hasFocus ||
      _rateFocus.hasFocus || _priceFocus.hasFocus;

  static String _fmt(double? v) {
    if (v == null) return '';
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _descCtrl = TextEditingController(text: item.description);
    _qtyCtrl = TextEditingController(text: _fmt(item.quantity));
    _rateCtrl = TextEditingController(text: _fmt(item.rate));
    _priceCtrl = TextEditingController(text: _fmt(item.amount));

    _descFocus.addListener(() { if (!_descFocus.hasFocus) _save(); });
    _qtyFocus.addListener(() { if (!_qtyFocus.hasFocus) _save(); });
    _rateFocus.addListener(() { if (!_rateFocus.hasFocus) _save(); });
    _priceFocus.addListener(() { if (!_priceFocus.hasFocus) _save(); });
  }

  @override
  void didUpdateWidget(_LineItemInlineEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only sync from external provider state when not actively typing
    if (_anyFocused) return;
    final item = widget.item;
    if (item.description != _descCtrl.text) _descCtrl.text = item.description;
    final newQty = _fmt(item.quantity);
    if (newQty != _qtyCtrl.text) _qtyCtrl.text = newQty;
    final newRate = _fmt(item.rate);
    if (newRate != _rateCtrl.text) _rateCtrl.text = newRate;
    final newPrice = _fmt(item.amount);
    if (newPrice != _priceCtrl.text) _priceCtrl.text = newPrice;
  }

  @override
  void dispose() {
    _save();
    _descCtrl.dispose(); _qtyCtrl.dispose();
    _rateCtrl.dispose(); _priceCtrl.dispose();
    _descFocus.dispose(); _qtyFocus.dispose();
    _rateFocus.dispose(); _priceFocus.dispose();
    super.dispose();
  }

  void _onQtyOrRateChanged() {
    final qty = double.tryParse(_qtyCtrl.text);
    final rate = double.tryParse(_rateCtrl.text);
    if (qty != null && rate != null) {
      final computed = qty * rate;
      // Update price field live
      final formatted = _fmt(computed);
      if (_priceCtrl.text != formatted) _priceCtrl.text = formatted;
      widget.onAmountChanged(widget.item.rowId, computed);
    }
  }

  void _save() {
    final qty = double.tryParse(_qtyCtrl.text);
    final rate = double.tryParse(_rateCtrl.text);
    double price = double.tryParse(_priceCtrl.text) ?? widget.item.amount;
    
    // Always use qty * rate if both exist
    if (qty != null && rate != null) {
      price = qty * rate;
    }
    
    final updated = widget.item.copyWith(
      description: _descCtrl.text.trim().isEmpty ? widget.item.description : _descCtrl.text,
      quantity: qty,
      rate: rate,
      amount: price,
    );
    widget.onSaved(updated);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    // Card border: use mismatch warning color (amber) only if triangle visible, otherwise normal
    final borderColor = context.borderColor;
    final cardColor = context.surfaceColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: Description (left) + Price (right with ▲ triangle) ─
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _descCtrl,
                    focusNode: _descFocus,
                    decoration: InputDecoration(
                      hintText: 'Item description',
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: context.textSecondaryColor.withValues(alpha: 0.5)),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: null,
                    textInputAction: TextInputAction.done,
                    onTapOutside: (_) => _descFocus.unfocus(),
                  ),
                ),
                const SizedBox(width: 6),
                // Price field (read-only)
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _priceCtrl,
                    focusNode: _priceFocus,
                    readOnly: true,
                    textAlign: TextAlign.right,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                      fillColor: context.surfaceColor,
                      filled: true,
                      hintText: '0',
                      prefixText: '₹',
                      prefixStyle: TextStyle(fontWeight: FontWeight.w700, color: context.textSecondaryColor, fontSize: 13),
                    ),
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: context.textSecondaryColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // ── Row 2: Q chip + Rate chip + Part/Labor toggle ─────────────
            Row(
              children: [
                // QTY chip
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
                        child: TextField(
                          controller: _qtyCtrl,
                          focusNode: _qtyFocus,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => _onQtyOrRateChanged(),
                          onTapOutside: (_) => _qtyFocus.unfocus(),
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            hintText: '1',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // RATE chip
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
                        child: TextField(
                          controller: _rateCtrl,
                          focusNode: _rateFocus,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => _onQtyOrRateChanged(),
                          onTapOutside: (_) => _rateFocus.unfocus(),
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            hintText: '-',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Part/Labor toggle — only for automobile
                if (widget.isAutomobile) ...[
                  _PartLaborToggle(
                    isPart: true,
                    selected: item.type?.toUpperCase().contains('PART') ?? false,
                    onTap: () => widget.onSaved(item.copyWith(type: 'PART')),
                  ),
                  const SizedBox(width: 6),
                  _PartLaborToggle(
                    isPart: false,
                    selected: (item.type?.toUpperCase().contains('LABOR') ?? false) ||
                        (item.type?.toUpperCase().contains('LABOUR') ?? false) ||
                        (item.type?.toUpperCase().contains('SERVICE') ?? false),
                    onTap: () => widget.onSaved(item.copyWith(type: 'LABOR')),
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
