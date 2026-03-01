import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/purchase_orders/domain/models/purchase_order_models.dart';

class PurchaseOrderRepository {
  final Dio _dio;
  static const _draftCacheKey = 'po_draft';
  static const _historyCacheKey = 'po_history';

  PurchaseOrderRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  Box get _cache => Hive.box('dashboard_cache');

  // ─── Draft Management ─────────────────────────────────────────────────────

  Future<DraftPoSummary> getDraftItems() async {
    try {
      final response = await _dio.get('/api/purchase-orders/draft/items');
      _cache.put(_draftCacheKey, response.data);
      return DraftPoSummary.fromJson(
          Map<String, dynamic>.from(response.data as Map));
    } catch (e) {
      final cached = _cache.get(_draftCacheKey);
      if (cached != null) {
        return DraftPoSummary.fromJson(
            Map<String, dynamic>.from(cached as Map));
      }
      return DraftPoSummary.empty();
    }
  }

  Future<bool> addDraftItem(DraftPoItem item) async {
    try {
      await _dio.post('/api/purchase-orders/draft/items', data: item.toJson());
      return true;
    } catch (e) {
      debugPrint('addDraftItem error: $e');
      return false;
    }
  }

  Future<bool> updateDraftQty(String partNumber, int qty) async {
    try {
      await _dio.put(
        '/api/purchase-orders/draft/items/${Uri.encodeComponent(partNumber)}/quantity',
        data: {'reorder_qty': qty},
      );
      return true;
    } catch (e) {
      debugPrint('updateDraftQty error: $e');
      return false;
    }
  }

  Future<bool> removeDraftItem(String partNumber) async {
    try {
      await _dio.delete(
          '/api/purchase-orders/draft/items/${Uri.encodeComponent(partNumber)}');
      return true;
    } catch (e) {
      debugPrint('removeDraftItem error: $e');
      return false;
    }
  }

  Future<bool> clearDraft() async {
    try {
      await _dio.delete('/api/purchase-orders/draft/clear');
      return true;
    } catch (e) {
      debugPrint('clearDraft error: $e');
      return false;
    }
  }

  /// Proceed to PO — backend generates a PDF and creates a PO record.
  /// Returns the PO number on success, null on failure.
  Future<String?> proceedToPO(ProceedToPORequest request) async {
    try {
      final response = await _dio.post(
        '/api/purchase-orders/draft/proceed',
        data: request.toJson(),
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      // PO number is returned in the response header by the backend
      final poNumber = response.headers.value('x-po-number') ?? 'PO Generated';
      return poNumber;
    } catch (e) {
      debugPrint('proceedToPO error: $e');
      return null;
    }
  }

  // ─── History ──────────────────────────────────────────────────────────────

  Future<List<PurchaseOrder>> getPOHistory({int limit = 50}) async {
    try {
      final response = await _dio.get('/api/purchase-orders/history',
          queryParameters: {'limit': limit});
      final raw = (response.data['purchase_orders'] as List?) ?? [];
      _cache.put(_historyCacheKey, raw);
      return raw
          .map((j) =>
              PurchaseOrder.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
    } catch (e) {
      final cached = _cache.get(_historyCacheKey);
      if (cached != null) {
        return (cached as List)
            .map((j) =>
                PurchaseOrder.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
      }
      return [];
    }
  }

  // ─── Suppliers ────────────────────────────────────────────────────────────

  Future<List<String>> getSuppliers() async {
    try {
      final response = await _dio.get('/api/purchase-orders/suppliers');
      return List<String>.from((response.data['suppliers'] as List?) ?? []);
    } catch (e) {
      return [];
    }
  }

  // ─── Quick Add ────────────────────────────────────────────────────────────

  Future<bool> quickAddToDraft(String partNumber) async {
    try {
      await _dio.post(
          '/api/purchase-orders/quick-add/${Uri.encodeComponent(partNumber)}');
      return true;
    } catch (e) {
      debugPrint('quickAddToDraft error: $e');
      return false;
    }
  }
  // ─── Details & Deletion ───────────────────────────────────────────────────

  Future<PurchaseOrderDetail?> getPurchaseOrderDetails(String poId) async {
    try {
      final response = await _dio.get('/api/purchase-orders/$poId');
      if (response.data['success'] == true) {
        return PurchaseOrderDetail.fromJson(
            Map<String, dynamic>.from(response.data as Map));
      }
      return null;
    } catch (e) {
      debugPrint('getPurchaseOrderDetails error: $e');
      return null;
    }
  }

  Future<bool> deletePurchaseOrder(String poId) async {
    try {
      final response = await _dio.delete('/api/purchase-orders/$poId');
      return response.data['success'] == true;
    } catch (e) {
      debugPrint('deletePurchaseOrder error: $e');
      return false;
    }
  }

  // ─── PDF Generation ────────────────────────────────────────────────────────

  Future<Uint8List?> getPdf(String poId) async {
    try {
      final response = await _dio.get(
        '/api/purchase-orders/$poId/pdf',
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      return response.data as Uint8List;
    } catch (e) {
      debugPrint('getPdf error: $e');
      return null;
    }
  }
}
