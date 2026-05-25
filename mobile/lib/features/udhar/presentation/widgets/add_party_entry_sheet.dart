import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_provider.dart';
import 'package:mobile/features/inventory/presentation/providers/vendor_ledger_provider.dart';
import 'package:mobile/features/udhar/presentation/providers/item_catalogue_provider.dart';
import 'package:mobile/features/udhar/presentation/pages/item_catalogue_page.dart';
import 'package:mobile/features/settings/presentation/providers/shop_provider.dart';
import 'package:mobile/features/udhar/domain/models/udhar_models.dart';
import 'package:mobile/features/inventory/domain/models/vendor_ledger_models.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/theme/context_extension.dart';
import 'package:mobile/core/utils/whatsapp_utils.dart';
import 'package:mobile/core/utils/contact_utils.dart';
import 'package:mobile/shared/widgets/app_toast.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AddPartyEntrySheet extends ConsumerStatefulWidget {
  const AddPartyEntrySheet({super.key});

  @override
  ConsumerState<AddPartyEntrySheet> createState() => _AddPartyEntrySheetState();
}

class _ManualItem {
  String name;
  double quantity;
  double rate;
  String unit;

  _ManualItem({
    required this.name,
    this.quantity = 1.0,
    this.rate = 0.0,
    this.unit = 'NOS',
  });

  Map<String, dynamic> toJson() => {
        'item_name': name,
        'quantity': quantity,
        'rate': rate,
        'amount': quantity * rate,
      };
}

class _AddPartyEntrySheetState extends ConsumerState<AddPartyEntrySheet>
    with SingleTickerProviderStateMixin {
  final _partySearchController = TextEditingController();
  final _flatAmountController = TextEditingController();
  final _notesController = TextEditingController();
  final _mobileController = TextEditingController();
  final _paidAmountController = TextEditingController();
  final FocusNode _partySearchFocusNode = FocusNode();
  final FocusNode _mobileFocusNode = FocusNode();

  String _partyType = 'customer'; // 'customer' or 'vendor'
  String _entryType = 'gave'; // 'got' or 'gave' — defaults to 'gave' (sale mode)
  String _paymentMode = 'Credit'; // 'Credit', 'Cash', 'UPI' — only used when entry_type=='gave'
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  // Selected party details
  CustomerLedger? _selectedCustomer;
  VendorLedger? _selectedVendor;
  bool _showSuggestions = false;

  // Line items list
  final List<_ManualItem> _items = [];

  // Animated total tracking
  late final AnimationController _totalBumpController;
  late final Animation<double> _totalBumpAnimation;

  @override
  void initState() {
    super.initState();
    _totalBumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _totalBumpAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(
        parent: _totalBumpController,
        curve: Curves.easeOut,
      ),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _totalBumpController.reverse();
        }
      });

    _partySearchController.addListener(() {
      if (_partySearchController.text.trim().isNotEmpty &&
          _partySearchFocusNode.hasFocus) {
        setState(() {
          _showSuggestions = true;
        });
      } else {
        setState(() {
          _showSuggestions = false;
        });
      }
    });

    _partySearchFocusNode.addListener(() {
      if (!_partySearchFocusNode.hasFocus) {
        // Delay hiding suggestions so that a tap on a suggestion item
        // is registered BEFORE the list disappears (focus fires before onTap).
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() {
              _showSuggestions = false;
            });
          }
        });
      } else {
        setState(() {
          _showSuggestions =
              _partySearchController.text.trim().isNotEmpty;
        });
      }
    });
  }

  @override
  void dispose() {
    _totalBumpController.dispose();
    _partySearchController.dispose();
    _flatAmountController.dispose();
    _notesController.dispose();
    _partySearchFocusNode.dispose();
    _mobileController.dispose();
    _paidAmountController.dispose();
    _mobileFocusNode.dispose();
    super.dispose();
  }

  void _bumpTotal() {
    if (!_totalBumpController.isAnimating) {
      _totalBumpController.forward(from: 0);
    }
  }

  double get _computedTotal {
    if (_items.isEmpty) return 0.0;
    return _items.fold(0.0, (sum, item) => sum + (item.quantity * item.rate));
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _addCatalogueItem(CatalogueItem item) {
    setState(() {
      final existingIndex = _items.indexWhere((it) => it.name == item.itemName);
      if (existingIndex >= 0) {
        _items[existingIndex].quantity += 1.0;
      } else {
        _items.add(_ManualItem(
          name: item.itemName,
          rate: item.lastPrice,
          unit: item.unit,
          quantity: 1.0,
        ));
      }
    });
    HapticFeedback.lightImpact();
    _bumpTotal();
  }

  /// Merges items returned from the catalogue cart picker into the line items.
  /// If the same item already exists, its quantity is incremented.
  void _mergeCatalogueCart(List<CatalogueCartItem> cartItems) {
    setState(() {
      for (final ci in cartItems) {
        final existingIndex =
            _items.indexWhere((it) => it.name == ci.name);
        if (existingIndex >= 0) {
          _items[existingIndex].quantity += ci.qty.toDouble();
        } else {
          _items.add(_ManualItem(
            name: ci.name,
            rate: ci.rate,
            unit: ci.unit,
            quantity: ci.qty.toDouble(),
          ));
        }
      }
    });
    HapticFeedback.mediumImpact();
    _bumpTotal();
    AppToast.showSuccess(
      context,
      '${cartItems.length} item${cartItems.length == 1 ? '' : 's'} added ✅',
    );
  }

  Future<void> _submit({bool shareOnWhatsApp = false}) async {
    final partyName = _partySearchController.text.trim();
    if (partyName.isEmpty) {
      AppToast.showError(context, 'Please enter or select a party');
      return;
    }

    final mobile = _mobileController.text.trim();
    if (_partyType == 'customer' && mobile.isNotEmpty && mobile.length != 10) {
      AppToast.showError(context, 'Please enter a valid 10-digit mobile number');
      return;
    }

    final double finalAmount = _items.isEmpty
        ? (double.tryParse(_flatAmountController.text.trim()) ?? 0.0)
        : _computedTotal;

    if (finalAmount <= 0) {
      AppToast.showError(context, 'Amount must be greater than zero');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final payload = {
        'party_type': _partyType,
        'party_name': partyName,
        // Also send party_id if a known party was selected — backend uses ID
        // for direct lookup, avoiding any name-mismatch bugs.
        if (_partyType == 'customer' && _selectedCustomer != null)
          'party_id': _selectedCustomer!.id,
        if (_partyType == 'vendor' && _selectedVendor != null)
          'party_id': _selectedVendor!.id,
        if (_partyType == 'customer' && _mobileController.text.trim().isNotEmpty)
          'mobile_number': _mobileController.text.trim(),
        'amount': finalAmount,
        'entry_type': _entryType,
        'payment_mode': _entryType == 'got' ? 'Cash' : _paymentMode,
        if (_paymentMode == 'Credit' && _entryType == 'gave') ...{
          'received_amount': double.tryParse(_paidAmountController.text.trim()) ?? 0.0,
        },
        'date': _selectedDate.toUtc().toIsoformat(),
        'notes': _notesController.text.trim(),
        'items': _items.map((it) => it.toJson()).toList(),
      };

      final response = await ApiClient().dio.post(
            '/api/udhar/manual-entry',
            data: payload,
          );

      if (response.data['status'] == 'success') {
        // Extract receipt number assigned by backend
        final String? receiptNum = response.data['receipt_number']?.toString();

        // Trigger data refresh in background
        unawaited(ref.read(dashboardTotalsProvider.notifier).refresh());
        ref.read(itemCatalogueProvider.notifier).fetchCatalogue();
        if (_partyType == 'customer') {
          ref.read(udharProvider.notifier).fetchLedgers();
        } else {
          ref.read(vendorLedgerProvider.notifier).fetchLedgers();
        }

        // Extract the ledger id returned by the backend so we can navigate
        // straight into the party's Transaction History.
        final int? ledgerId = response.data['ledger_id'] is int
            ? response.data['ledger_id'] as int
            : int.tryParse(response.data['ledger_id']?.toString() ?? '');

        if (mounted) {
          if (shareOnWhatsApp && _partyType == 'customer') {
            final shopProfile = ref.read(shopProvider);
            final message = WhatsAppUtils.buildManualBillMessage(
              customerName: partyName,
              shopName: shopProfile.name.isNotEmpty ? shopProfile.name : 'Our Store',
              items: _items
                  .map((it) => {
                        'name': it.name,
                        'quantity': it.quantity,
                        'rate': it.rate,
                        'unit': it.unit,
                        'amount': it.quantity * it.rate
                      })
                  .toList(),
              total: finalAmount,
              paymentMode: _entryType == 'got' ? 'Cash' : _paymentMode,
            );

            // Resolve phone: prefer what's typed in the field, then fall
            // back to the customer's stored number.  shareReceipt() will
            // show a single prompt if still empty — no double-dialog.
            String phone = _mobileController.text.trim();
            if (phone.isEmpty) {
              phone = _selectedCustomer?.customerPhone ?? '';
            }
            if (phone.isNotEmpty && !phone.startsWith('+91') && phone.length == 10) {
              phone = '+91$phone';
            }

            if (!mounted) return;
            // Close manual entry sheet
            Navigator.of(context).pop(true);
            // Show WhatsApp share sheet (handles missing phone with one prompt)
            await WhatsAppUtils.shareReceipt(
              context,
              phone: phone,
              message: message,
            );
            // After WhatsApp sheet, open party detail if we have an id
            if (mounted && ledgerId != null && _partyType == 'customer') {
              _navigateToPartyDetail(ledgerId, partyName);
            }
          } else {
            Navigator.of(context).pop(true);
            final successMsg = receiptNum != null
                ? 'Entry saved! Bill #$receiptNum 🎉'
                : 'Entry added successfully! 🎉';
            AppToast.showSuccess(context, successMsg);
            // Immediately open the party's transaction history
            if (mounted && ledgerId != null && _partyType == 'customer') {
              _navigateToPartyDetail(ledgerId, partyName);
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to save transaction: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Pushes the Party Detail page for [ledgerId] after a successful save.
  /// Uses a stub CustomerLedger — the detail page fetches fresh data on init.
  void _navigateToPartyDetail(int ledgerId, String partyName) {
    if (!mounted) return;
    // Try to find the real ledger from provider state (may already be updated)
    final ledgers = ref.read(udharProvider).ledgers;
    final match = ledgers.where((l) => l.id == ledgerId).toList();
    final ledger = match.isNotEmpty
        ? match.first
        : CustomerLedger(
            id: ledgerId,
            customerName: partyName,
            balanceDue: 0.0,
          );
    context.push('/party/$ledgerId', extra: ledger);
  }

  /// Builds the mobile number input row (without the label — label is
  /// rendered inline with the date chip above it).
  Widget _buildMobileNumberFieldNoLabel(BuildContext context) {
    final phoneVal = _mobileController.text;
    final isValid = phoneVal.length == 10;
    final isEmpty = phoneVal.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // +91 prefix chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color: context.primaryColor.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
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
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    borderSide: BorderSide(
                      color: context.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
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
                onChanged: (_) => setState(() {}),
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

  @override
  Widget build(BuildContext context) {
    final bool isGot = _entryType == 'got';
    final Color activeColor = isGot ? context.successColor : context.primaryColor;

    final customerState = ref.watch(udharProvider);
    final vendorState = ref.watch(vendorLedgerProvider);
    final catalogueState = ref.watch(itemCatalogueProvider);

    final double finalAmount = _items.isEmpty
        ? (double.tryParse(_flatAmountController.text.trim()) ?? 0.0)
        : _computedTotal;

    // Silence unused warning
    final _ = _selectedVendor?.vendorName;

    // Filtered suggestions
    final query = _partySearchController.text.trim().toLowerCase();
    List<dynamic> partySuggestions = [];
    if (_partyType == 'customer') {
      partySuggestions = customerState.ledgers
          .where((l) => l.customerName.toLowerCase().contains(query))
          .toList();
    } else {
      partySuggestions = vendorState.ledgers
          .where((l) => l.vendorName.toLowerCase().contains(query))
          .toList();
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: context.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle & Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Record Manual Entry',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      IconButton(
                        icon: Icon(LucideIcons.x, color: context.textColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 20,
                right: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Party Type Toggle
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderColor, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _partyType = 'customer';
                                _selectedCustomer = null;
                                _selectedVendor = null;
                                _partySearchController.clear();
                                _mobileController.clear();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _partyType == 'customer'
                                    ? context.primaryColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    LucideIcons.user,
                                    size: 16,
                                    color: _partyType == 'customer'
                                        ? Colors.white
                                        : context.textSecondaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Customer',
                                    style: TextStyle(
                                      color: _partyType == 'customer'
                                          ? Colors.white
                                          : context.textColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _partyType = 'vendor';
                                _selectedCustomer = null;
                                _selectedVendor = null;
                                _partySearchController.clear();
                                _mobileController.clear();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _partyType == 'vendor'
                                    ? context.primaryColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    LucideIcons.truck,
                                    size: 16,
                                    color: _partyType == 'vendor'
                                        ? Colors.white
                                        : context.textSecondaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Supplier',
                                    style: TextStyle(
                                      color: _partyType == 'vendor'
                                          ? Colors.white
                                          : context.textColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Party Search & Dropdown Stack
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _partySearchController,
                        focusNode: _partySearchFocusNode,
                        style: TextStyle(
                          color: context.textColor,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          labelText: _partyType == 'customer'
                              ? 'Search Customer'
                              : 'Search Supplier',
                          hintText: 'Enter name or select...',
                          prefixIcon: const Icon(LucideIcons.search, size: 20),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: context.borderColor),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: context.primaryColor),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          suffixIcon: _partySearchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(LucideIcons.x, size: 16),
                                  onPressed: () {
                                    setState(() {
                                      _partySearchController.clear();
                                      _selectedCustomer = null;
                                      _selectedVendor = null;
                                      _mobileController.clear();
                                    });
                                  },
                                )
                              : null,
                        ),
                      ),

                      // Suggestions overlay panel
                      if (_showSuggestions && partySuggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            color: context.surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: context.borderColor,
                              width: 0.5,
                            ),
                            boxShadow: context.premiumShadow,
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: partySuggestions.length,
                            itemBuilder: (ctx, idx) {
                              final p = partySuggestions[idx];
                              final String name = _partyType == 'customer'
                                  ? (p as CustomerLedger).customerName
                                  : (p as VendorLedger).vendorName;
                              final double balance = p.balanceDue;

                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: context.primaryColor
                                      .withValues(alpha: 0.1),
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '',
                                    style: TextStyle(
                                      color: context.primaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: TextStyle(
                                    color: context.textColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Balance: ₹${balance.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: context.textSecondaryColor,
                                    fontSize: 12,
                                  ),
                                ),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  // Cancel the delayed hide so no double-setState
                                  setState(() {
                                    _partySearchController.text = name;
                                    if (_partyType == 'customer') {
                                      _selectedCustomer = p as CustomerLedger;
                                      final phone = _selectedCustomer?.customerPhone ?? '';
                                      _mobileController.text =
                                          phone.replaceAll('+91', '').trim();
                                    } else {
                                      _selectedVendor = p as VendorLedger;
                                    }
                                    _showSuggestions = false;
                                  });
                                  _partySearchFocusNode.unfocus();
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                  if (_partyType == 'customer') ...[
                    const SizedBox(height: 20),
                    // Mobile Number + Date chip in one row label
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Mobile number label on left
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
                        const Spacer(),
                        // Date pill on right — tappable
                        GestureDetector(
                          onTap: _selectDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: context.primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: context.primaryColor.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.calendar,
                                  size: 12,
                                  color: context.primaryColor,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _formatDate(_selectedDate),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: context.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildMobileNumberFieldNoLabel(context),
                  ] else ...[ 
                    // Vendor: show date pill standalone (no mobile field)
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: context.primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: context.primaryColor.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.calendar,
                                size: 12,
                                color: context.primaryColor,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _formatDate(_selectedDate),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: context.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Item catalogue chips (Customer only)
                  if (_partyType == 'customer') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '📦 Quick Items',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: context.textColor,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final result = await context
                                .push<List<CatalogueCartItem>>(
                              '/item-catalogue?mode=select',
                            );
                            if (result != null && result.isNotEmpty) {
                              _mergeCatalogueCart(result);
                            }
                          },
                          icon: const Icon(LucideIcons.tag, size: 14),
                          label: const Text('My Items'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (catalogueState.isLoading && catalogueState.items.isEmpty)
                      SizedBox(
                        height: 40,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.primaryColor,
                            ),
                          ),
                        ),
                      )
                    else if (catalogueState.items.isEmpty)
                      GestureDetector(
                        onTap: () => context.push('/item-catalogue'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: context.primaryColor.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: context.primaryColor.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: context.primaryColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  LucideIcons.packageOpen,
                                  size: 16,
                                  color: context.primaryColor,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'No items yet — add your products!',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: context.textColor,
                                      ),
                                    ),
                                    Text(
                                      'Tap to set up your price catalogue',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: context.textSecondaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                LucideIcons.chevronRight,
                                size: 16,
                                color: context.primaryColor,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 40,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: catalogueState.items.length > 10
                              ? 10
                              : catalogueState.items.length,
                          itemBuilder: (ctx, idx) {
                            final item = catalogueState.items[idx];
                            // Show a star if this item's price was manually set
                            // (useCount is low relative to other items or was directly added)
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ActionChip(
                                avatar: Icon(
                                  LucideIcons.plus,
                                  size: 12,
                                  color: context.primaryColor,
                                ),
                                label: Text(
                                  '${item.itemName}  ₹${item.lastPrice.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.textColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: context.surfaceColor,
                                side: BorderSide(
                                  color: context.primaryColor.withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 0,
                                ),
                                onPressed: () => _addCatalogueItem(item),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],

                  // Items List Header & Flat Amount input
                  if (_items.isEmpty) ...[
                    // Show a simple amount field if no line items are added yet
                    TextFormField(
                      controller: _flatAmountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Transaction Amount (₹)',
                        hintText: '0.00',
                        prefixIcon:
                            const Icon(LucideIcons.indianRupee, size: 20),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: context.borderColor),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: context.primaryColor),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _items.add(_ManualItem(name: ''));
                          });
                        },
                        icon: const Icon(LucideIcons.plusCircle, size: 16),
                        label: const Text('Add Line Items'),
                      ),
                    ),
                  ] else ...[
                    // Table header
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          const Expanded(
                            flex: 3,
                            child: Text(
                              'Item Name',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Expanded(
                            flex: 2,
                            child: Text(
                              'Qty',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Expanded(
                            flex: 2,
                            child: Text(
                              'Rate',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Subtotal column header
                          SizedBox(
                            width: 68,
                            child: Text(
                              'Amount',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                    // Line Items builder
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      itemBuilder: (ctx, idx) {
                        final item = _items[idx];
                        final rowSubtotal = item.quantity * item.rate;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Name field
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      initialValue: item.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Item...',
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 12,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: context.borderColor,
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: context.primaryColor,
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      onChanged: (val) => item.name = val,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Qty stepper
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: context.borderColor,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              HapticFeedback.lightImpact();
                                              setState(() {
                                                if (item.quantity > 1.0) {
                                                  item.quantity -= 1.0;
                                                } else {
                                                  _items.removeAt(idx);
                                                }
                                              });
                                              _bumpTotal();
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(8.0),
                                              child: const Icon(
                                                LucideIcons.minus,
                                                size: 14,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            item.quantity % 1 == 0
                                                ? item.quantity.toInt().toString()
                                                : item.quantity.toString(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              HapticFeedback.lightImpact();
                                              setState(() {
                                                item.quantity += 1.0;
                                              });
                                              _bumpTotal();
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(8.0),
                                              child: const Icon(
                                                LucideIcons.plus,
                                                size: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Rate input
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: item.rate > 0
                                          ? item.rate.toStringAsFixed(0)
                                          : '',
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                      decoration: InputDecoration(
                                        prefixText: '₹',
                                        hintText: '0',
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 12,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: context.borderColor,
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: context.primaryColor,
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          item.rate = double.tryParse(val) ?? 0.0;
                                        });
                                        _bumpTotal();
                                      },
                                    ),
                                  ),
                                  // Row subtotal chip
                                  SizedBox(
                                    width: 68,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 200),
                                      transitionBuilder: (child, animation) =>
                                          FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(0, -0.3),
                                            end: Offset.zero,
                                          ).animate(animation),
                                          child: child,
                                        ),
                                      ),
                                      child: Text(
                                        key: ValueKey('sub_${idx}_${rowSubtotal.toInt()}'),
                                        rowSubtotal > 0
                                            ? '₹${rowSubtotal.toStringAsFixed(0)}'
                                            : '—',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: rowSubtotal > 0
                                              ? context.primaryColor
                                              : context.textSecondaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Remove button
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _items.removeAt(idx);
                                      });
                                      _bumpTotal();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Icon(
                                        LucideIcons.xCircle,
                                        color: context.errorColor.withValues(
                                          alpha: 0.7,
                                        ),
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _items.add(_ManualItem(name: ''));
                            });
                          },
                          icon: const Icon(LucideIcons.plusCircle, size: 14),
                          label: const Text('Add Custom Item'),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _items.clear();
                            });
                            _bumpTotal();
                          },
                          child: Text(
                            'Clear Items',
                            style: TextStyle(color: context.errorColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),

                  // ── Transaction Mode Selector ──────────────────────────────
                  // For customers: SegmentedButton matching the review page pattern.
                  // Row 1 — sale types (Credit | Cash | UPI)
                  // Row 2 — Payment Received (full width)
                  if (_partyType == 'customer') ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'TRANSACTION TYPE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: context.textSecondaryColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    // Row 1: sale-type segments
                    Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'Credit', label: Text('Credit')),
                              ButtonSegment(value: 'Cash', label: Text('Cash')),
                              ButtonSegment(value: 'UPI', label: Text('UPI')),
                            ],
                            selected: _entryType == 'gave'
                                ? {_paymentMode}
                                : {'__none__'},
                            emptySelectionAllowed: true,
                            onSelectionChanged: (newSelection) {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _entryType = 'gave';
                                _paymentMode = newSelection.first;
                              });
                            },
                            style: ButtonStyle(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Row 2: Payment Received — full width
                    Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'got',
                                label: Text('Payment Received'),
                                icon: Icon(LucideIcons.arrowDownLeft, size: 14),
                              ),
                            ],
                            selected: _entryType == 'got' ? {'got'} : {},
                            emptySelectionAllowed: true,
                            onSelectionChanged: (newSelection) {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _entryType = newSelection.isEmpty ? 'gave' : 'got';
                                if (_entryType == 'got') _paymentMode = 'Cash';
                              });
                            },
                            style: ButtonStyle(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                                (states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return context.successColor.withValues(alpha: 0.12);
                                  }
                                  return null;
                                },
                              ),
                              foregroundColor: WidgetStateProperty.resolveWith<Color?>(
                                (states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return context.successColor;
                                  }
                                  return null;
                                },
                              ),
                              side: WidgetStateProperty.resolveWith<BorderSide?>(
                                (states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return BorderSide(color: context.successColor);
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ── Amount Paid (Credit only) ── mirrors review page ──────
                    if (_entryType == 'gave' && _paymentMode == 'Credit') ...[
                      Builder(builder: (context) {
                        final total = _items.isEmpty
                            ? (double.tryParse(_flatAmountController.text.trim()) ?? 0.0)
                            : _computedTotal;
                        final paid = double.tryParse(_paidAmountController.text.trim()) ?? 0.0;
                        final balance = (total - paid).clamp(0.0, double.infinity);
                        return Row(
                          children: [
                            // Total display
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total Bill',
                                      style: TextStyle(fontSize: 11, color: context.textSecondaryColor)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹${total.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                            // Amount paid input
                            SizedBox(
                              width: 110,
                              child: TextField(
                                controller: _paidAmountController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'Paid Now',
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
                                Text('Balance Due',
                                    style: TextStyle(fontSize: 11, color: context.textSecondaryColor)),
                                const SizedBox(height: 2),
                                Text(
                                  '₹${balance.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: balance > 0 ? context.errorColor : context.successColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 16),
                    ],
                  ] else ...[
                    // For vendors: keep simple YOU GOT / YOU GAVE
                    Row(
                      children: [
                        Expanded(
                          child: _EntryTypeButton(
                            label: 'YOU GOT',
                            isSelected: _entryType == 'got',
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _entryType = 'got');
                            },
                            activeColor: context.successColor,
                            icon: LucideIcons.arrowDownLeft,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _EntryTypeButton(
                            label: 'YOU GAVE',
                            isSelected: _entryType == 'gave',
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _entryType = 'gave');
                            },
                            activeColor: context.errorColor,
                            icon: LucideIcons.arrowUpRight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Notes (Optional)
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notes (Optional)',
                      hintText: 'Add bill details, context, etc.',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── STICKY BOTTOM PANEL ──────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: context.backgroundColor,
              border: Border(
                top: BorderSide(
                  color: context.borderColor.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Total row with animated amount
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Item count badge
                        if (_items.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: activeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_items.length} item${_items.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: activeColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Spacer(),
                        // Label
                        Text(
                          'TOTAL',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: context.textSecondaryColor,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Animated amount
                        ScaleTransition(
                          scale: _totalBumpAnimation,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (child, anim) =>
                                SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.5),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: anim,
                                curve: Curves.easeOut,
                              )),
                              child: FadeTransition(
                                opacity: anim,
                                child: child,
                              ),
                            ),
                            child: Text(
                              '₹${finalAmount.toStringAsFixed(0)}',
                              key: ValueKey(finalAmount.toInt()),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: activeColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Action buttons
                    Row(
                      children: [
                        // Save Only
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : () => _submit(),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: activeColor, width: 2),
                              foregroundColor: activeColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: activeColor,
                                    ),
                                  )
                                : const Text(
                                    'SAVE',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Save + Send on WhatsApp
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(
                                colors: [
                                  activeColor,
                                  activeColor.withValues(alpha: 0.82),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: activeColor.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () => _submit(shareOnWhatsApp: true),
                              icon: const Icon(LucideIcons.send, size: 16),
                              label: Text(
                                _partyType == 'customer'
                                    ? 'SAVE + WHATSAPP'
                                    : 'SAVE',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final comparison = DateTime(date.year, date.month, date.day);

    if (comparison == today) {
      return 'Today, ${date.day} ${_monthName(date.month)}';
    } else if (comparison == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${date.day} ${_monthName(date.month)}';
    } else {
      return '${date.day} ${_monthName(date.month)}, ${date.year}';
    }
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }
}

extension _DateTimeIso on DateTime {
  String toIsoformat() {
    return toIso8601String();
  }
}



class _EntryTypeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;
  final IconData icon;

  const _EntryTypeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.activeColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.08)
              : context.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeColor
                : context.borderColor.withValues(alpha: 0.5),
            width: isSelected ? 2.5 : 1.5,
          ),
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    activeColor.withValues(alpha: 0.12),
                    activeColor.withValues(alpha: 0.02),
                  ],
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.1)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? activeColor : context.textSecondaryColor,
                size: 20,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : context.textSecondaryColor,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
