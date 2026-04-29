import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:mobile/features/udhar/domain/models/udhar_models.dart';
import 'package:mobile/features/verified/presentation/providers/verified_provider.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_providers.dart';

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
    // Start as loading=true so the spinner shows immediately on first render
    // instead of briefly flashing "No parties found" before microtask fires.
    return UdharState(isLoading: true);
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

  Future<void> fetchLedgersSilent() async {
    try {
      final response = await _dio.get('/api/udhar/ledgers');
      final data = response.data['data'] as List?;
      if (data != null) {
        final ledgers = data.map((e) => CustomerLedger.fromJson(e)).toList();
        state = state.copyWith(isLoading: false, ledgers: ledgers, clearError: true);
      }
    } catch (e) {
      // Ignore errors for silent refresh
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
      // Eagerly re-fetch dashboard totals (don't just invalidate — that's lazy)
      ref.invalidate(verifiedProvider);
      unawaited(ref.read(dashboardTotalsProvider.notifier).refresh());
      await fetchLedgers();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteLedger(int ledgerId) async {
    try {
      await _dio.delete('/api/udhar/ledgers/$ledgerId');
      ref.invalidate(verifiedProvider);
      unawaited(ref.read(dashboardTotalsProvider.notifier).refresh());
      await fetchLedgers();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> toggleTransactionPaidStatus(int ledgerId, int transactionId, bool isPaid) async {
    try {
      await _dio.post(
        '/api/udhar/ledgers/$ledgerId/transactions/$transactionId/toggle-paid',
        data: {'is_paid': isPaid},
      );
      ref.invalidate(verifiedProvider);
      unawaited(ref.read(dashboardTotalsProvider.notifier).refresh());
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
