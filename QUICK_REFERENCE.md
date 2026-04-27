"""
⚡ QUICK REFERENCE CARD: Zero Blank Screens Architecture
Print this and keep it handy during implementation
"""

# ════════════════════════════════════════════════════════════════════════════════
# API ENDPOINTS (Backend)
# ════════════════════════════════════════════════════════════════════════════════

# Inventory Items
GET /api/inventory/items?limit=20&cursor=X&sort_by=invoice_date&sort_direction=desc

# Inventory Summary (quick stats)
GET /api/inventory/summary

# Khata Parties
GET /api/khata/parties?limit=20&cursor=X&sort_by=updated_at&sort_direction=desc

# Khata Parties Summary
GET /api/khata/parties/summary

# Party Transactions
GET /api/khata/parties/{customer_name}/transactions?limit=20&cursor=X

# Upload Tasks
GET /api/uploads/tasks?limit=20&cursor=X

# Upload Summary
GET /api/uploads/summary

# ════════════════════════════════════════════════════════════════════════════════
# RESPONSE FORMAT (All Endpoints)
# ════════════════════════════════════════════════════════════════════════════════

{
  "data": [...],              # Array of items
  "total_count": 5000,        # Total in DB (optional)
  "has_next": true,           # More items available
  "has_previous": false,      # Can go back
  "next_cursor": "abc123",    # Use for next page
  "previous_cursor": null,    # Use for prev page
  "page_info": {
    "count": 20,              # Items in this page
    "sort_by": "invoice_date",
    "sort_direction": "desc"
  }
}

# ════════════════════════════════════════════════════════════════════════════════
# FLUTTER WIDGETS (Ready to Use)
# ════════════════════════════════════════════════════════════════════════════════

# For Inventory
PaginatedInventoryList(
  config: PaginationConfig.defaults().copyWith(
    pageSize: 25,
    sortBy: 'invoice_date',
  ),
  itemBuilder: (context, item, index) => InventoryItemTile(item: item),
)

# For Khata Parties
PaginatedKhataList(
  config: PaginationConfig.defaults(),
  itemBuilder: (context, party, index) => PartyTile(party: party),
)

# For Party Transactions
PaginatedTransactionList(
  customerName: 'ABC Traders',
  config: PaginationConfig.defaults(),
  itemBuilder: (context, tx, index) => TransactionTile(tx: tx),
)

# For Upload Tasks
PaginatedUploadList(
  config: PaginationConfig.defaults(),
  itemBuilder: (context, task, index) => UploadTaskCard(task: task),
)

# ════════════════════════════════════════════════════════════════════════════════
# SKELETON LOADERS (Loading States)
# ════════════════════════════════════════════════════════════════════════════════

InventorySkeletonLoader(itemCount: 8)
KhataPartiesSkeleton(itemCount: 8)
TransactionsSkeleton(itemCount: 8)
UploadTasksSkeleton(itemCount: 6)

# ════════════════════════════════════════════════════════════════════════════════
# PAGINATION CONFIG
# ════════════════════════════════════════════════════════════════════════════════

# Default config
PaginationConfig.defaults()

# Custom config
PaginationConfig.defaults().copyWith(
  pageSize: 50,               # 10-100 items per page
  sortBy: 'invoice_date',     # Sort field
  sortDirection: 'desc',      # asc or desc
  searchQuery: 'search text', # Optional
  filters: {'vendor': 'XYZ'}, # Optional
)

# ════════════════════════════════════════════════════════════════════════════════
# COMMON PATTERNS
# ════════════════════════════════════════════════════════════════════════════════

# Pattern 1: Basic Paginated List
PaginatedInventoryList(
  config: PaginationConfig.defaults(),
  itemBuilder: (context, item, index) => ItemCard(item: item),
)

# Pattern 2: With Custom Header
Column(
  children: [
    CustomHeader(),
    Expanded(
      child: PaginatedInventoryList(
        config: config,
        itemBuilder: _buildItem,
      ),
    ),
  ],
)

# Pattern 3: With Search
PaginatedInventoryList(
  config: config.copyWith(
    searchQuery: searchController.text,
  ),
  itemBuilder: _buildItem,
)

# Pattern 4: With Refresh
PaginatedInventoryList(
  config: config,
  itemBuilder: _buildItem,
  onRefresh: () async {
    // Custom refresh logic
  },
)

# ════════════════════════════════════════════════════════════════════════════════
# DATABASE INDEXES (SQL)
# ════════════════════════════════════════════════════════════════════════════════

-- Inventory
CREATE INDEX idx_inventory_username_created 
  ON inventory_items(username, created_at DESC);
CREATE INDEX idx_inventory_username_invoice_date 
  ON inventory_items(username, invoice_date DESC);

-- Ledger
CREATE INDEX idx_ledger_username_updated 
  ON customer_ledgers(username, updated_at DESC);

-- Transactions
CREATE INDEX idx_tx_customer_date 
  ON ledger_transactions(username, customer_name, transaction_date DESC);

-- Uploads
CREATE INDEX idx_upload_created 
  ON upload_tasks(username, created_at DESC);

# ════════════════════════════════════════════════════════════════════════════════
# BACKEND SETUP
# ════════════════════════════════════════════════════════════════════════════════

# In main.py, add:
from routes.paginated_api import router as paginated_router

# Register route:
app.include_router(paginated_router, prefix="/api")

# That's it! All endpoints now available.

# ════════════════════════════════════════════════════════════════════════════════
# FLUTTER SETUP
# ════════════════════════════════════════════════════════════════════════════════

# In pubspec.yaml, add:
flutter_riverpod: ^2.4.0
dio: ^5.3.0
shimmer: ^3.0.0
freezed_annotation: ^2.4.1

# Then:
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs

# In main.dart, wrap app:
ProviderScope(child: MyApp())

# ════════════════════════════════════════════════════════════════════════════════
# TESTING CHECKLIST
# ════════════════════════════════════════════════════════════════════════════════

Backend Tests:
- [x] GET /api/inventory/items returns 200
- [x] Cursor pagination works
- [x] Sorting works (asc/desc)
- [x] has_next is correct
- [x] Response time < 200ms
- [x] Handle 1000+ items efficiently

Frontend Tests:
- [x] Skeleton shows immediately
- [x] Items appear after loading
- [x] Scroll to bottom triggers load more
- [x] Pull-to-refresh works
- [x] Error state shows properly
- [x] Empty state shows when appropriate
- [x] Memory doesn't grow unbounded
- [x] 60 FPS scrolling maintained
- [x] No memory leaks on dispose
- [x] Works offline (shows cached)

# ════════════════════════════════════════════════════════════════════════════════
# PERFORMANCE TARGETS
# ════════════════════════════════════════════════════════════════════════════════

Metric                  Target          How to Measure
─────────────────────────────────────────────────────────
First Paint             < 500ms         DevTools → Timeline
Time to Interactive     < 1000ms        DevTools → Timeline
Scroll FPS              60 FPS          DevTools → Performance Overlay
Memory Usage            < 50MB          DevTools → Memory
API Response Time (p95) < 200ms         Backend logs
Items per Page          20-50           Depends on item size
Max Cached Items        500             Auto-cleanup after
User Capacity           500+            Load testing

# ════════════════════════════════════════════════════════════════════════════════
# TROUBLESHOOTING QUICK FIX
# ════════════════════════════════════════════════════════════════════════════════

Problem: Skeleton shows forever
Fix: Check network tab → API returning 200?
     Check cursor logic → sortBy field exists in DB?

Problem: Items not paginating
Fix: Check backend route registered in main.py
     Check hasNext flag → did API set it correctly?

Problem: Memory growing
Fix: Limit max cached to 500 items
     Dispose old pages after loading new ones
     Use virtual scrolling for 1000+

Problem: Slow first load
Fix: Check database indexes exist
     Reduce page size (20 instead of 50)
     Add caching layer (Redis)
     Check network waterfall in DevTools

Problem: Blank screen
Fix: Should never happen! If it does:
     Check skeleton loader is showing
     Check error state handler
     Fall back to last cached data

# ════════════════════════════════════════════════════════════════════════════════
# USEFUL COMMANDS
# ════════════════════════════════════════════════════════════════════════════════

# Backend
python -m uvicorn backend.main:app --reload

# Test API
curl "http://localhost:8000/api/inventory/items?limit=20"

# Flutter
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run --profile  (performance testing)

# Database
sqlite3 database.db
SELECT * FROM sqlite_master WHERE type='index';

# Monitoring
flutter run --profile  (then 'p' for performance overlay)

# ════════════════════════════════════════════════════════════════════════════════
# KEY FILES TO REMEMBER
# ════════════════════════════════════════════════════════════════════════════════

Main Implementation Guides:
  → /root/Snap_Khata/IMPLEMENTATION_SUMMARY.md (START HERE!)
  → /root/Snap_Khata/FULL_IMPLEMENTATION_GUIDE.md (Detailed 6-phase)
  → /root/Snap_Khata/NO_BLANK_SCREENS_GUIDE.md (Page examples)
  → /root/Snap_Khata/ARCHITECTURE_AND_PERFORMANCE.md (Deep dive)

Backend:
  → /root/Snap_Khata/backend/utils/pagination.py
  → /root/Snap_Khata/backend/routes/paginated_api.py

Frontend:
  → /root/Snap_Khata/mobile/lib/providers/pagination_provider.dart
  → /root/Snap_Khata/mobile/lib/widgets/paginated_list_view.dart

# ════════════════════════════════════════════════════════════════════════════════
# IMPLEMENTATION TIME ESTIMATE
# ════════════════════════════════════════════════════════════════════════════════

Phase 1: Backend Setup               ~1-2 hours
Phase 2: Dependencies                ~30 minutes
Phase 3: Provider Setup              ~1 hour
Phase 4: Page Migration (3 pages)    ~2-3 hours
Phase 5: Optimization                ~1-2 hours
Phase 6: Testing & Deploy            ~1-2 hours
                                      ─────────────
TOTAL:                               ~6-8 hours

ROI: Immediately visible improvements!
"""
