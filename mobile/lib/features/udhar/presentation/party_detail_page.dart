import "package:mobile/core/theme/context_extension.dart";
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/shared/domain/models/invoice_group.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import '../../verified/presentation/providers/verified_provider.dart';
import '../domain/models/udhar_models.dart';
import 'providers/udhar_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile/core/utils/whatsapp_utils.dart';
import 'package:mobile/features/settings/presentation/providers/shop_provider.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mobile/core/utils/contact_utils.dart';
import 'package:shimmer/shimmer.dart';
import 'widgets/add_party_entry_sheet.dart';
import 'pages/item_catalogue_page.dart';
import 'package:mobile/core/utils/invoice_pdf_generator.dart';
import 'package:mobile/core/utils/file_download_helper.dart';
import 'package:share_plus/share_plus.dart';



class PartyDetailPage extends ConsumerStatefulWidget {
  final CustomerLedger ledger;

  const PartyDetailPage({super.key, required this.ledger});

  @override
  ConsumerState<PartyDetailPage> createState() => _PartyDetailPageState();
}

class _PartyDetailPageState extends ConsumerState<PartyDetailPage> {
  final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');

  List<LedgerTransaction>? _transactions;
  bool _isLoading = true;
  Map<String, double> _backendSummary = {
    'total_billed': 0,
    'total_paid': 0,
    'balance_due': 0,
  };
  // Tracks which manual-entry transactions have their items expanded.
  final Map<int, bool> _expandedItems = {};

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    // Pre-warm PDF fonts + logo as soon as the page opens so they're cached
    // by the time the user taps "Share as PDF". Uses a post-frame callback so
    // that the Riverpod ref (shopProvider) is readable.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final logoUrl = ref.read(shopProvider).logoUrl;
      InvoicePdfGenerator.preWarm(logoUrl.isNotEmpty ? logoUrl : null);
    });
  }

  Future<void> _loadTransactions() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final (transactions, summary) = await ref
        .read(udharProvider.notifier)
        .fetchLedgerWithTransactions(widget.ledger.id);
    if (!mounted) return;
    setState(() {
      _transactions = transactions;
      _backendSummary = summary;
      _isLoading = false;
    });
  }

  /// Returns the authoritative balance: prefers backend-computed value (which accounts
  /// for all transactions including linked initial payments) and only falls back to
  /// summing local transactions if the backend summary hasn't loaded yet.
  double get _computedBalance {
    // Primary: server-computed balance_due = final_billed - final_paid
    // This is authoritative because grand_total is now derived from item amounts, not stale DB fields.
    final backendVal = _backendSummary['balance_due'] ?? 0.0;
    if (!_isLoading && _transactions != null) return backendVal;
    // Fallback during initial load: iterate all transactions
    if (_transactions == null || _transactions!.isEmpty) {
      return widget.ledger.balanceDue;
    }
    double balance = 0;
    for (final tx in _transactions!) {
      if (tx.transactionType == 'INVOICE' ||
          tx.transactionType == 'MANUAL_CREDIT') {
        balance += tx.amount;
      } else if (tx.transactionType == 'PAYMENT') {
        balance -= tx.amount;
      }
    }
    return balance;
  }

  double get _totalInvoiced {
    // Use backend-computed value if available (avoids local recalculation drift)
    final backendVal = _backendSummary['total_billed'] ?? 0.0;
    if (backendVal > 0) return backendVal;
    if (_transactions == null) return 0;
    return _transactions!
        .where(
          (tx) =>
              tx.transactionType == 'INVOICE' ||
              tx.transactionType == 'MANUAL_CREDIT',
        )
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  double get _totalPaid {
    // Use backend-computed value — avoids double-counting where an invoice's
    // receivedAmount (from verified_invoices) would be counted again here.
    final backendVal = _backendSummary['total_paid'] ?? 0.0;
    if (backendVal > 0) return backendVal;
    if (_transactions == null) return 0;
    // Fallback: only count PAYMENT rows that are standalone (not linked to an invoice
    // whose receivedAmount is already shown in the invoice clarity row).
    return _transactions!
        .where((tx) => tx.transactionType == 'PAYMENT')
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  void _showBillingOptionsSheet(
    BuildContext context,
    CustomerLedger currentLedger,
  ) {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: context.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(LucideIcons.x, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: context.surfaceColor,
                      side: BorderSide(color: context.borderColor),
                    ),
                  ),
                  const Text(
                    'NEW BILL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 48), // Spacer to balance the X button
                ],
              ),
              const SizedBox(height: 20),

              // Title Section
              Text(
                'How would you like to bill?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: context.textColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondaryColor,
                    fontFamily: 'Outfit',
                  ),
                  children: [
                    const TextSpan(text: 'Choose a billing method for '),
                    TextSpan(
                      text: currentLedger.customerName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: context.textColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Option 1: Scan Bill (AI Camera)
              _buildBillingOptionCard(
                context: context,
                title: 'Scan Bill',
                icon: LucideIcons.scanLine,
                color: const Color(0xFF6366F1), // Indigo
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(
                    '/upload',
                    extra: {'customerName': currentLedger.customerName},
                  );
                },
                isDark: isDark,
              ),

              // Option 2: Quick Bill (Catalogue)
              _buildBillingOptionCard(
                context: context,
                title: 'Quick Bill',
                icon: LucideIcons.shoppingCart,
                color: const Color(0xFF10B981), // Emerald Green
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await Navigator.push<List<CatalogueCartItem>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const ItemCataloguePage(selectionMode: true),
                    ),
                  );
                  if (result != null && result.isNotEmpty && context.mounted) {
                    final completed = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => AddPartyEntrySheet(
                        initialItems: result,
                        initialCustomer: currentLedger,
                      ),
                    );
                    if (completed == true) {
                      _loadTransactions();
                    }
                  }
                },
                isDark: isDark,
              ),

              // Option 3: Manual Bill (Type Details)
              _buildBillingOptionCard(
                context: context,
                title: 'Manual Entry',
                icon: LucideIcons.edit3,
                color: const Color(0xFFF59E0B), // Amber
                onTap: () async {
                  Navigator.pop(ctx);
                  final completed = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) =>
                        AddPartyEntrySheet(initialCustomer: currentLedger),
                  );
                  if (completed == true) {
                    _loadTransactions();
                  }
                },
                isDark: isDark,
              ),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBillingOptionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: context.textColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                color: context.textSecondaryColor.withValues(alpha: 0.5),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddPaymentDialog(BuildContext context) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Record Payment',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: context.primaryColor.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Balance Due:',
                          style: TextStyle(
                            color: context.textSecondaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(_computedBalance),
                          style: TextStyle(
                            color: context.primaryColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Amount Received',
                      labelStyle: TextStyle(color: context.textSecondaryColor),
                      prefixIcon: Icon(
                        LucideIcons.indianRupee,
                        color: context.primaryColor,
                      ),
                      filled: true,
                      fillColor: context.textSecondaryColor.withValues(
                        alpha: 0.03,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: 'Notes (Optional)',
                      labelStyle: TextStyle(color: context.textSecondaryColor),
                      prefixIcon: Icon(
                        LucideIcons.edit3,
                        color: context.textSecondaryColor,
                      ),
                      filled: true,
                      fillColor: context.textSecondaryColor.withValues(
                        alpha: 0.03,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final amount =
                                  double.tryParse(amountController.text) ?? 0;
                              if (amount <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please enter a valid amount',
                                    ),
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isSubmitting = true);
                              final success = await ref
                                  .read(udharProvider.notifier)
                                  .recordPayment(
                                    widget.ledger.id,
                                    amount,
                                    notesController.text,
                                  );

                              if (success && context.mounted) {
                                ref.invalidate(verifiedProvider);
                                Navigator.pop(context);
                                _loadTransactions();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Payment recorded! 🎉'),
                                  ),
                                );
                              } else {
                                setModalState(() => isSubmitting = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Failed to save payment.'),
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save Payment',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditCustomerSheet(
    BuildContext context,
    CustomerLedger currentLedger,
  ) {
    final nameController = TextEditingController(
      text: currentLedger.customerName,
    );
    final phoneController = TextEditingController(
      text: currentLedger.customerPhone ?? '',
    );
    bool isSubmitting = false;
    String? nameError; // null = no error, 'duplicate' = name taken, 'error' = generic

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.borderColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: context.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            LucideIcons.userCog,
                            color: context.primaryColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit Customer',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'Update name & mobile number',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    // Name field
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                      onChanged: (_) {
                        if (nameError != null) {
                          setModalState(() => nameError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Customer Name',
                        hintText: 'e.g. Ramesh Sharma',
                        labelStyle: TextStyle(
                          color: nameError != null
                              ? Colors.red.shade600
                              : context.textSecondaryColor,
                        ),
                        prefixIcon: Icon(
                          LucideIcons.user,
                          color: nameError != null
                              ? Colors.red.shade600
                              : context.primaryColor,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: nameError != null
                            ? Colors.red.withValues(alpha: 0.05)
                            : context.textSecondaryColor.withValues(alpha: 0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: nameError != null
                                ? Colors.red.shade400
                                : context.borderColor,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: nameError != null
                                ? Colors.red.shade400
                                : context.borderColor,
                            width: nameError != null ? 1.5 : 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: nameError != null
                                ? Colors.red.shade600
                                : context.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                      autofocus: true,
                    ),
                    // Duplicate name error banner
                    if (nameError == 'duplicate') ...[  
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFFB74D),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('⚠️', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'यह नाम पहले से मौजूद है!',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: Color(0xFFE65100),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'कोई और नाम डालें — जैसे "${nameController.text.trim()} 2" या "${nameController.text.trim()} (नया)"',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF6D4C41),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (nameError == 'error') ...[  
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.shade300,
                            width: 1.2,
                          ),
                        ),
                        child: const Row(
                          children: [
                            Text('❌', style: TextStyle(fontSize: 16)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Save नहीं हो सका। Internet check करें और दोबारा try करें।',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFC62828),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Mobile number field
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        hintText: 'e.g. 9876543210',
                        labelStyle: TextStyle(color: context.textSecondaryColor),
                        prefixIcon: Icon(
                          LucideIcons.smartphone,
                          color: context.primaryColor,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: context.textSecondaryColor.withValues(
                          alpha: 0.04,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: context.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: context.borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: context.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final name = nameController.text.trim();
                                if (name.isEmpty) {
                                  setModalState(() => nameError = 'error');
                                  return;
                                }

                                setModalState(() {
                                  isSubmitting = true;
                                  nameError = null;
                                });

                                final phone = phoneController.text.trim();
                                final nameChanged =
                                    name != currentLedger.customerName;
                                final phoneChanged =
                                    phone !=
                                    (currentLedger.customerPhone ?? '');

                                String? nameUpdateError;
                                if (nameChanged) {
                                  nameUpdateError = await ref
                                      .read(udharProvider.notifier)
                                      .updateCustomerName(
                                        currentLedger.id,
                                        name,
                                      );
                                }

                                // If name update failed, show targeted feedback in-sheet
                                if (nameUpdateError != null) {
                                  if (!mounted) return;
                                  setModalState(() {
                                    isSubmitting = false;
                                    nameError = nameUpdateError;
                                  });
                                  return;
                                }

                                bool phoneSuccess = true;
                                if (phoneChanged) {
                                  phoneSuccess = await ref
                                      .read(udharProvider.notifier)
                                      .updateCustomerPhone(
                                        currentLedger.id,
                                        phone,
                                      );
                                }

                                if (!mounted) return;
                                if (phoneSuccess && context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Row(
                                        children: [
                                          Text('✅ ', style: TextStyle(fontSize: 16)),
                                          Text(
                                            'Customer details saved!',
                                            style: TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: const Color(0xFF2E7D32),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                } else {
                                  setModalState(() {
                                    isSubmitting = false;
                                    nameError = 'error';
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _navigateToOrderDetails(LedgerTransaction tx) async {
    if (tx.receiptNumber == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final repo = ref.read(verifiedRepositoryProvider);
      final records = await repo.getVerifiedInvoices(
        receiptNumber: tx.receiptNumber,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (records.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find order details.')),
        );
        return;
      }

      final first = records.first;

      // ─── Fix #1: Derive authoritative payment amounts from ledger_transactions ───
      // verified_invoices.received_amount is NEVER updated when a payment is recorded
      // via the Khata page — payments only live in ledger_transactions.
      // So we compute the true paid/due amounts from the already-loaded _transactions.
      //
      //   1. tx is the INVOICE ledger transaction → tx.amount = bill total per ledger.
      //   2. Find all PAYMENT txs for the same receipt number in _transactions.
      //   3. Sum them → authoritative totalPaid.
      //   4. invoiceAmount − totalPaid → authoritative balanceDue.
      final double ledgerInvoiceAmount = tx.amount;
      final double ledgerTotalPaid = (_transactions ?? [])
          .where(
            (t) =>
                t.transactionType == 'PAYMENT' &&
                t.receiptNumber == tx.receiptNumber,
          )
          .fold(0.0, (sum, t) => sum + t.amount);
      final double ledgerBalanceDue = (ledgerInvoiceAmount - ledgerTotalPaid)
          .clamp(0.0, double.infinity);
      final String ledgerPaymentMode = ledgerBalanceDue <= 0
          ? 'Cash'
          : (tx.paymentMode ?? 'Credit');
      // ─────────────────────────────────────────────────────────────────────────

      final group = InvoiceGroup(
        receiptNumber: first.receiptNumber,
        date: first.date.isNotEmpty ? first.date : first.uploadDate,
        receiptLink: first.receiptLink,
        customerName: first.customerName,
        mobileNumber: first.mobileNumber.replaceAll(RegExp(r'\.0$'), ''),
        extraFields: first.extraFields,
        uploadDate: first.uploadDate,
        paymentMode: ledgerPaymentMode,
        receivedAmount: ledgerTotalPaid,
        balanceDue: ledgerBalanceDue,
        customerDetails: first.customerDetails,
      );
      group.items = records;
      group.totalAmount = ledgerInvoiceAmount;

      if (mounted) {
        // Use await to refresh data when returning from details
        await context.pushNamed(
          'order-detail',
          extra: group,
          queryParameters: {'receiptNumber': group.receiptNumber},
        );
        if (mounted) {
          _loadTransactions();
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  void _showReceiptPhotoDialog(LedgerTransaction tx) async {
    if (tx.receiptNumber == null && tx.receiptLink == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.receipt,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Invoice #${tx.receiptNumber ?? "N/A"}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12),
              Expanded(
                child:
                    tx.receiptLink != null &&
                        tx.receiptLink!.isNotEmpty &&
                        tx.receiptLink != 'null'
                    ? _buildImageWidget(tx.receiptLink!, scrollController)
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.imageOff,
                              color: Colors.white.withValues(alpha: 0.2),
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No receipt photo available',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageWidget(String url, ScrollController scrollController) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: InteractiveViewer(
        maxScale: 5.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            width: double.infinity,
            placeholder: (context, url) => Container(
              height: 400,
              color: Colors.white.withValues(alpha: 0.05),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: 200,
              color: Colors.white.withValues(alpha: 0.05),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.alertTriangle,
                    color: Colors.orange,
                    size: 48,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Could not load image',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(udharProvider);
    final currentLedger = state.ledgers.firstWhere(
      (l) => l.id == widget.ledger.id,
      orElse: () => widget.ledger,
    );

    final initials = currentLedger.customerName.isNotEmpty
        ? currentLedger.customerName
              .trim()
              .split(' ')
              .take(2)
              .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
              .join()
        : 'C';

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () =>
                        _showEditCustomerSheet(context, currentLedger),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            currentLedger.customerName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          LucideIcons.pencil,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () =>
                        _showEditCustomerSheet(context, currentLedger),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (currentLedger.customerPhone != null &&
                            currentLedger.customerPhone!.isNotEmpty)
                          Text(
                            currentLedger.customerPhone!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        else
                          Text(
                            'Add Mobile Number',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.italic,
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
        actions: [
          IconButton(
            onPressed: () {
              context.push(
                '/upload',
                extra: {'customerName': currentLedger.customerName},
              );
            },
            icon: const Icon(LucideIcons.scanLine, color: Colors.white),
            tooltip: 'Scan New Bill',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildHeaderCard(currentLedger),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: context.primaryColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'TRANSACTION HISTORY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: context.textSecondaryColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                if (_transactions != null && _transactions!.isNotEmpty)
                  Text(
                    '${_transactions!.length} Entries',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondaryColor.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? _buildTransactionSkeleton()
                : _transactions == null || _transactions!.isEmpty
                ? _buildEmptyState()
                : Builder(
                    builder: (context) {
                      // Sort newest-first so the most recent activity is always visible
                      // without scrolling — matches Khatabook / Vyapar UX convention.
                      //
                      // Advance PAYMENT rows (is_advance_linked=true) are excluded from
                      // the visible list because they are already shown inline on the bill
                      // card's "Bill Amount / Paid / Balance" clarity row. Showing them as
                      // a separate "Payment Received" card would be redundant.
                      // They are still present in _transactions for summary calculations.
                      final visibleTxs =
                          _transactions!
                              .where((tx) => !tx.isAdvanceLinked)
                              .toList()
                            ..sort(
                              (a, b) => b.createdAt.compareTo(a.createdAt),
                            );
                      if (visibleTxs.isEmpty) return _buildEmptyState();
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                        itemCount: visibleTxs.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final tx = visibleTxs[index];
                          return _buildTransactionCard(tx);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          border: Border(
            top: BorderSide(
              color: context.borderColor.withValues(alpha: 0.5),
              width: 0.5,
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
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  side: const BorderSide(color: Color(0xFF25D366), width: 1.5),
                  foregroundColor: const Color(0xFF25D366),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: EdgeInsets.zero,
                ),
                onPressed: _isLoading
                    ? null
                    : () => _showWhatsAppReminderSheet(
                        context,
                        ref,
                        currentLedger,
                      ),
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF25D366),
                        ),
                      )
                    : const FaIcon(FontAwesomeIcons.whatsapp, size: 20),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                icon: const Icon(
                  LucideIcons.receipt,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text(
                  'NEW BILL',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1), // Indigo color
                  minimumSize: const Size(0, 52),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () =>
                    _showBillingOptionsSheet(context, currentLedger),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                icon: const Icon(
                  LucideIcons.indianRupee,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text(
                  'PAYMENT',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primaryColor,
                  minimumSize: const Size(0, 52),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _showAddPaymentDialog(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(CustomerLedger currentLedger) {
    final balance = _isLoading ? currentLedger.balanceDue : _computedBalance;
    final isPositive = balance > 0.01;
    final isNegative = balance < -0.01;

    String headerLabel = 'TOTAL BALANCE DUE';
    if (isNegative) headerLabel = 'ADVANCE';
    if (!isPositive && !isNegative) headerLabel = 'SETTLED';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        boxShadow: [
          BoxShadow(
            color: context.primaryColor.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    headerLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '₹',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: isPositive
                                ? Colors.white
                                : Colors.greenAccent.shade200,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        CurrencyFormatter.formatPlain(balance.abs()),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: isPositive
                              ? Colors.white
                              : Colors.greenAccent.shade200,
                          letterSpacing: -2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: _buildHeaderStat(
                          label: 'TOTAL BILLED',
                          value: CurrencyFormatter.format(_totalInvoiced),
                          icon: LucideIcons.fileText,
                        ),
                      ),
                      Container(
                        width: 1.5,
                        height: 36,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      Expanded(
                        child: _buildHeaderStat(
                          label: 'TOTAL PAID',
                          value: CurrencyFormatter.format(_totalPaid),
                          icon: LucideIcons.checkCircle2,
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

  Widget _buildHeaderStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 14),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Future<void> _showWhatsAppReminderSheet(
    BuildContext context,
    WidgetRef ref,
    CustomerLedger ledger,
  ) async {
    HapticFeedback.lightImpact();

    // Ensure shop name is loaded before composing the message.
    await ref.read(shopProvider.notifier).ensureValidShopName();
    final shopProfile = ref.read(shopProvider);
    final authState = ref.read(authProvider);
    final shopName = shopProfile.name.isNotEmpty
        ? shopProfile.name
        : 'Our Shop';
    final upiId = shopProfile.upiId.isNotEmpty ? shopProfile.upiId : null;
    final usernameParam = authState.user?.username != null
        ? '&u=${Uri.encodeComponent(authState.user!.username)}'
        : '';

    // Collect ALL credit transactions (invoices + manual entries) for the picker.
    // Manual entries without a receipt image or number are now included so they
    // can be sent as a formatted itemized bill message.
    final invoicesForReminder = (_transactions ?? [])
        .where(
          (tx) =>
              tx.transactionType == 'INVOICE' ||
              tx.transactionType == 'MANUAL_CREDIT',
        )
        .toList();

    final phoneController = TextEditingController(
      text: ledger.customerPhone ?? '',
    );

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        // ── Determine initial selected transaction ─────────────────────────────
        LedgerTransaction? selectedTx = invoicesForReminder.isNotEmpty
            ? invoicesForReminder.first
            : null;

        // shareMode: 'receiptPhoto' | 'manualBill' | 'accountStatement'
        // Default intelligently: manual entries → 'manualBill',
        //                        image receipts  → 'receiptPhoto',
        //                        no transactions → 'accountStatement'
        String defaultMode(LedgerTransaction? tx) {
          if (tx == null) return 'accountStatement';
          if (tx.isManualEntry) return 'manualBill';
          final hasImage =
              tx.receiptLink != null &&
              tx.receiptLink!.isNotEmpty &&
              tx.receiptLink != 'null';
          return hasImage ? 'receiptPhoto' : 'accountStatement';
        }

        String shareMode = defaultMode(selectedTx);

        // ── Background pre-fetch ──────────────────────────────────────────────
        // Start downloading the receipt image immediately when the sheet opens.
        String? prefetchedUrl = (shareMode == 'receiptPhoto')
            ? selectedTx?.receiptLink
            : null;
        Future<Uint8List?> prefetchFuture =
            (prefetchedUrl != null &&
                prefetchedUrl.isNotEmpty &&
                prefetchedUrl != 'null')
            ? WhatsAppUtils.prefetchImageBytes(prefetchedUrl)
            : Future<Uint8List?>.value(null);

        // Restart the prefetch whenever the user switches receipt or mode.
        void restartPrefetch(LedgerTransaction? tx, String mode) {
          final url = (mode == 'receiptPhoto') ? (tx?.receiptLink) : null;
          if (url == prefetchedUrl) return;
          prefetchedUrl = url;
          prefetchFuture = (url != null && url.isNotEmpty && url != 'null')
              ? WhatsAppUtils.prefetchImageBytes(url)
              : Future<Uint8List?>.value(null);
        }
        // ────────────────────────────────────────────────────────────

        // Mutable delivery date that the user can edit in the share sheet
        // without affecting the stored transaction. Initialized from the tx
        // when the sheet opens and re-initialized when selectedTx changes.
        DateTime? editableDeliveryDate = selectedTx?.deliveryDate;

        return StatefulBuilder(
          builder: (ctx, setSheet) {
            // Dynamically generate receipt link for chosen bill, falling back to party statement in receipt.html
            final String activeShareLink;
            final selectedReceiptNumber = selectedTx?.receiptNumber;
            if (selectedReceiptNumber != null && selectedReceiptNumber.isNotEmpty) {
              activeShareLink = 'https://snapkhata.com/receipt.html?i=$selectedReceiptNumber$usernameParam';
            } else {
              activeShareLink = 'https://snapkhata.com/receipt.html?party=${ledger.id}$usernameParam';
            }

            // Build the correct preview message depending on shareMode
            final String message;
            if (shareMode == 'manualBill' && selectedTx != null) {
              message = WhatsAppUtils.buildManualBillMessage(
                customerName: ledger.customerName.isNotEmpty
                    ? ledger.customerName
                    : 'Customer',
                shopName: shopName,
                items: selectedTx!.items,
                total: selectedTx!.amount,
                paymentMode: selectedTx!.paymentMode ?? 'Credit',
                receivedAmount: selectedTx!.receivedAmount,
                balanceDue: _computedBalance,
                whatsappCustomNote: shopProfile.whatsappCustomNote,
                orderDate: selectedTx!.orderDate,
                deliveryDate: editableDeliveryDate ?? selectedTx!.deliveryDate,
              );
            } else {
              message = WhatsAppUtils.buildPartyReminderMessage(
                customerName: ledger.customerName.isNotEmpty
                    ? ledger.customerName
                    : 'Customer',
                shopName: shopName,
                totalBilled: _totalInvoiced,
                totalPaid: _totalPaid,
                balanceDue: _computedBalance,
                statementLink: activeShareLink,
                upiId: upiId,
                useReceiptPhoto: shareMode == 'receiptPhoto',
                receiptPhotoUrl: selectedTx?.receiptLink,
                receiptNumber: selectedTx?.receiptNumber?.toString(),
                whatsappCustomNote: shopProfile.whatsappCustomNote,
              );
            }

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.85,
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Scrollable body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF25D366,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const FaIcon(
                                  FontAwesomeIcons.whatsapp,
                                  color: Color(0xFF25D366),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Send Payment Reminder',
                                      style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    Text(
                                      ledger.customerName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: context.textSecondaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  LucideIcons.x,
                                  color: context.textSecondaryColor,
                                ),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Summary strip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: context.backgroundColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _summaryChip(
                                  context,
                                  'Billed',
                                  CurrencyFormatter.format(_totalInvoiced),
                                  context.textColor,
                                ),
                                Container(
                                  width: 1,
                                  height: 32,
                                  color: context.borderColor,
                                ),
                                _summaryChip(
                                  context,
                                  'Paid',
                                  CurrencyFormatter.format(_totalPaid),
                                  context.successColor,
                                ),
                                Container(
                                  width: 1,
                                  height: 32,
                                  color: context.borderColor,
                                ),
                                _summaryChip(
                                  context,
                                  'Due',
                                  CurrencyFormatter.format(_computedBalance),
                                  context.errorColor,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── SEND AS section ─────────────────────────────────
                          // Show picker only if there are any credit transactions.
                          if (invoicesForReminder.isNotEmpty) ...[
                            Text(
                              'SEND AS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: context.textSecondaryColor,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Build mode segments contextually:
                            // • Manual entry with no image → only 'Manual Bill'
                            // • Image receipt              → 'Receipt Photo' + 'Account Statement'
                            // • Image receipt (manual)     → all three
                            Builder(
                              builder: (ctx) {
                                final bool txIsManual =
                                    selectedTx?.isManualEntry ?? false;
                                final bool txHasImage =
                                    selectedTx?.receiptLink != null &&
                                    selectedTx!.receiptLink!.isNotEmpty &&
                                    selectedTx!.receiptLink != 'null';

                                // Segments available for this transaction
                                final segments = <ButtonSegment<String>>[
                                  if (txHasImage)
                                    const ButtonSegment<String>(
                                      value: 'receiptPhoto',
                                      label: Text(
                                        'Receipt Photo',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      icon: Icon(LucideIcons.image, size: 15),
                                    ),
                                  if (txIsManual)
                                    const ButtonSegment<String>(
                                      value: 'manualBill',
                                      label: Text(
                                        'Manual Bill',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      icon: Icon(
                                        LucideIcons.clipboardList,
                                        size: 15,
                                      ),
                                    ),
                                  const ButtonSegment<String>(
                                    value: 'accountStatement',
                                    label: Text(
                                      'Account Statement',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    icon: Icon(
                                      LucideIcons.link,
                                      size: 15,
                                    ),
                                  ),
                                ];

                                // Ensure current shareMode is valid for this tx
                                final validMode =
                                    segments.any((s) => s.value == shareMode)
                                    ? shareMode
                                    : segments.first.value;

                                return SegmentedButton<String>(
                                  segments: segments,
                                  selected: {validMode},
                                  onSelectionChanged: (s) {
                                    final newMode = s.first;
                                    restartPrefetch(selectedTx, newMode);
                                    setSheet(() => shareMode = newMode);
                                  },
                                  showSelectedIcon: false,
                                  style: SegmentedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 10,
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Receipt picker when multiple transactions exist
                            if (invoicesForReminder.length > 1) ...[
                              const SizedBox(height: 14),
                              Text(
                                'CHOOSE BILL',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: context.textSecondaryColor,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ...invoicesForReminder.map(
                                (tx) => InkWell(
                                  onTap: () {
                                    final newMode = defaultMode(tx);
                                    restartPrefetch(tx, newMode);
                                    setSheet(() {
                                      selectedTx = tx;
                                      shareMode = newMode;
                                      editableDeliveryDate = tx.deliveryDate;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selectedTx == tx
                                          ? context.primaryColor.withValues(
                                              alpha: 0.08,
                                            )
                                          : context.backgroundColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selectedTx == tx
                                            ? context.primaryColor
                                            : context.borderColor,
                                        width: selectedTx == tx ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          tx.isManualEntry
                                              ? LucideIcons.clipboardList
                                              : LucideIcons.receipt,
                                          size: 16,
                                          color: selectedTx == tx
                                              ? context.primaryColor
                                              : context.textSecondaryColor,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            tx.isManualEntry
                                                ? 'Manual · ${DateFormat("dd MMM yyyy").format(tx.createdAt.toLocal())}'
                                                : 'Bill #${tx.receiptNumber ?? "N/A"} · ${DateFormat("dd MMM yyyy").format(tx.createdAt.toLocal())}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: selectedTx == tx
                                                  ? context.primaryColor
                                                  : context.textColor,
                                            ),
                                          ),
                                        ),
                                        if (tx.isManualEntry)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFFF59E0B,
                                              ).withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: const Color(
                                                  0xFFF59E0B,
                                                ).withValues(alpha: 0.35),
                                              ),
                                            ),
                                            child: const Text(
                                              'MANUAL',
                                              style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFFD97706),
                                              ),
                                            ),
                                          ),
                                        if (selectedTx == tx)
                                          Icon(
                                            LucideIcons.checkCircle2,
                                            size: 16,
                                            color: context.primaryColor,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                          ],

                          // Message preview (WhatsApp bubble style)
                          Text(
                            'PREVIEW',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: context.textSecondaryColor,
                              letterSpacing: 1.2,
                            ),
                          ),
                          // ── Editable Delivery Date (laundry manual bills) ───
                          if (shareMode == 'manualBill' &&
                              (editableDeliveryDate != null ||
                                  (selectedTx?.deliveryDate != null))) ...[
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: editableDeliveryDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                  helpText: 'Change Delivery Date',
                                );
                                if (picked != null) {
                                  setSheet(() => editableDeliveryDate = picked);
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.truck,
                                      size: 16,
                                      color: Color(0xFF7C3AED),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'DELIVERY DATE',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF7C3AED),
                                              letterSpacing: 1,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            editableDeliveryDate != null
                                                ? DateFormat('dd MMM yyyy').format(editableDeliveryDate!)
                                                : 'Tap to set',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF7C3AED),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      LucideIcons.pencil,
                                      size: 14,
                                      color: Color(0xFF7C3AED),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCF8C6),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(18),
                                bottomLeft: Radius.circular(18),
                                bottomRight: Radius.circular(18),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              message,
                              style: const TextStyle(
                                color: Color(0xFF0D0D0D),
                                fontSize: 13,
                                height: 1.65,
                              ),
                            ),
                          ),

                          // Phone field if missing
                          if (ledger.customerPhone == null ||
                              ledger.customerPhone!.trim().isEmpty) ...[
                            const SizedBox(height: 20),
                            TextField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'Customer Mobile Number',
                                prefixText: '+91 ',
                                hintText: '9876543210',
                                prefixIcon: Icon(
                                  LucideIcons.phone,
                                  color: context.primaryColor,
                                ),
                                filled: true,
                                fillColor: context.textSecondaryColor
                                    .withValues(alpha: 0.03),
                                suffixIcon: ContactUtils.isSupported
                                    ? IconButton(
                                        icon: Icon(
                                          LucideIcons.contact,
                                          color: context.primaryColor,
                                        ),

                                        onPressed: () async {
                                          final phone =
                                              await ContactUtils.pickContactPhone();

                                          if (phone != null) {
                                            phoneController.text = phone;
                                          }
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: context.borderColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // Action buttons
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      12,
                      24,
                      24 + MediaQuery.of(ctx).padding.bottom,
                    ),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      border: Border(
                        top: BorderSide(
                          color: context.borderColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (shareMode == 'accountStatement' && selectedTx != null)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            icon: const Icon(
                              LucideIcons.fileDown,
                              size: 18,
                              color: Color(0xFF6366F1),
                            ),
                            label: const Text(
                              'Share as PDF',
                              style: TextStyle(
                                color: Color(0xFF6366F1),
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFF6366F1),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              backgroundColor: const Color(0xFF6366F1)
                                  .withValues(alpha: 0.06),
                            ),
                            onPressed: () async {
                              // Capture before pop
                              final capturedTx = selectedTx;
                              final capturedShopProfile = shopProfile;
                              Navigator.pop(ctx);
                              if (!context.mounted) return;
                              await _sharePdfForTransaction(
                                tx: capturedTx!,
                                ledger: ledger,
                                shopName: shopName,
                                shopAddress: capturedShopProfile.address
                                    .isNotEmpty
                                    ? capturedShopProfile.address
                                    : null,
                                shopPhone: capturedShopProfile.phone
                                    .isNotEmpty
                                    ? capturedShopProfile.phone
                                    : null,
                                shopGst: capturedShopProfile.gst
                                    .isNotEmpty
                                    ? capturedShopProfile.gst
                                    : null,
                                shopType: capturedShopProfile.shopType,
                                shopLogoUrl: capturedShopProfile.logoUrl.isNotEmpty
                                    ? capturedShopProfile.logoUrl
                                    : null,
                                customTerms: capturedShopProfile.customTerms
                                    .isNotEmpty
                                    ? capturedShopProfile.customTerms
                                    : null,
                              );
                            },
                          ),
                        ),
                        if (shareMode == 'accountStatement' && selectedTx != null)
                          const SizedBox(height: 10),
                        // ── Cancel + WhatsApp row ───────────────────────────
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  side: BorderSide(color: context.borderColor),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                icon: const FaIcon(
                                  FontAwesomeIcons.whatsapp,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'SEND ON WHATSAPP',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  minimumSize: const Size(0, 52),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () async {
                                  final phone =
                                      phoneController.text.trim().isNotEmpty
                                      ? phoneController.text.trim()
                                      : (ledger.customerPhone ?? '');

                                  // Capture all values before popping
                                  String capturedMessage = message;
                                  final capturedReceiptLink =
                                      selectedTx?.receiptLink;
                                  final capturedReceiptNumber =
                                      selectedTx?.receiptNumber;
                                  final capturedShareMode = shareMode;

                                  Navigator.pop(ctx);

                                  // For Account Statement mode, always send the
                                  // party-level statement.html link (full ledger).
                                  // The receipt picker only controls which PDF is
                                  // generated — the WhatsApp link must always point
                                  // to the account statement, NOT receipt.html.
                                  if (capturedShareMode == 'accountStatement') {
                                    capturedMessage =
                                        WhatsAppUtils.buildPartyReminderMessage(
                                          customerName:
                                              ledger.customerName.isNotEmpty
                                              ? ledger.customerName
                                              : 'Customer',
                                          shopName: shopName,
                                          totalBilled: _totalInvoiced,
                                          totalPaid: _totalPaid,
                                          balanceDue: _computedBalance,
                                          statementLink: activeShareLink,
                                          upiId: upiId,
                                          useReceiptPhoto: false,
                                          receiptPhotoUrl: null,
                                          receiptNumber: null,
                                          whatsappCustomNote:
                                              shopProfile.whatsappCustomNote,
                                        );
                                  }

                                  // Receipt Photo mode
                                  if (capturedShareMode == 'receiptPhoto' &&
                                      capturedReceiptLink != null &&
                                      capturedReceiptLink.isNotEmpty &&
                                      capturedReceiptLink != 'null') {
                                    final prefetchedBytes = await prefetchFuture;
                                    if (!context.mounted) return;
                                    await WhatsAppUtils.shareActualImageOnWhatsApp(
                                      context: context,
                                      imageUrl: capturedReceiptLink,
                                      caption: capturedMessage,
                                      phone: phone,
                                      prefetchedBytes: prefetchedBytes,
                                      receiptNumber: capturedReceiptNumber,
                                      username: authState.user?.username,
                                    );
                                  } else {
                                    if (phone.isNotEmpty) {
                                      await WhatsAppUtils.openWhatsAppChat(
                                        phone: phone,
                                        message: capturedMessage,
                                      );
                                    } else {
                                      if (!context.mounted) return;
                                      await WhatsAppUtils.shareReceipt(
                                        context,
                                        phone: phone,
                                        message: capturedMessage,
                                        dialogTitle: 'Send Reminder',
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── PDF Share helper ─────────────────────────────────────────────────────
  // Generates a professional invoice PDF for [tx] (or a simple balance PDF
  // if [tx] is null) and opens the native OS share sheet.
  Future<void> _sharePdfForTransaction({
    required LedgerTransaction tx,
    required CustomerLedger ledger,
    required String shopName,
    String? shopAddress,
    String? shopPhone,
    String? shopGst,
    String shopType = 'general',
    String? shopLogoUrl,
    String? customTerms,
  }) async {
    // Show loading snackbar
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 14),
            Text('Preparing PDF…'),
          ],
        ),
        duration: Duration(seconds: 30),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final InvoiceData invoiceData;
      final t0 = DateTime.now();
      // ignore: avoid_print
      print('[PDF] ⏱ START ${t0.toIso8601String()}');

      // ── Authoritative payment amounts from ledger ──────────────────────
      final double txTotal = tx.amount;

      // Sum ALL payments on this customer ledger — not just ones tagged with
      // this receipt number. Standalone "Record Payment" entries get their own
      // sequential receipt numbers and would be missed by a receipt_number filter.
      final allTxs = _transactions ?? [];
      final totalPaidOnLedger = (_backendSummary['total_paid'] ?? 0.0) > 0
          ? _backendSummary['total_paid']!
          : allTxs
              .where((t) => t.transactionType == 'PAYMENT')
              .fold(0.0, (s, t) => s + t.amount);
      final totalBilledOnLedger = (_backendSummary['total_billed'] ?? 0.0) > 0
          ? _backendSummary['total_billed']!
          : allTxs
              .where((t) =>
                  t.transactionType == 'INVOICE' ||
                  t.transactionType == 'MANUAL_CREDIT')
              .fold(0.0, (s, t) => s + t.amount);

      // Proportionally attribute payments to this specific receipt's share
      final double txPaid;
      if (totalBilledOnLedger > 0 && totalPaidOnLedger > 0) {
        final receiptShare = txTotal / totalBilledOnLedger;
        txPaid = (totalPaidOnLedger * receiptShare).clamp(0.0, txTotal);
      } else {
        // Fallback: use receivedAmount stored on the transaction itself
        txPaid = tx.receivedAmount ?? 0.0;
      }
      final double txBalance = (txTotal - txPaid).clamp(0.0, double.infinity);
      final String txStatus = txBalance <= 0
          ? 'PAID'
          : (txPaid > 0 ? 'PARTIAL' : 'UNPAID');

      // ── Items: prefer local, fall back to verified_invoices API ────────
      // Manual/catalogue entries store items directly on the transaction.
      // AI-processed invoice receipts store items in verified_invoices
      // (one row per line item, keyed by receipt_number).
      List<Map<String, dynamic>> rawItems = tx.items;
      String gstMode = 'none';
      String? vehicleNumber;
      String? odometerReading;

      if (rawItems.isEmpty &&
          tx.receiptNumber != null &&
          tx.receiptNumber!.isNotEmpty) {
        // Fetch the verified invoice rows for this receipt
        try {
          // ignore: avoid_print
          print('[PDF] ⏱ getVerifiedInvoices START +${DateTime.now().difference(t0).inMilliseconds}ms');
          final repo = ref.read(verifiedRepositoryProvider);
          final records = await repo.getVerifiedInvoices(
            receiptNumber: tx.receiptNumber,
          );
          // ignore: avoid_print
          print('[PDF] ⏱ getVerifiedInvoices END +${DateTime.now().difference(t0).inMilliseconds}ms (${records.length} rows)');

          if (records.isNotEmpty) {
            final first = records.first;
            gstMode = first.gstMode ?? 'none';
            vehicleNumber = first.extraFields['vehicle_number']?.toString() ??
                first.extraFields['car_number']?.toString();
            odometerReading = first.extraFields['odometer']?.toString() ??
                first.extraFields['odometer_reading']?.toString();

            // Each VerifiedInvoice record = one line item
            rawItems = records
                .map((r) => <String, dynamic>{
                      'name': r.description.isNotEmpty ? r.description : 'Item',
                      'qty': r.quantity,
                      'rate': r.rate,
                      'amount': r.amount,
                      'type':
                          r.type.toLowerCase(), // 'part', 'labour', 'service'
                    })
                .toList();
          }
        } catch (_) {
          // If API fetch fails, still generate PDF with amounts (no items)
        }
      }

      final invoices = allTxs.where((t) =>
          t.transactionType == 'INVOICE' ||
          t.transactionType == 'MANUAL_CREDIT');
      final payments = allTxs.where((t) => t.transactionType == 'PAYMENT');
      final bool hideAccountSummary = invoices.length <= 1 && payments.length <= 1;

      invoiceData = InvoicePdfGenerator.fromLocalTransaction(
        shopName: shopName,
        shopAddress: shopAddress,
        shopPhone: shopPhone,
        shopGst: shopGst,
        shopLogoUrl: shopLogoUrl,
        customerName: ledger.customerName.isNotEmpty
            ? ledger.customerName
            : 'Customer',
        customerPhone: ledger.customerPhone,
        vehicleNumber: vehicleNumber,
        odometerReading: odometerReading,
        receiptNumber: tx.receiptNumber ?? ledger.id.toString(),
        date: tx.createdAt,
        totalAmount: txTotal,
        receivedAmount: txPaid > 0 ? txPaid : null,
        balanceDue: txBalance > 0 ? txBalance : 0,
        rawItems: rawItems,
        gstMode: gstMode,
        industry: shopType,
        status: txStatus,
        customTerms: customTerms,
        documentType: tx.isManualEntry ? 'bill' : 'order',
        // Account-level summary — shown in the banner at the bottom of the PDF
        // only when there are multiple receipts/payments. If there is only one
        // receipt and at most one payment, we hide the Account Summary to keep
        // the PDF clean and avoid redundant totals.
        accountTotalBilled: hideAccountSummary ? null : (totalBilledOnLedger > 0 ? totalBilledOnLedger : null),
        accountTotalPaid: hideAccountSummary ? null : totalPaidOnLedger,
        accountBalanceDue: hideAccountSummary
            ? null
            : (totalBilledOnLedger > 0
                ? (totalBilledOnLedger - totalPaidOnLedger).clamp(0.0, double.infinity)
                : null),
      );

      // ignore: avoid_print
      print('[PDF] ⏱ generate() START +${DateTime.now().difference(t0).inMilliseconds}ms');
      final pdfBytes = await InvoicePdfGenerator.generate(invoiceData);
      // ignore: avoid_print
      print('[PDF] ⏱ generate() DONE +${DateTime.now().difference(t0).inMilliseconds}ms (${pdfBytes.length} bytes)');

      if (!mounted) return;
      messenger.hideCurrentSnackBar();

      // Build filename: ShopName_ReceiptNo_Date.pdf
      // Handles Marathi/Hindi Devanagari shop names by keeping Unicode letters
      // e.g. जाधव_1586_07-Jun-2026.pdf  or  AK_Shop_1586_07-Jun-2026.pdf
      String slugifyPdf(String s) {
        // Strip control chars and filesystem-unsafe characters, keep Unicode letters/digits
        final cleaned = s.trim().replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '');
        // Collapse whitespace → underscore
        final spaced = cleaned.replaceAll(RegExp(r'\s+'), '_');
        // Remove leading/trailing underscores
        final slug = spaced.replaceAll(RegExp(r'^_+|_+$'), '');
        // If entirely empty (shouldn't happen), return 'Shop'
        return slug.isEmpty ? 'Shop' : slug;
      }

      final txDate = invoiceData.date.toLocal();
      // Use ddMMyyHHmmss format (e.g. 080626120743) so every download gets a
      // unique filename — prevents the browser from showing "Download again?"
      // and ensures fresh downloads even for the same bill.
      final now = DateTime.now();
      final dd = txDate.day.toString().padLeft(2, '0');
      final mm = txDate.month.toString().padLeft(2, '0');
      final yy = (txDate.year % 100).toString().padLeft(2, '0');
      final hh = now.hour.toString().padLeft(2, '0');
      final mi = now.minute.toString().padLeft(2, '0');
      final ss = now.second.toString().padLeft(2, '0');
      final datePart = '$dd$mm$yy$hh$mi$ss';
      final shopPart = slugifyPdf(invoiceData.shopName);
      final receiptPart = slugifyPdf(invoiceData.receiptNumber);
      final isGst = invoiceData.gstMode != 'none';
      final fileName = isGst
          ? '${shopPart}_Tax_${receiptPart}_$datePart.pdf'
          : '${shopPart}_${receiptPart}_$datePart.pdf';

      if (kIsWeb) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => AlertDialog(
            title: const Text('PDF Ready', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text('Your invoice PDF has been generated successfully.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  FileDownloadHelper.downloadFile(pdfBytes, fileName, 'application/pdf');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                ),
                child: const Text('DOWNLOAD'),
              ),
            ],
          ),
        );
      } else {
        // Open native OS share sheet with the PDF file.
        // On Android Chrome / iOS Safari: pops up the system share chooser
        // (WhatsApp, Gmail, Drive, etc.) — exactly like top apps do.
        // On desktop browsers: falls back to a direct file download.
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                pdfBytes,
                mimeType: 'application/pdf',
                name: fileName,
              ),
            ],
            text: '${invoiceData.shopName} — Invoice PDF',
          ),
        );
      }

    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not generate PDF: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDeleteTransaction(LedgerTransaction tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete Transaction',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete this ${tx.transactionType == 'PAYMENT' ? 'payment' : 'entry'}? This action cannot be undone and balances will be recalculated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'CANCEL',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'DELETE',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref
          .read(udharProvider.notifier)
          .deleteTransaction(tx.id);
      if (success && mounted) {
        // Show success snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Transaction deleted successfully'),
            backgroundColor: context.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Refresh local view
        _loadTransactions();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to delete transaction'),
            backgroundColor: context.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _summaryChip(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: context.textSecondaryColor,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // ── Skeleton loader shown while transactions are fetching ──────────────────
  // Mirrors the real transaction card shape so there's no layout jump when
  // data arrives. Uses the shimmer package already present in pubspec.
  Widget _buildTransactionSkeleton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFE0E0E0);
    final highlightColor = isDark
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFF5F5F5);

    Widget ghostCard() {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.borderColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon box placeholder
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + amount row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 110,
                        height: 14,
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      Container(
                        width: 72,
                        height: 16,
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Date row
                  Container(
                    width: 90,
                    height: 10,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Balance chip placeholder
                  Container(
                    width: 130,
                    height: 10,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(6, (_) => ghostCard()),
      ),
    );
  }
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildTransactionCard(LedgerTransaction tx) {
    final isPayment = tx.transactionType == 'PAYMENT';
    final isInvoice =
        tx.transactionType == 'INVOICE' ||
        tx.transactionType == 'MANUAL_CREDIT';
    final canNavigateToOrderDetails =
        isInvoice &&
        !tx.isManualEntry &&
        (tx.receiptNumber != null || tx.receiptLink != null);
    final hasReceiptPhoto =
        tx.receiptLink != null &&
        tx.receiptLink!.isNotEmpty &&
        tx.receiptLink != 'null';

    final Color accentColor = isPayment
        ? context.successColor
        : context.errorColor;
    final Color bgColor = accentColor.withValues(alpha: 0.08);

    final IconData txIcon = isPayment
        ? LucideIcons.arrowDownLeft
        : LucideIcons.arrowUpRight;
    final String txTitle = isPayment
        ? 'Payment Received'
        : (tx.paymentMode != null && tx.paymentMode!.toLowerCase() != 'credit'
              ? '${tx.paymentMode} Sale'
              : 'Credit Sale');

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _confirmDeleteTransaction(tx);
      },
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: context.premiumShadow,
          border: Border.all(
            color: context.borderColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              onTap: tx.isManualEntry
                  ? (tx.items.isNotEmpty
                        ? () {
                            setState(() {
                              final isExpanded = _expandedItems[tx.id] ?? false;
                              _expandedItems[tx.id] = !isExpanded;
                            });
                          }
                        : null)
                  : (canNavigateToOrderDetails
                        ? () => _navigateToOrderDetails(tx)
                        : null),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(txIcon, color: accentColor, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                txTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                '${isPayment ? '-' : '+'} ${CurrencyFormatter.format(tx.amount)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: accentColor,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                LucideIcons.calendar,
                                size: 12,
                                color: context.textSecondaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                () {
                                  final local = tx.createdAt.toLocal();
                                  final now = DateTime.now();
                                  final isToday =
                                      local.year == now.year &&
                                      local.month == now.month &&
                                      local.day == now.day;
                                  final isYesterday =
                                      local.year == now.year &&
                                      local.month == now.month &&
                                      local.day == now.day - 1;
                                  final datePart = isToday
                                      ? 'Today'
                                      : isYesterday
                                      ? 'Yesterday'
                                      : DateFormat('dd MMM yyyy').format(local);

                                  // Check if date-only (midnight UTC) to avoid showing default 5:30 AM/12:00 AM
                                  final isDateOnly =
                                      tx.createdAt.toUtc().hour == 0 &&
                                      tx.createdAt.toUtc().minute == 0 &&
                                      tx.createdAt.toUtc().second == 0;

                                  if (isDateOnly) {
                                    return datePart;
                                  }

                                  final timePart = DateFormat(
                                    'h:mm a',
                                  ).format(local);
                                  return '$datePart • $timePart';
                                }(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.textSecondaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (tx.notes != null && tx.notes!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: context.textSecondaryColor.withValues(
                                  alpha: 0.05,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.messageSquare,
                                    size: 10,
                                    color: context.textSecondaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      // Clean up auto-generated notes for SMB readability
                                      tx.notes!.startsWith(
                                            'Payment collected for Invoice',
                                          )
                                          ? 'Full balance collected'
                                          : tx.notes!.startsWith(
                                              'Auto-generated payment',
                                            )
                                          ? 'Payment for Invoice #${tx.receiptNumber ?? ""}'
                                          : tx.notes!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: context.textSecondaryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          // ── Delivery Date chip (Laundry only) ──────────────
                          if (tx.deliveryDate != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.truck,
                                    size: 10,
                                    color: Color(0xFF7C3AED),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Delivery: ${DateFormat("dd MMM yyyy").format(tx.deliveryDate!.toLocal())}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF7C3AED),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // User Clarity Row: Bill, Paid, Balance
            if (isInvoice)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: context.textSecondaryColor.withValues(alpha: 0.03),
                  border: Border(
                    top: BorderSide(color: context.borderColor, width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildClarityItem(
                      'Bill Amount',
                      CurrencyFormatter.format(tx.amount),
                    ),
                    _buildClarityItem(
                      'Paid',
                      CurrencyFormatter.format(
                        tx.receivedAmount ??
                            (tx.amount -
                                (tx.balanceDue ?? (tx.isPaid ? 0 : tx.amount))),
                      ),
                    ),
                    _buildClarityItem(
                      'Balance',
                      CurrencyFormatter.format(
                        tx.balanceDue ?? (tx.isPaid ? 0 : tx.amount),
                      ),
                      valueColor:
                          (tx.balanceDue ?? (tx.isPaid ? 0 : tx.amount)) <= 0
                          ? context.successColor
                          : context.errorColor,
                    ),
                  ],
                ),
              ),

            // ── Expandable Items Section (manual entries with item details) ──
            if (isInvoice && tx.items.isNotEmpty) _buildExpandableItems(tx),

            // Actions Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                border: Border(
                  top: BorderSide(color: context.borderColor, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  if (tx.receiptNumber != null && !tx.isManualEntry)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '#${tx.receiptNumber}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: context.textSecondaryColor.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ),
                  if (tx.isManualEntry)
                    // Show MANUAL badge
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(
                            0xFFF59E0B,
                          ).withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: const Text(
                        'MANUAL',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFD97706),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (hasReceiptPhoto && !tx.isManualEntry)
                    TextButton.icon(
                      onPressed: () => _showReceiptPhotoDialog(tx),
                      icon: const Icon(LucideIcons.eye, size: 14),
                      label: const Text(
                        'VIEW BILL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: context.primaryColor,
                      ),
                    ),
                  if (isInvoice) ...[
                    // SETTLED badge for paid invoices
                    if (tx.isPaid)
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.successColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: context.successColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.checkCircle2,
                              size: 10,
                              color: context.successColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'SETTLED',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: context.successColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Collapsible item breakdown panel for manual-entry MANUAL_CREDIT transactions.
  Widget _buildExpandableItems(LedgerTransaction tx) {
    final isExpanded = _expandedItems[tx.id] ?? false;
    final items = tx.items;

    return GestureDetector(
      onTap: () {
        setState(() {
          _expandedItems[tx.id] = !isExpanded;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: context.primaryColor.withValues(alpha: 0.03),
          border: Border(
            top: BorderSide(color: context.borderColor, width: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header / toggle row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.packageOpen,
                    size: 13,
                    color: context.primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${items.length} item${items.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: context.primaryColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      LucideIcons.chevronDown,
                      size: 14,
                      color: context.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            // Expanded item rows
            if (isExpanded)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Column header
                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(
                            'ITEM',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: context.textSecondaryColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(
                            'QTY',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: context.textSecondaryColor,
                              letterSpacing: 0.8,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(
                          width: 56,
                          child: Text(
                            'RATE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: context.textSecondaryColor,
                              letterSpacing: 0.8,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        SizedBox(
                          width: 64,
                          child: Text(
                            'AMOUNT',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: context.textSecondaryColor,
                              letterSpacing: 0.8,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Divider(height: 1, color: context.borderColor),
                    const SizedBox(height: 6),
                    ...items.map((item) {
                      final name = item['item_name']?.toString() ?? '';
                      final qty =
                          double.tryParse(
                            item['quantity']?.toString() ?? '1',
                          ) ??
                          1.0;
                      final rate =
                          double.tryParse(item['rate']?.toString() ?? '0') ??
                          0.0;
                      final amount =
                          double.tryParse(item['amount']?.toString() ?? '0') ??
                          (qty * rate);
                      final qtyStr = qty == qty.truncateToDouble()
                          ? qty.toInt().toString()
                          : qty.toStringAsFixed(1);
                      final rawUnit = (item['unit']?.toString() ?? '').trim().toUpperCase();
                      final unit = (rawUnit == 'NOS' || rawUnit.isEmpty) ? '' : rawUnit;
                      final showQty = qty != 1.0 || unit.isNotEmpty;
                      final qtyText = showQty
                          ? (unit.isNotEmpty ? '×$qtyStr $unit' : '×$qtyStr')
                          : '';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.textColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              child: Text(
                                qtyText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: context.textSecondaryColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(
                              width: 56,
                              child: Text(
                                '₹${rate.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.textSecondaryColor,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            SizedBox(
                              width: 64,
                              child: Text(
                                '₹${amount.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: context.textColor,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildClarityItem(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: context.textSecondaryColor.withValues(alpha: 0.6),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: valueColor ?? context.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              shape: BoxShape.circle,
              boxShadow: context.premiumShadow,
            ),
            child: Icon(
              LucideIcons.fileText,
              size: 48,
              color: context.borderColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: context.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Transactions will appear here once\nan invoice or payment is recorded.',
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondaryColor,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
