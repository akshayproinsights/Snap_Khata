import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:mobile/features/udhar/domain/models/udhar_models.dart';

class ItemCatalogueState {
  final bool isLoading;
  final List<CatalogueItem> items;
  final String? error;

  ItemCatalogueState({this.isLoading = false, this.items = const [], this.error});

  ItemCatalogueState copyWith({
    bool? isLoading,
    List<CatalogueItem>? items,
    String? error,
    bool clearError = false,
  }) {
    return ItemCatalogueState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ItemCatalogueNotifier extends Notifier<ItemCatalogueState> {
  late final Dio _dio;

  @override
  ItemCatalogueState build() {
    _dio = ApiClient().dio;
    Future.microtask(() => fetchCatalogue());
    return ItemCatalogueState(isLoading: true);
  }

  Future<void> fetchCatalogue() async {
    final hasCache = state.items.isNotEmpty;
    if (!hasCache) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final response = await _dio.get('/api/items/catalogue');
      final data = response.data as List?;
      if (data != null) {
        final items = data.map((e) => CatalogueItem.fromJson(e)).toList();
        state = state.copyWith(
          isLoading: false,
          items: items,
          clearError: true,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to parse catalogue items',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> addItem(String name, double price, String unit) async {
    try {
      final response = await _dio.post(
        '/api/items/catalogue',
        data: {
          'item_name': name,
          'last_price': price,
          'unit': unit,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchCatalogue();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateItem(int itemId, String name, double price, String unit) async {
    try {
      final response = await _dio.put(
        '/api/items/catalogue/$itemId',
        data: {
          'item_name': name,
          'last_price': price,
          'unit': unit,
        },
      );
      if (response.statusCode == 200) {
        await fetchCatalogue();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteItem(int itemId) async {
    try {
      final response = await _dio.delete('/api/items/catalogue/$itemId');
      if (response.statusCode == 200) {
        state = state.copyWith(
          items: state.items.where((i) => i.id != itemId).toList(),
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> syncFromBills() async {
    try {
      final response = await _dio.post('/api/items/catalogue/sync');
      if (response.statusCode == 200) {
        await fetchCatalogue();
        return {
          'success': true,
          'synced_count': response.data['synced_count'] ?? 0,
          'message': response.data['message'] ?? 'Successfully synced items',
        };
      }
      return {'success': false, 'message': 'Sync failed'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

final itemCatalogueProvider = NotifierProvider<ItemCatalogueNotifier, ItemCatalogueState>(() {
  return ItemCatalogueNotifier();
});
