import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:dio/dio.dart';
import '../../domain/models/vendor_ledger_models.dart';

class VendorLedgerState {
  final bool isLoading;
  final List<VendorLedger> ledgers;
  final String? error;

  VendorLedgerState({
    this.isLoading = false,
    this.ledgers = const [],
    this.error,
  });

  VendorLedgerState copyWith({
    bool? isLoading,
    List<VendorLedger>? ledgers,
    String? error,
    bool clearError = false,
  }) {
    return VendorLedgerState(
      isLoading: isLoading ?? this.isLoading,
      ledgers: ledgers ?? this.ledgers,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class VendorLedgerNotifier extends Notifier<VendorLedgerState> {
  late final Dio _dio;

  @override
  VendorLedgerState build() {
    _dio = ApiClient().dio;
    Future.microtask(() => fetchLedgers());
    return VendorLedgerState();
  }

  Future<void> fetchLedgers() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _dio.get('/api/vendor-ledgers/vendor-ledgers');
      final data = response.data['data'] as List?;
      if (data != null) {
        final ledgers = data.map((e) => VendorLedger.fromJson(e)).toList();
        state = state.copyWith(isLoading: false, ledgers: ledgers);
      } else {
        state = state.copyWith(
            isLoading: false, error: 'Failed to parse vendor ledgers');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<List<VendorLedgerTransaction>> fetchTransactions(int ledgerId) async {
    try {
      final response = await _dio.get('/api/vendor-ledgers/vendor-ledgers/$ledgerId/transactions');
      final data = response.data['data'] as List?;
      if (data != null) {
        return data.map((e) => VendorLedgerTransaction.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> recordPayment(int ledgerId, double amount, String notes) async {
    try {
      await _dio.post('/api/vendor-ledgers/vendor-ledgers/$ledgerId/pay', data: {
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

  Future<bool> toggleTransactionPaidStatus(int transactionId, bool markAsPaid) async {
    try {
      await _dio.post('/api/vendor-ledgers/vendor-ledgers/transactions/$transactionId/toggle-paid', data: {
        'is_paid': markAsPaid,
      });
      // Refresh list after successful toggle
      await fetchLedgers();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteLedger(int ledgerId) async {
    try {
      await _dio.delete('/api/vendor-ledgers/vendor-ledgers/$ledgerId');
      await fetchLedgers();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final vendorLedgerProvider =
    NotifierProvider<VendorLedgerNotifier, VendorLedgerState>(VendorLedgerNotifier.new);
