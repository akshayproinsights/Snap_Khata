import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/verified/presentation/providers/verified_provider.dart';
import 'package:mobile/features/verified/domain/models/verified_models.dart';
import 'package:mobile/features/shared/domain/models/invoice_group.dart';
import 'package:mobile/core/utils/whatsapp_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/settings/presentation/providers/shop_provider.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/dashboard/presentation/order_detail_page.dart';

class PartyLedgerPage extends ConsumerStatefulWidget {
  final String customerName;
  final String vehicleNumber; // Might be empty

  const PartyLedgerPage({
    super.key,
    required this.customerName,
    required this.vehicleNumber,
  });

  @override
  ConsumerState<PartyLedgerPage> createState() => _PartyLedgerPageState();
}

class _PartyLedgerPageState extends ConsumerState<PartyLedgerPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(verifiedProvider);

    // Filter records: if a vehicleNumber was provided, use it as the primary key
    // (all records for that vehicle, regardless of customer name)
    // Otherwise fall back to matching by customer name.
    final List<VerifiedInvoice> partyRecords = state.records.where((record) {
      final vNum = record.extraFields['vehicle_number']?.toString() ?? '';
      if (widget.vehicleNumber.isNotEmpty) {
        return vNum == widget.vehicleNumber;
      }
      final effectiveName = record.customerName.isNotEmpty
          ? record.customerName
          : (vNum.isNotEmpty
              ? vNum
              : 'Unknown');
      return effectiveName == widget.customerName;
    }).toList();

    // 1. Group by receiptNumber (fallback to date)
    final Map<String, InvoiceGroup> groups = {};

    for (var record in partyRecords) {
      final String groupId = record.receiptNumber.isNotEmpty
          ? record.receiptNumber
          : (record.date.isNotEmpty ? record.date : record.uploadDate);
      final String safeId = groupId.isNotEmpty ? groupId : record.rowId;

      if (!groups.containsKey(safeId)) {
        groups[safeId] = InvoiceGroup(
          receiptNumber: record.receiptNumber,
          date: record.date.isNotEmpty ? record.date : record.uploadDate,
          receiptLink: record.receiptLink,
          customerName: record.customerName,
          mobileNumber: record.mobileNumber,
          extraFields: record.extraFields,
          uploadDate: record.uploadDate,
          paymentMode: record.paymentMode,
          receivedAmount: record.receivedAmount,
          balanceDue: record.balanceDue,
          customerDetails: record.customerDetails,
        );
      } else {
        final existingDt = DateTime.tryParse(groups[safeId]!.uploadDate) ?? DateTime(0);
        final newDt = DateTime.tryParse(record.uploadDate) ?? DateTime(0);
        if (newDt.isAfter(existingDt)) {
          groups[safeId]!.uploadDate = record.uploadDate;
        }
      }
      groups[safeId]!.items.add(record);
      groups[safeId]!.totalAmount += record.amount;
    }

    // 2. Sort groups descending by uploadDate
    final groupedList = groups.values.toList();
    groupedList.sort((a, b) {
      final dA = DateTime.tryParse(a.uploadDate) ?? DateTime(0);
      final dB = DateTime.tryParse(b.uploadDate) ?? DateTime(0);
      return dB.compareTo(dA);
    });

    // Determine display title: vehicle number is primary, customer name secondary
    final String headerTitle = widget.vehicleNumber.isNotEmpty
        ? widget.vehicleNumber
        : (widget.customerName.isNotEmpty ? widget.customerName : 'Unknown');
    final String headerSubtitle =
        widget.vehicleNumber.isNotEmpty && widget.customerName.isNotEmpty
            ? widget.customerName
            : '';

    final String initial = headerTitle.isNotEmpty && headerTitle != 'Unknown'
        ? headerTitle[0].toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            elevation: 0,
            backgroundColor: AppTheme.primary,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Primary title: vehicle number (or customer name if no vehicle)
                            Row(
                              children: [
                                if (widget.vehicleNumber.isNotEmpty)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(LucideIcons.truck,
                                        color: Colors.white, size: 16),
                                  ),
                                Expanded(
                                  child: Text(
                                    headerTitle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            // Secondary: customer name (only when navigating by vehicle with a known name)
                            if (headerSubtitle.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                headerSubtitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Timeline Header ───────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Text(
                'Transaction History',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),

          // ── Timeline ──────────────────────────────────
          if (state.isLoading && groupedList.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (groupedList.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  'No transactions found.',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.6),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _InvoiceGroupTile(
                    group: groupedList[i],
                  ),
                  childCount: groupedList.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Ledger Entry Tile (Grouped) ──────────────────────────────────────────

class _InvoiceGroupTile extends ConsumerWidget {
  final InvoiceGroup group;

  const _InvoiceGroupTile({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    // If receiptLink exists, we can show an eye icon to view the real image
    final dt = DateTime.tryParse(group.date) ?? DateTime.now();
    final bool hasLink =
        group.receiptLink.isNotEmpty && group.receiptLink != 'null';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: GestureDetector(
          onLongPress: () {
            HapticFeedback.heavyImpact();
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Order Record?'),
                content: const Text(
                    'Are you sure you want to permanently delete this order and all its items? This action cannot be undone.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      final rowIds = group.items.map((i) => i.rowId).toList();
                      if (rowIds.isNotEmpty) {
                        ref.read(verifiedProvider.notifier).deleteBulk(rowIds);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Order deleted successfully.'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      }
                    },
                    style:
                        TextButton.styleFrom(foregroundColor: AppTheme.error),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
          },
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderDetailPage(group: group),
                ),
              );
            },
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.receipt,
                  color: AppTheme.primary, size: 20),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Invoice ${group.receiptNumber.isNotEmpty ? "#${group.receiptNumber}" : "Captured"}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasLink)
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
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
                                  group.receiptLink,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Container(
                                    padding: const EdgeInsets.all(32),
                                    color: AppTheme.surface,
                                    child: const Text(
                                        'Failed to load receipt image.'),
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
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(LucideIcons.eye,
                          size: 18, color: AppTheme.primary),
                    ),
                  ),
                InkWell(
                  onTap: () async {
                    HapticFeedback.lightImpact();

                    // Load persisted GST mode for this receipt
                    final prefs = await SharedPreferences.getInstance();
                    final savedMode = prefs
                        .getString('gst_mode_order_${group.receiptNumber}');
                    final gstParam = (savedMode != null && savedMode != 'none')
                        ? '&g=$savedMode'
                        : '';

                    final authState = ref.read(authProvider);
                    final usernameParam = authState.user?.username != null
                        ? '&u=${authState.user!.username}'
                        : '';

                    final link =
                        'https://mydigientry.com/receipt.html?i=${group.receiptNumber}$gstParam$usernameParam';

                    final customerNameMsg = group.customerName.isNotEmpty &&
                            group.customerName.toLowerCase() != 'unknown'
                        ? group.customerName
                        : 'Customer';

                    final shopProfile = ref.read(shopProvider);
                    final shopName = shopProfile.name.isNotEmpty
                        ? shopProfile.name
                        : 'Our Shop';

                    OrderPaymentStatus status;
                    if (group.paymentMode == 'Cash') {
                      status = OrderPaymentStatus.fullyPaid;
                    } else {
                      final received = group.receivedAmount ?? 0.0;
                      if (received >= group.totalAmount) {
                        status = OrderPaymentStatus.fullyPaid;
                      } else if (received > 0) {
                        status = OrderPaymentStatus.partiallyPaid;
                      } else {
                        status = OrderPaymentStatus.unpaid;
                      }
                    }

                    final caption = WhatsAppUtils.getWhatsAppCaption(
                      status: status,
                      customerName: customerNameMsg,
                      businessName: shopName,
                      orderNumber: group.receiptNumber.isNotEmpty
                          ? group.receiptNumber
                          : 'Recent',
                      totalAmount: group.totalAmount,
                      paidAmount: group.paymentMode == 'Credit' ? (group.receivedAmount ?? 0.0) : group.totalAmount,
                      pendingAmount: group.balanceDue,
                    );
                    final message =
                        '$caption\n\nView your complete digital receipt and order details here:\n$link\n\nThank you for your business!\n— *${shopName.trim()}*';

                    if (!context.mounted) return;
                    await WhatsAppUtils.shareReceipt(
                      context,
                      phone: group.mobileNumber,
                      message: message,
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: FaIcon(FontAwesomeIcons.whatsapp,
                        size: 18, color: AppTheme.primary),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  Text(
                    _formatDate(dt),
                    style: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '• ${group.items.length} item(s)',
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            trailing: Text(
              CurrencyFormatter.format(group.totalAmount),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: -0.5,
              ),
            ),
          ), // End ListTile
        ), // End GestureDetector
      ), // End Theme
    ); // End Container
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0 && now.day == dt.day) return 'Today';
    if (diff.inDays == 1 || (diff.inDays == 0 && now.day != dt.day)) {
      return 'Yesterday';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
