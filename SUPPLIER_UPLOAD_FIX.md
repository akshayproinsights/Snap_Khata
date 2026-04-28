# Supplier Upload Flow Fix - Complete Analysis

## Problem Summary
When users upload supplier purchase bills via "Scan Bill → Supplier", the images are being saved to the **Customer (Receipts)** section instead of the **Inventory (Supplier Purchases)** section.

### Root Cause
The files are being uploaded to the `sales/` folder (R2) instead of the `inventory/` folder, and processed by the sales processor (`process_invoices_batch`) which saves to the `invoices` table instead of the `inventory_items` table.

### Evidence from Logs
```
Uploaded to R2: snapkhata-prod/akshaykh/sales/20260428_124227_4635bc_.jpg
file_keys: ['akshaykh/sales/20260428_124227_81fd8b_.jpg', 'akshaykh/sales/20260428_124227_4635bc_.jpg']
```

## Architecture Analysis

### Two Separate Upload Flows (Correctly Designed)

#### Sales Flow (✓ Working correctly)
- **Frontend**: `/sales/upload` → `UploadPage.tsx`  
- **Mobile**: 'upload' route → `UploadPage.dart`
- **API Endpoint**: `POST /api/upload/files` → `POST /api/upload/process-files`
- **Backend Processor**: `process_invoices_batch()` (services/processor.py)
- **Storage Folder**: `get_sales_folder()` = `akshaykh/sales/`
- **Database Table**: `invoices` (customer receipts)
- **Review Page**: Review Center → Customer section

#### Inventory Flow (❌ Issue Here)
- **Frontend**: `/inventory/upload` → `InventoryUploadPage.tsx`
- **Mobile**: 'inventory-upload' route → `InventoryUploadPage.dart`
- **API Endpoint**: `POST /api/inventory/upload` → `POST /api/inventory/process`
- **Backend Processor**: `process_inventory_batch()` (services/inventory_processor.py)
- **Storage Folder**: `get_purchases_folder()` = `akshaykh/inventory/`
- **Database Table**: `inventory_items` (supplier purchases)
- **Review Page**: Review Center → Inventory section → Supplier Purchases

## Likely Causes

### Issue #1: Mobile Bill Selection Sheet
**File**: `mobile/lib/features/dashboard/presentation/widgets/bill_type_selection_sheet.dart`

**Code** (Line 152):
```dart
final result = selectedType == BillScanType.customer
    ? await router.pushNamed('upload')
    : await router.push('/inventory-upload');
```

**Problem**: Inconsistent navigation - customer uses `pushNamed()` while supplier uses `push()` (direct path)

### Issue #2: Possible Upload Page Confusion
Users may be clicking on a "Scan Bill" quick action that defaults to the sales upload page instead of showing the bill type selection sheet first.

## Recommended Fixes

### Fix #1: Ensure Bill Type Selection Sheet Always Shows
The bill type selection should always appear before upload when clicking "Scan Bill"

### Fix #2: Standardize Mobile Navigation
Use consistent `pushNamed()` for both routes

### Fix #3: Verify Frontend Routing
Ensure frontend doesn't have a default redirect to sales upload

### Fix #4: Add Server-Side Type Detection
Backend should detect upload type from file folder path and save accordingly
