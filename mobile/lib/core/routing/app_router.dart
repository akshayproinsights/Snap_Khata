import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/auth/presentation/login_page.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_page.dart';
import 'package:mobile/features/upload/presentation/upload_page.dart';
import 'package:mobile/features/review/presentation/pending_receipts_page.dart';
import 'package:mobile/features/review/presentation/receipt_review_page.dart';
import 'package:mobile/features/review/presentation/review_dates_page.dart';
import 'package:mobile/features/review/presentation/review_amounts_page.dart';
import 'package:mobile/features/review/presentation/verify_parts_page.dart';
import 'package:mobile/features/verified/presentation/verified_invoices_page.dart';
import 'package:mobile/features/inventory/presentation/inventory_upload_page.dart';
import 'package:mobile/features/inventory/presentation/inventory_mapping_page.dart';
import 'package:mobile/features/inventory/presentation/inventory_main_page.dart';
import 'package:mobile/features/inventory/presentation/inventory_item_mapping_page.dart';
import 'package:mobile/features/inventory/presentation/inventory_mapped_page.dart';
import 'package:mobile/features/inventory/presentation/inventory_review_page.dart';
import 'package:mobile/features/inventory/presentation/inventory_invoice_review_page.dart';
import 'package:mobile/features/inventory/presentation/current_stock_page.dart';
import 'package:mobile/features/vendor/presentation/vendor_mapping_page.dart';
import 'package:mobile/features/purchase_orders/presentation/purchase_orders_page.dart';
import 'package:mobile/features/purchase_orders/presentation/create_po_page.dart';
import 'package:mobile/features/purchase_orders/presentation/quick_reorder_page.dart';
import 'package:mobile/features/notifications/presentation/notifications_page.dart';
import 'package:mobile/core/routing/app_shell.dart';
import 'package:mobile/features/settings/presentation/settings_page.dart';
import 'package:mobile/features/dashboard/presentation/party_ledger_page.dart';
import 'package:mobile/features/dashboard/presentation/order_detail_page.dart';
import 'package:mobile/features/shared/domain/models/invoice_group.dart';
import 'package:mobile/features/review/domain/models/review_models.dart';
import 'package:mobile/features/udhar/presentation/udhar_list_page.dart';
import 'package:mobile/features/udhar/presentation/udhar_detail_page.dart';
import 'package:mobile/features/udhar/domain/models/udhar_models.dart';
import 'package:mobile/features/inventory/presentation/vendor_ledger/vendor_ledger_list_page.dart';
import 'package:mobile/features/inventory/presentation/vendor_ledger/vendor_ledger_detail_page.dart';
import 'package:mobile/features/inventory/domain/models/vendor_ledger_models.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation:
        '/login', // Will be changed to redirect based on auth state later
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                name: 'dashboard',
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inventory',
                name: 'inventory',
                builder: (context, state) => const InventoryMainPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/upload',
        name: 'upload',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const UploadPage(),
      ),
      GoRoute(
        path: '/review',
        name: 'review',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final skippedCount = extra?['skippedCount'] as int? ?? 0;
          return PendingReceiptsPage(skippedCount: skippedCount);
        },
      ),
      GoRoute(
        path: '/receipt-review',
        name: 'receipt-review',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final group = state.extra as InvoiceReviewGroup;
          return ReceiptReviewPage(group: group);
        },
      ),
      GoRoute(
        path: '/review-dates',
        name: 'review-dates',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ReviewDatesPage(),
      ),
      GoRoute(
        path: '/review-amounts',
        name: 'review-amounts',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ReviewAmountsPage(),
      ),
      GoRoute(
        path: '/verify-parts',
        name: 'verify-parts',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const VerifyPartsPage(),
      ),
      GoRoute(
        path: '/verified-invoices',
        name: 'verified-invoices',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const VerifiedInvoicesPage(),
      ),
      GoRoute(
        path: '/inventory-mapping',
        name: 'inventory-mapping',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const InventoryMappingPage(),
      ),
      GoRoute(
        path: '/inventory-item-mapping',
        name: 'inventory-item-mapping',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const InventoryItemMappingPage(),
      ),
      GoRoute(
        path: '/inventory-mapped',
        name: 'inventory-mapped',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const InventoryMappedPage(),
      ),
      GoRoute(
        path: '/current-stock',
        name: 'current-stock',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CurrentStockPage(),
      ),
      GoRoute(
        path: '/vendor-mapping',
        name: 'vendor-mapping',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const VendorMappingPage(),
      ),
      GoRoute(
        path: '/party-ledger',
        name: 'party-ledger',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>?;
          return PartyLedgerPage(
            customerName: extras?['customerName'] as String? ?? 'Unknown',
            vehicleNumber: extras?['vehicleNumber'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        path: '/inventory-review',
        name: 'inventory-review',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const InventoryReviewPage(),
      ),
      GoRoute(
        path: '/inventory-invoice-review',
        name: 'inventory-invoice-review',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final bundle = state.extra as InventoryInvoiceBundle;
          return InventoryInvoiceReviewPage(bundle: bundle);
        },
      ),
      GoRoute(
        path: '/inventory-upload',
        name: 'inventory-upload',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const InventoryUploadPage(),
      ),
      GoRoute(
        path: '/purchase-orders',
        name: 'purchase-orders',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PurchaseOrdersPage(),
      ),
      GoRoute(
        path: '/purchase-orders/create',
        name: 'create-po',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreatePoPage(),
      ),
      GoRoute(
        path: '/quick-reorder',
        name: 'quick-reorder',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const QuickReorderPage(),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/udhar',
        name: 'udhar-list',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const UdharListPage(),
      ),
      GoRoute(
        path: '/udhar/:id',
        name: 'udhar-detail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final ledger = state.extra as CustomerLedger;
          return UdharDetailPage(ledger: ledger);
        },
      ),
      GoRoute(
        path: '/inventory/vendor-ledger',
        name: 'vendor-ledger-list',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const VendorLedgerListPage(),
      ),
      GoRoute(
        path: '/inventory/vendor-ledger/:id',
        name: 'vendor-ledger-detail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final ledger = state.extra as VendorLedger;
          return VendorLedgerDetailPage(ledger: ledger);
        },
      ),
      GoRoute(
        path: '/order-detail',
        name: 'order-detail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final group = state.extra as InvoiceGroup;
          return OrderDetailPage(group: group);
        },
      ),
    ],
  );
}
