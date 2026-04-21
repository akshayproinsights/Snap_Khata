import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/theme/app_theme.dart';
// v1 DISABLED: purchaseOrderProvider used only by Quick Links card — uncomment to restore
// import 'package:mobile/features/purchase_orders/presentation/providers/purchase_order_provider.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_items_provider.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:mobile/features/inventory/domain/models/vendor_ledger_models.dart';
import 'package:mobile/features/inventory/presentation/providers/vendor_ledger_provider.dart';
import 'package:mobile/features/inventory/presentation/vendor_ledger/vendor_ledger_detail_page.dart';

import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/dashboard/presentation/customers_tab.dart';
import 'package:mobile/features/verified/presentation/providers/verified_provider.dart';

import 'package:mobile/features/inventory/presentation/inventory_review_page.dart';

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

    final userState = ref.watch(authProvider);
    final String shopName =
        userState.user?.name ?? userState.user?.username ?? 'My Shop';
    final String greeting = '${_getGreeting()}, $shopName'.toUpperCase();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        titleSpacing: 16,
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppTheme.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'HOME',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              greeting,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text(pendingCount > 99 ? '99+' : pendingCount.toString()),
              backgroundColor: const Color(0xFFEF4444),
              child: const Icon(LucideIcons.clipboardCheck),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push('/inventory-review');
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelPadding: const EdgeInsets.symmetric(horizontal: 14),
          labelStyle: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
          unselectedLabelStyle: Theme.of(context).textTheme.titleSmall,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Recent Deliveries'),
            Tab(text: 'CUSTOMERS'),
          ],
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
          ? _buildSnapNewOrderFab(context)
          : _buildAddNewItemsFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildAddNewItemsFab(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.push('/inventory-upload');
        },
        backgroundColor: const Color(0xFFEF4444), // red-500
        foregroundColor: Colors.white,
        icon: const Icon(Icons.camera_alt_rounded, size: 22),
        label: Text(
          'Scan Purchase Bill',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: Colors.white,
              ),
        ),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildSnapNewOrderFab(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.pushNamed('upload');
        },
        backgroundColor: const Color(0xFF16A34A), // green-700
        foregroundColor: Colors.white,
        icon: const Icon(Icons.camera_alt_rounded, size: 22),
        label: Text(
          'Snap New Order',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: Colors.white,
              ),
        ),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                const Text(
                  'Recent Vendor Deliveries',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
        style: const TextStyle(
          fontSize: 14,
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search by vendor, invoice ID or item…',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13.5),
          prefixIcon:
              Icon(LucideIcons.search, size: 18, color: Colors.grey.shade400),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(LucideIcons.x,
                      size: 16, color: Colors.grey.shade400),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
              Icon(LucideIcons.wifiOff, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('Could not load deliveries',
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Pull down to retry',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
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
                      color: Colors.grey.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(LucideIcons.truck,
                        size: 48, color: Colors.grey.shade300),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No vendor deliveries yet',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap "Scan Purchase Bill" to snap\na vendor bill or purchase order',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
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
                      size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'No results found',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try searching by vendor, invoice ID or item name',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
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
  Widget _buildPartyDetailsTab(
      BuildContext context, AsyncValue<List<InventoryItem>> itemsAsync) {
    if (itemsAsync.isLoading && !itemsAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }

    if (itemsAsync.hasError) {
      return Center(
        child: Text('Error: ${itemsAsync.error}',
            style: const TextStyle(color: AppTheme.error)),
      );
    }

    final items = itemsAsync.value ?? [];
    final Map<String, _VendorSummary> summaries = {};

    for (var item in items) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = (item.vendorName ?? '').toLowerCase().contains(query);
        final matchesInvoice = item.invoiceNumber.toLowerCase().contains(query);
        if (!matchesName && !matchesInvoice) continue;
      }

      final String vendorName = item.vendorName ?? 'Unknown';
      if (!summaries.containsKey(vendorName)) {
        summaries[vendorName] = _VendorSummary(
          vendorName: vendorName,
          latestInvoice: item.invoiceNumber,
          totalAmount: 0,
        );
      }

      summaries[vendorName]!.totalAmount += item.netBill;
      summaries[vendorName]!.itemIds.add(item.id);

      final String uniqueInvoice = item.invoiceNumber.isNotEmpty
          ? '${item.invoiceNumber}_$vendorName'
          : '${item.invoiceDate}_$vendorName';

      summaries[vendorName]!.invoices.add(uniqueInvoice);
    }

    final vendorList = summaries.values.toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Column(
      children: [
        if (items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: _buildSearchBox(),
          ),
        Expanded(
          child: summaries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.users,
                          size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No vendors found matching "$_searchQuery"'
                            : 'No specific vendor deliveries logged yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: vendorList.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final vendor = vendorList[index];

                    return Material(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppTheme.border),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          // Navigate to Vendor Ledger Detail page to see complete vendor history
                          final ledgerState = ref.read(vendorLedgerProvider);
                          // Try to find an existing ledger for this vendor
                          final existingLedger = ledgerState.ledgers.where(
                            (l) => l.vendorName.toLowerCase() == vendor.vendorName.toLowerCase(),
                          ).firstOrNull;

                          final ledger = existingLedger ?? VendorLedger(
                            id: -1, // Negative ID indicates view-only mode (no ledger exists yet)
                            vendorName: vendor.vendorName,
                            balanceDue: 0,
                          );

                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => VendorLedgerDetailPage(ledger: ledger),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.local_shipping,
                                  size: 22,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vendor.vendorName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${vendor.orderCount} Delivery(s)',
                                      style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currencyFormat.format(vendor.totalAmount),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: AppTheme.textPrimary,
                                          letterSpacing: -0.3,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Supplier',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 10,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  )
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}


class _VendorSummary {
  String vendorName;
  String latestInvoice;
  double totalAmount;
  Set<int> itemIds = {};
  Set<String> invoices = {};
  int get orderCount => invoices.length;

  _VendorSummary({
    required this.vendorName,
    required this.latestInvoice,
    required this.totalAmount,
  });
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Invoice?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            'Are you sure you want to delete this invoice for "${bundle.vendorName}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
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
          const SnackBar(
            content: Text('Invoice deleted successfully'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasChori
                ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                : Colors.grey.shade200,
            width: hasChori ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: hasChori
                  ? const Color(0xFFEF4444).withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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
                      ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                      : AppTheme.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasChori
                      ? LucideIcons.alertCircle
                      : LucideIcons.packageCheck,
                  color: hasChori
                      ? const Color(0xFFEF4444)
                      : AppTheme.primary,
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: AppTheme.textPrimary,
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
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isPaid
                                ? Colors.green.withValues(alpha: 0.4)
                                : Colors.orange.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          isPaid ? '✓ Paid' : 'Credit',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isPaid
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
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
                              size: 11, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              bundle.invoiceNumber,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
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
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Text(' · ',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12)),
                      Text(
                        '${bundle.items.length} item${bundle.items.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Text(' · ',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12)),
                      Text(
                        currencyFormat.format(bundle.totalAmount),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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
                          color: const Color(0xFFEF4444).withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFEF4444)
                                .withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                size: 13, color: Color(0xFFDC2626)),
                            const SizedBox(width: 5),
                            Text(
                              hasMismatch && bundle.totalPriceHike > 0
                                  ? '🔴 Bill mismatch + price hike detected'
                                  : hasMismatch
                                      ? '🔴 Bill amount mismatch detected'
                                      : '🔴 Price hike: ${currencyFormat.format(bundle.totalPriceHike)} extra',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFDC2626),
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
                  size: 20, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }


}
