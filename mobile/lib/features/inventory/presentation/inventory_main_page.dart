import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
// v1 DISABLED: purchaseOrderProvider used only by Quick Links card — uncomment to restore
// import 'package:mobile/features/purchase_orders/presentation/providers/purchase_order_provider.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_items_provider.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_provider.dart';

import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/dashboard/presentation/customers_tab.dart';
import 'package:mobile/features/verified/presentation/providers/verified_provider.dart';

import 'package:mobile/features/inventory/presentation/inventory_review_page.dart';
import 'package:mobile/features/review/presentation/providers/review_provider.dart';

// ─── Page ────────────────────────────────────────────────────────────────────
class InventoryMainPage extends ConsumerStatefulWidget {
  const InventoryMainPage({super.key});

  @override
  ConsumerState<InventoryMainPage> createState() => _InventoryMainPageState();
}

class _InventoryMainPageState extends ConsumerState<InventoryMainPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // Rebuild for FAB switch
      }
    });
    // Fetch verified orders so the CUSTOMERS tab shows all processed orders
    // (paid, partial, credit) as soon as the Home page is opened.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(verifiedProvider);
      if (state.records.isEmpty && !state.isLoading) {
        ref.read(verifiedProvider.notifier).fetchRecords();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _dateLabel(String rawDate) {
    final dt = DateTime.tryParse(rawDate);
    if (dt == null) return rawDate;
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(dt.year, dt.month, dt.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('d MMM').format(dt);
  }

  List<InventoryInvoiceBundle> _groupItems(List<InventoryItem> items) {
    final Map<String, InventoryInvoiceBundle> groups = {};
    for (final item in items) {
      final key = item.invoiceNumber.isNotEmpty
          ? item.invoiceNumber
          : '${item.invoiceDate}_${item.vendorName ?? ''}';
      final safeKey = key.isNotEmpty ? key : item.id.toString();

      if (!groups.containsKey(safeKey)) {
        groups[safeKey] = InventoryInvoiceBundle(
          invoiceNumber: item.invoiceNumber,
          date: item.invoiceDate,
          vendorName: item.vendorName?.isNotEmpty == true
              ? item.vendorName!
              : 'Unknown Vendor',
          receiptLink: item.receiptLink,
          items: [],
          totalAmount: 0,
          hasMismatch: false,
          isVerified: true, // assume verified until we find otherwise
          createdAt: item.createdAt ?? '',
          headerAdjustments: item.headerAdjustments ?? [],
        );
      }
      final bundle = groups[safeKey]!;
      bundle.items.add(item);
      bundle.totalAmount += item.netBill;
      if (item.amountMismatch.abs() > 1.0) bundle.hasMismatch = true;
      // If any item is NOT verified, the whole bundle is not verified
      if (item.verificationStatus != 'Done') bundle.isVerified = false;
      // Track most recent upload date
      if (item.createdAt != null && (bundle.createdAt.isEmpty || item.createdAt!.compareTo(bundle.createdAt) > 0)) {
        bundle.createdAt = item.createdAt!;
      }
      // Sync payment mode
      if (item.paymentMode == 'Cash') {
        bundle.paymentMode = 'Cash';
      } else if (item.paymentMode == 'Credit' && bundle.paymentMode != 'Cash') {
        bundle.paymentMode = 'Credit';
      }
    }

    return groups.values.toList()
      ..sort((a, b) {
        // 1. Reviewed (isVerified) first
        if (a.isVerified && !b.isVerified) return -1;
        if (!a.isVerified && b.isVerified) return 1;

        // 2. Most recent upload (createdAt) first
        if (a.createdAt.isNotEmpty && b.createdAt.isNotEmpty) {
          final cA = DateTime.tryParse(a.createdAt) ?? DateTime(0);
          final cB = DateTime.tryParse(b.createdAt) ?? DateTime(0);
          final createdCmp = cB.compareTo(cA);
          if (createdCmp != 0) return createdCmp;
        }

        // 3. Fallback to invoice date
        final dA = DateTime.tryParse(a.date) ?? DateTime(0);
        final dB = DateTime.tryParse(b.date) ?? DateTime(0);
        return dB.compareTo(dA);
      });
  }

  @override
  Widget build(BuildContext context) {
    // v1 DISABLED: poState used only by Quick Links card — uncomment to restore
    // final poState = ref.watch(purchaseOrderProvider);
    final itemsAsync = ref.watch(inventoryItemsProvider);

    final pendingCount = itemsAsync.maybeWhen(
      data: (items) {
        final Map<String, bool> unverifiedReceipts = {};
        for (final item in items) {
          if (item.verificationStatus != 'Done') {
            final key = item.invoiceNumber.isNotEmpty
                ? item.invoiceNumber
                : '${item.invoiceDate}_${item.vendorName ?? ''}';
            final safeKey = key.isNotEmpty ? key : item.id.toString();
            unverifiedReceipts[safeKey] = true;
          }
        }
        return unverifiedReceipts.length;
      },
      orElse: () => 0,
    );

    final customerReviewState = ref.watch(reviewProvider);
    final customerPendingCount = customerReviewState.groups.length;

    final userState = ref.watch(authProvider);
    final String shopName =
        userState.user?.name ?? userState.user?.username ?? 'My Shop';
    final String greeting = '${_getGreeting()}, $shopName'.toUpperCase();

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        titleSpacing: 16,
        surfaceTintColor: Colors.transparent,
        backgroundColor: context.surfaceColor,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            greeting,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: context.textColor,
              letterSpacing: -0.5,
            ),
          ),
        ),
        actions: [
          _tabController.index == 0
              ? IconButton(
                  icon: Badge(
                    isLabelVisible: pendingCount > 0,
                    label: Text(
                        pendingCount > 99 ? '99+' : pendingCount.toString()),
                    backgroundColor: context.errorColor,
                    child: const Icon(LucideIcons.clipboardCheck),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.push('/inventory-review');
                  },
                )
              : IconButton(
                  icon: Badge(
                    isLabelVisible: customerPendingCount > 0,
                    label: Text(customerPendingCount > 99
                        ? '99+'
                        : customerPendingCount.toString()),
                    backgroundColor: context.errorColor,
                    child: const Icon(LucideIcons.clipboardCheck),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.push('/review');
                  },
                ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                labelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800, letterSpacing: 0.1),
                unselectedLabelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorWeight: 3,
                indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(width: 3.5, color: context.primaryColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                indicatorColor: context.primaryColor,
                labelColor: context.primaryColor,
                unselectedLabelColor: context.textSecondaryColor,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'SUPPLIERS'),
                  Tab(text: 'CUSTOMERS'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRecentDeliveriesTab(context, itemsAsync, pendingCount),
          const CustomersTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? _buildSnapNewReceiptFab(context)
          : _buildAddNewItemsFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildAddNewItemsFab(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [context.errorColor, context.errorColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: context.errorColor.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.push('/inventory-upload');
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        extendedIconLabelSpacing: 10,
        icon: const Icon(Icons.camera_alt_rounded, size: 22, color: Colors.white),
        label: Text(
          'Scan Supplier Purchase',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: Colors.white,
                fontSize: 15,
              ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  Widget _buildSnapNewReceiptFab(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [context.successColor, context.successColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: context.successColor.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.pushNamed('upload');
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        extendedIconLabelSpacing: 10,
        icon: const Icon(Icons.camera_alt_rounded, size: 22, color: Colors.white),
        label: Text(
          'Snap New Receipt',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: Colors.white,
                fontSize: 15,
              ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  Widget _buildRecentDeliveriesTab(
      BuildContext context,
      AsyncValue<List<InventoryItem>> itemsAsync,
      int pendingCount) {
    // v1 DISABLED: PurchaseOrderState poState parameter removed (Quick Links hidden)
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(inventoryItemsProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── v1 DISABLED: Quick Links card (uncomment to restore) ─────────────
            // _buildQuickLinksCard(context, pendingCount, poState),
            // const SizedBox(height: 28),
            Row(
              children: [
                Text(
                  'Recent Supplier Deliveries',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.textColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                if (itemsAsync.isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _buildSearchBox(),
            const SizedBox(height: 12),
            _buildDeliveriesList(context, itemsAsync),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor, // Use adaptive surface color
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
        style: TextStyle(
          fontSize: 14,
          color: context.textColor,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Search by vendor, invoice ID or item…',
          hintStyle: TextStyle(
            color: context.textSecondaryColor,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon:
              Icon(LucideIcons.search, size: 18, color: context.textSecondaryColor),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(LucideIcons.x,
                      size: 16, color: context.textSecondaryColor),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
      ),
    );
  }


  // ───────────────────────────────────────────────────────────────────
  // v1 DISABLED: Quick Links card & action item methods
  // Uncomment the two methods below to restore the Quick Links section.
  // Also restore: import, poState watch, _buildRecentDeliveriesTab param, and card call.
  // ───────────────────────────────────────────────────────────────────
  //
  // Widget _buildQuickLinksCard(
  //     BuildContext context, int pendingCount, PurchaseOrderState poState) {
  //   return Container(
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: AppTheme.surface,
  //       borderRadius: BorderRadius.circular(16),
  //       border: Border.all(color: AppTheme.border),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withValues(alpha: 0.02),
  //           blurRadius: 8,
  //           offset: const Offset(0, 2),
  //         ),
  //       ],
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Text('Quick Links',
  //             style: Theme.of(context).textTheme.titleMedium?.copyWith(
  //                   fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
  //         const SizedBox(height: 16),
  //         Row(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             _buildActionItem(
  //               context: context, icon: LucideIcons.box,
  //               color: const Color(0xFFF59E0B), title: 'Stock',
  //               onTap: () { HapticFeedback.lightImpact(); context.push('/current-stock'); },
  //             ),
  //             _buildActionItem(
  //               context: context, icon: LucideIcons.shoppingCart,
  //               color: const Color(0xFFEA580C), title: 'PO',
  //               badgeCount: poState.draftCount,
  //               onTap: () { HapticFeedback.lightImpact(); context.push('/purchase-orders'); },
  //             ),
  //             _buildActionItem(
  //               context: context, icon: LucideIcons.gitMerge,
  //               color: const Color(0xFF3B82F6), title: 'Link Items',
  //               onTap: () { HapticFeedback.lightImpact(); context.push('/inventory-item-mapping'); },
  //             ),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }
  //
  // Widget _buildActionItem({
  //   required BuildContext context, required IconData icon,
  //   required Color color, required String title,
  //   int badgeCount = 0, required VoidCallback onTap,
  // }) {
  //   return Expanded(
  //     child: InkWell(
  //       onTap: onTap, borderRadius: BorderRadius.circular(12),
  //       child: Padding(
  //         padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             Stack(clipBehavior: Clip.none, children: [
  //               Container(width: 48, height: 48,
  //                 decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
  //                   borderRadius: BorderRadius.circular(14)),
  //                 child: Icon(icon, color: color, size: 24)),
  //               if (badgeCount > 0)
  //                 Positioned(top: -6, right: -6,
  //                   child: Container(
  //                     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  //                     decoration: BoxDecoration(color: const Color(0xFFEF4444),
  //                       borderRadius: BorderRadius.circular(10),
  //                       border: Border.all(color: Colors.white, width: 2)),
  //                     constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
  //                     child: Text(badgeCount > 99 ? '99+' : '$badgeCount',
  //                       style: const TextStyle(color: Colors.white, fontSize: 10,
  //                         fontWeight: FontWeight.bold, height: 1.1),
  //                       textAlign: TextAlign.center))),
  //             ]),
  //             const SizedBox(height: 8),
  //             Text(title, textAlign: TextAlign.center,
  //               style: Theme.of(context).textTheme.labelSmall?.copyWith(
  //                 fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
  //               maxLines: 2, overflow: TextOverflow.ellipsis),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildDeliveriesList(
      BuildContext context, AsyncValue<List<InventoryItem>> itemsAsync) {
    return itemsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(LucideIcons.wifiOff, size: 48, color: context.borderColor),
              const SizedBox(height: 12),
              Text('Could not load deliveries',
                  style: TextStyle(
                      color: context.textSecondaryColor,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Pull down to retry',
                  style: TextStyle(color: context.textSecondaryColor.withValues(alpha: 0.7), fontSize: 12)),
            ],
          ),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Icon(LucideIcons.truck,
                        size: 48, color: context.borderColor),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No supplier deliveries yet',
                    style: TextStyle(
                        color: context.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap "Scan Supplier Purchase" to snap\na vendor bill or purchase order',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.textSecondaryColor, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        var bundles = _groupItems(items);

        // Only show verified (synced) deliveries in the recent list
        bundles = bundles.where((b) => b.isVerified).toList();

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          bundles = bundles.where((b) {
            final vendorMatch =
                b.vendorName.toLowerCase().contains(_searchQuery);
            final invoiceMatch =
                b.invoiceNumber.toLowerCase().contains(_searchQuery);
            final itemMatch = b.items.any((i) =>
                i.description.toLowerCase().contains(_searchQuery) ||
                i.partNumber.toLowerCase().contains(_searchQuery));
            return vendorMatch || invoiceMatch || itemMatch;
          }).toList();
        }

        if (bundles.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(LucideIcons.searchX,
                      size: 48, color: context.borderColor),
                  const SizedBox(height: 16),
                  Text(
                    'No results found',
                    style: TextStyle(
                        color: context.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try searching by vendor, invoice ID or item name',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: context.textSecondaryColor, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: bundles.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final bundle = bundles[index];
            return _VendorDeliveryCard(
              bundle: bundle,
              dateLabel: _dateLabel(bundle.date),
              searchQuery: _searchQuery,
              allItems: items,
            );
          },
        );
      },
    );
  }
}

// ─── Vendor Delivery Card ─────────────────────────────────────────────────────
class _VendorDeliveryCard extends ConsumerWidget {
  final InventoryInvoiceBundle bundle;
  final String dateLabel;
  final String searchQuery;
  final List<InventoryItem> allItems;

  const _VendorDeliveryCard({
    required this.bundle,
    required this.dateLabel,
    required this.searchQuery,
    required this.allItems,
  });

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, InventoryInvoiceBundle bundle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Invoice?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            'Are you sure you want to delete this invoice for "${bundle.vendorName}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: context.textSecondaryColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.errorColor,
              foregroundColor: context.surfaceColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ids = bundle.items.map((i) => i.id).toList();
      await ref.read(inventoryProvider.notifier).bulkDeleteItems(ids);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Invoice deleted successfully'),
            backgroundColor: context.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasMismatch = bundle.hasMismatch;
    final isPaid = bundle.isPaid;
    final hasChori = bundle.hasChoriCatcherAlert;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/vendor-delivery-detail', extra: bundle);
      },
      onLongPress: () {
        HapticFeedback.heavyImpact();
        _confirmDelete(context, ref, bundle);
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasChori
                ? context.errorColor.withValues(alpha: 0.3)
                : context.borderColor.withValues(alpha: 0.8),
            width: hasChori ? 1.5 : 1.0,
          ),
          boxShadow: context.premiumShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Left icon ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: hasChori
                      ? context.errorColor.withValues(alpha: 0.08)
                      : context.primaryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasChori
                      ? LucideIcons.alertCircle
                      : LucideIcons.packageCheck,
                  color: hasChori
                      ? context.errorColor
                      : context.primaryColor,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // ── Main content ────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: vendor name + paid/credit pill
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          bundle.vendorName,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: context.textColor,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // ── Paid / Credit pill ──────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isPaid
                              ? context.successColor.withValues(alpha: 0.1)
                              : context.warningColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isPaid
                                ? context.successColor.withValues(alpha: 0.4)
                                : context.warningColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          isPaid ? '✓ Paid' : 'Credit',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isPaid
                                ? context.successColor
                                : context.warningColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Row 2: invoice number
                  if (bundle.invoiceNumber.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(LucideIcons.hash,
                              size: 11, color: context.textSecondaryColor),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              bundle.invoiceNumber,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: context.textSecondaryColor,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 5),

                  // Row 3: date · items · amount
                  Row(
                    children: [
                      Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(' · ',
                          style: TextStyle(
                              color: context.textSecondaryColor,
                              fontSize: 12)),
                      Text(
                        '${bundle.items.length} item${bundle.items.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: context.textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(' · ',
                          style: TextStyle(
                              color: context.textSecondaryColor,
                              fontSize: 12)),
                      Text(
                        CurrencyFormatter.format(bundle.totalAmount),
                        style: TextStyle(
                          color: context.primaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),

                  // Row 4: Rate Hike alert (only if triggered)
                  if (hasChori)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.errorColor.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: context.errorColor.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                size: 13, color: context.errorColor),
                            const SizedBox(width: 5),
                            Text(
                              hasMismatch && bundle.totalPriceHike > 0
                                  ? '🔴 Bill mismatch + price hike detected'
                                  : hasMismatch
                                      ? '🔴 Bill amount mismatch detected'
                                      : '🔴 Price hike: ${CurrencyFormatter.format(bundle.totalPriceHike)} extra',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.errorColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Chevron ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Icon(LucideIcons.chevronRight,
                  size: 20, color: context.textSecondaryColor.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }


}
