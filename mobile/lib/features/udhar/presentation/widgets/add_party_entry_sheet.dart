import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_provider.dart';
import 'package:mobile/features/inventory/presentation/providers/vendor_ledger_provider.dart';
import 'package:mobile/features/udhar/presentation/providers/item_catalogue_provider.dart';
import 'package:mobile/features/settings/presentation/providers/shop_provider.dart';
import 'package:mobile/features/udhar/domain/models/udhar_models.dart';
import 'package:mobile/features/inventory/domain/models/vendor_ledger_models.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/theme/context_extension.dart';
import 'package:mobile/core/utils/whatsapp_utils.dart';
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

class _AddPartyEntrySheetState extends ConsumerState<AddPartyEntrySheet> {
  final _partySearchController = TextEditingController();
  final _flatAmountController = TextEditingController();
  final _notesController = TextEditingController();
  final FocusNode _partySearchFocusNode = FocusNode();

  String _partyType = 'customer'; // 'customer' or 'vendor'
  String _entryType = 'got'; // 'got' or 'gave'
  String _paymentMode = 'Credit'; // 'Credit', 'Cash', 'UPI'
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  // Selected party details
  CustomerLedger? _selectedCustomer;
  VendorLedger? _selectedVendor;
  bool _showSuggestions = false;

  // Line items list
  final List<_ManualItem> _items = [];

  @override
  void initState() {
    super.initState();
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
      setState(() {
        _showSuggestions = _partySearchFocusNode.hasFocus &&
            _partySearchController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _partySearchController.dispose();
    _flatAmountController.dispose();
    _notesController.dispose();
    _partySearchFocusNode.dispose();
    super.dispose();
  }

  /// Prompts the user to enter a WhatsApp number when none is stored.
  Future<String?> _promptPhoneNumber(BuildContext ctx) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: ctx.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: ctx.borderColor, width: 0.5),
        ),
        title: Row(
          children: [
            const Text('📱 ', style: TextStyle(fontSize: 22)),
            Text(
              'WhatsApp Number',
              style: TextStyle(
                color: ctx.textColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the customer\'s mobile number to send the bill on WhatsApp.',
              style: TextStyle(
                color: ctx.textSecondaryColor,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: ctx.textColor, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '9876543210',
                prefixText: '+91 ',
                prefixStyle: TextStyle(
                  color: ctx.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
                hintStyle: TextStyle(color: ctx.textSecondaryColor),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: ctx.borderColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: ctx.primaryColor, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, null),
            child: Text(
              'Skip',
              style: TextStyle(color: ctx.textSecondaryColor),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final number = controller.text.trim();
              Navigator.pop(dialogCtx, number.isEmpty ? null : number);
            },
            icon: const Icon(LucideIcons.send, size: 14),
            label: const Text('Send'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
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
  }

  Future<void> _submit({bool shareOnWhatsApp = false}) async {
    final partyName = _partySearchController.text.trim();
    if (partyName.isEmpty) {
      AppToast.showError(context, 'Please enter or select a party');
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
        'amount': finalAmount,
        'entry_type': _entryType,
        'payment_mode': _paymentMode,
        'date': _selectedDate.toUtc().toIsoformat(),
        'notes': _notesController.text.trim(),
        'items': _items.map((it) => it.toJson()).toList(),
      };

      final response = await ApiClient().dio.post(
            '/api/udhar/manual-entry',
            data: payload,
          );

      if (response.data['status'] == 'success') {
        // Trigger data refresh in background
        unawaited(ref.read(dashboardTotalsProvider.notifier).refresh());
        ref.read(itemCatalogueProvider.notifier).fetchCatalogue();
        if (_partyType == 'customer') {
          ref.read(udharProvider.notifier).fetchLedgers();
        } else {
          ref.read(vendorLedgerProvider.notifier).fetchLedgers();
        }

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
              paymentMode: _paymentMode,
            );

            String phone = _selectedCustomer?.customerPhone ?? '';

            // If no phone saved, prompt the user to enter one before sharing
            if (phone.isEmpty && mounted) {
              phone = await _promptPhoneNumber(context) ?? '';
            }

            if (!mounted) return;
            // Close manual entry sheet
            Navigator.of(context).pop(true);
            // Show WhatsApp share sheet
            await WhatsAppUtils.shareReceipt(
              context,
              phone: phone,
              message: message,
            );
          } else {
            Navigator.of(context).pop(true);
            AppToast.showSuccess(context, 'Entry added successfully! 🎉');
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

  @override
  Widget build(BuildContext context) {
    final bool isGot = _entryType == 'got';
    final Color activeColor = isGot ? context.successColor : context.errorColor;

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
                                  setState(() {
                                    _partySearchController.text = name;
                                    if (_partyType == 'customer') {
                                      _selectedCustomer = p as CustomerLedger;
                                    } else {
                                      _selectedVendor = p as VendorLedger;
                                    }
                                    _showSuggestions = false;
                                    _partySearchFocusNode.unfocus();
                                  });
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
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
                          onPressed: () {
                            context.push('/item-catalogue');
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
                              'Price',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 32),
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
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
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
                                          setState(() {
                                            if (item.quantity > 1.0) {
                                              item.quantity -= 1.0;
                                            } else {
                                              _items.removeAt(idx);
                                            }
                                          });
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Icon(
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
                                          setState(() {
                                            item.quantity += 1.0;
                                          });
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Icon(
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
                              // Price input
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
                                    item.rate = double.tryParse(val) ?? 0.0;
                                    setState(() {});
                                  },
                                ),
                              ),
                              // Remove button
                              IconButton(
                                icon: Icon(
                                  LucideIcons.xCircle,
                                  color: context.errorColor.withValues(
                                    alpha: 0.7,
                                  ),
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _items.removeAt(idx);
                                  });
                                },
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

                  // Date Picker & Payment Mode Selector Row
                  Row(
                    children: [
                      // Date Picker Button
                      Expanded(
                        child: GestureDetector(
                          onTap: _selectDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: context.surfaceColor,
                              border: Border.all(color: context.borderColor, width: 0.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.calendar,
                                  size: 16,
                                  color: context.primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _formatDate(_selectedDate),
                                    style: TextStyle(
                                      color: context.textColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Payment Mode Pills (Cash, UPI, Credit)
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: context.surfaceColor,
                            border: Border.all(color: context.borderColor, width: 0.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: ['Credit', 'Cash', 'UPI'].map((mode) {
                              final isSelected = _paymentMode == mode;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _paymentMode = mode;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? context.primaryColor
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        mode,
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : context.textSecondaryColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Entry Type (Got / Gave) Toggle
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

                  // Total Summary Bar (Green/Red based on entry type)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: activeColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: activeColor.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TOTAL AMOUNT:',
                          style: TextStyle(
                            color: activeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          '₹${finalAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: activeColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save and Save + WhatsApp Actions
                  Row(
                    children: [
                      // Save Only
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => _submit(),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: activeColor, width: 2),
                            foregroundColor: activeColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'SAVE',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Save + Send on WhatsApp
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [
                                activeColor,
                                activeColor.withValues(alpha: 0.8),
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
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
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
