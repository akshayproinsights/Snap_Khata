import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/auth/presentation/login_page.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_page.dart';
import 'package:mobile/features/upload/presentation/upload_page.dart';
import 'package:mobile/features/review/presentation/review_invoice_details_page.dart';
import 'package:mobile/features/review/presentation/review_dates_page.dart';
import 'package:mobile/features/review/presentation/review_amounts_page.dart';
import 'package:mobile/features/review/presentation/verify_parts_page.dart';
import 'package:mobile/features/verified/presentation/verified_invoices_page.dart';
import 'package:mobile/features/inventory/presentation/inventory_upload_page.dart';
import 'package:mobile/features/inventory/presentation/inventory_hub_page.dart';
import 'package:mobile/features/inventory/presentation/inventory_mapping_page.dart';
import 'package:mobile/features/inventory/presentation/inventory_item_mapping_page.dart';
import 'package:mobile/features/inventory/presentation/inventory_mapped_page.dart';
import 'package:mobile/features/inventory/presentation/current_stock_page.dart';
import 'package:mobile/features/vendor/presentation/vendor_mapping_page.dart';
import 'package:mobile/features/purchase_orders/presentation/purchase_orders_page.dart';
import 'package:mobile/features/purchase_orders/presentation/create_po_page.dart';
import 'package:mobile/features/notifications/presentation/notifications_page.dart';
import 'package:mobile/core/routing/app_shell.dart';
import 'package:mobile/features/settings/presentation/settings_page.dart';

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
                path: '/upload',
                name: 'upload',
                builder: (context, state) => const UploadPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inventory-hub',
                name: 'inventory-hub',
                builder: (context, state) => const InventoryHubPage(),
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
        path: '/review',
        name: 'review',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ReviewInvoiceDetailsPage(),
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
        path: '/notifications',
        name: 'notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsPage(),
      ),
    ],
  );
}
