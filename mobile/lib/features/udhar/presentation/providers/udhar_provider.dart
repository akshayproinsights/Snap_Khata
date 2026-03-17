import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:dio/dio.dart';
import '../../domain/models/udhar_models.dart';

class UdharState {
  final bool isLoading;
  final List<CustomerLedger> ledgers;
  final String? error;

  UdharState({
    this.isLoading = false,
    this.ledgers = const [],
    this.error,
  });

  UdharState copyWith({
    bool? isLoading,
    List<CustomerLedger>? ledgers,
    String? error,
    bool clearError = false,
  }) {
    return UdharState(
      isLoading: isLoading ?? this.isLoading,
      ledgers: ledgers ?? this.ledgers,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class UdharNotifier extends Notifier<UdharState> {
  late final Dio _dio;

  @override
  UdharState build() {
    _dio = ApiClient().dio;
    Future.microtask(() => fetchLedgers());
    return UdharState();
  }

  Future<void> fetchLedgers() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _dio.get('/api/udhar/ledgers');
      final data = response.data['data'] as List?;
      if (data != null) {
        final ledgers = data.map((e) => CustomerLedger.fromJson(e)).toList();
        state = state.copyWith(isLoading: false, ledgers: ledgers);
      } else {
        state = state.copyWith(
            isLoading: false, error: 'Failed to parse ledgers');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<List<LedgerTransaction>> fetchTransactions(int ledgerId) async {
    try {
      final response = await _dio.get('/api/udhar/ledgers/$ledgerId/transactions');
      final data = response.data['data'] as List?;
      if (data != null) {
        return data.map((e) => LedgerTransaction.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> recordPayment(int ledgerId, double amount, String notes) async {
    try {
      await _dio.post('/api/udhar/ledgers/$ledgerId/pay', data: {
        'amount': amount,
        'notes': notes,
      });
      // Refresh list after successful payment
      await fetchLedgers();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<OrderLineItem>> fetchOrderItems(String receiptNumber) async {
    try {
      final response = await _dio.get('/api/invoices/receipt/$receiptNumber/items');
      final data = response.data['items'] as List?;
      if (data != null) {
        return data.map((e) => OrderLineItem.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

final udharProvider =
    NotifierProvider<UdharNotifier, UdharState>(UdharNotifier.new);
