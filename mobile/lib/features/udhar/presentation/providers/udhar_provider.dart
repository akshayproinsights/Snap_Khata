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

  UdharState({this.isLoading = false, this.ledgers = const [], this.error});

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
    // Kick off the initial fetch. If there's already cached data (state has
    // ledgers from a previous build), isLoading stays false so the list
    // stays visible while refreshing in the background.
    Future.microtask(() => fetchLedgers());
    return UdharState(isLoading: true);
  }

  Future<void> fetchLedgers() async {
    // KEY: only show the loading spinner when the list is truly empty.
    // When there's already cached data, keep showing it while the network
    // call runs in the background. Zero blank-screen flashes.
    final hasCache = state.ledgers.isNotEmpty;
    if (!hasCache) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final response = await _dio.get('/api/udhar/ledgers');
      final data = response.data['data'] as List?;
      if (data != null) {
        final ledgers = data.map((e) => CustomerLedger.fromJson(e)).toList();
        state = state.copyWith(
          isLoading: false,
          ledgers: ledgers,
          clearError: true,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to parse ledgers',
        );
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
        state = state.copyWith(
          isLoading: false,
          ledgers: ledgers,
          clearError: true,
        );
      }
    } catch (e) {
      // Ignore errors for silent refresh
    }
  }

  Future<List<LedgerTransaction>> fetchTransactions(int ledgerId) async {
    try {
      final response = await _dio.get(
        '/api/udhar/ledgers/$ledgerId/transactions',
      );
      final data = response.data['data'] as List?;
      if (data != null) {
        return data.map((e) => LedgerTransaction.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetches transactions AND the backend-computed ledger summary
  /// (total_billed, total_paid, balance_due) in one call.
  /// Use this on PartyDetailPage to avoid double-counting paid amounts.
  Future<(List<LedgerTransaction>, Map<String, double>)>
  fetchLedgerWithTransactions(int ledgerId) async {
    final emptySummary = <String, double>{
      'total_billed': 0,
      'total_paid': 0,
      'balance_due': 0,
    };
    try {
      final response = await _dio.get(
        '/api/udhar/ledgers/$ledgerId/transactions',
      );
      final data = response.data['data'] as List?;
      final ledgerData = response.data['ledger'] as Map<String, dynamic>?;

      final transactions = data != null
          ? data.map((e) => LedgerTransaction.fromJson(e)).toList()
          : <LedgerTransaction>[];

      final summary = <String, double>{
        'total_billed':
            double.tryParse(ledgerData?['total_billed']?.toString() ?? '0') ??
            0.0,
        'total_paid':
            double.tryParse(ledgerData?['total_paid']?.toString() ?? '0') ??
            0.0,
        'balance_due':
            double.tryParse(ledgerData?['balance_due']?.toString() ?? '0') ??
            0.0,
      };
      return (transactions, summary);
    } catch (e) {
      return (<LedgerTransaction>[], emptySummary);
    }
  }

  Future<bool> recordPayment(int ledgerId, double amount, String notes) async {
    // Optimistic update — immediately reduce the displayed balance so the
    // user sees the change before the network round-trip completes.
    final prevLedgers = state.ledgers;
    state = state.copyWith(
      ledgers: state.ledgers.map((l) {
        if (l.id != ledgerId) return l;
        return l.copyWith(
          balanceDue: (l.balanceDue - amount).clamp(0, double.infinity),
        );
      }).toList(),
    );
    try {
      await _dio.post(
        '/api/udhar/ledgers/$ledgerId/pay',
        data: {'amount': amount, 'notes': notes},
      );
      ref.invalidate(verifiedProvider);
      unawaited(ref.read(dashboardTotalsProvider.notifier).refreshSilent());
      // Silent re-fetch to get authoritative server data.
      unawaited(fetchLedgersSilent());
      return true;
    } catch (e) {
      // Roll back optimistic change on failure.
      state = state.copyWith(ledgers: prevLedgers);
      return false;
    }
  }

  Future<bool> updateCustomerPhone(int ledgerId, String phone) async {
    // Optimistic update
    final prevLedgers = state.ledgers;
    state = state.copyWith(
      ledgers: state.ledgers.map((l) {
        if (l.id != ledgerId) return l;
        return l.copyWith(customerPhone: phone);
      }).toList(),
    );
    try {
      await _dio.put(
        '/api/udhar/ledgers/$ledgerId/phone',
        data: {'phone': phone},
      );
      return true;
    } catch (e) {
      // Roll back on failure
      state = state.copyWith(ledgers: prevLedgers);
      return false;
    }
  }

  Future<bool> deleteLedger(int ledgerId) async {
    // Optimistic removal — remove from UI immediately so the party
    // disappears the instant the user confirms, without waiting for re-fetch.
    final previousLedgers = state.ledgers;
    state = state.copyWith(
      ledgers: state.ledgers.where((l) => l.id != ledgerId).toList(),
    );
    try {
      await _dio.delete('/api/udhar/ledgers/$ledgerId');
      ref.invalidate(verifiedProvider);
      // Refresh dashboard totals in background — don't block UI.
      unawaited(ref.read(dashboardTotalsProvider.notifier).refresh());
      // Silent re-fetch to sync any server-side changes (new balance, etc.)
      unawaited(fetchLedgersSilent());
      return true;
    } catch (e) {
      // Roll back optimistic removal on failure.
      state = state.copyWith(ledgers: previousLedgers);
      return false;
    }
  }

  Future<bool> toggleTransactionPaidStatus(
    int ledgerId,
    int transactionId,
    bool isPaid,
  ) async {
    try {
      await _dio.post(
        '/api/udhar/ledgers/$ledgerId/transactions/$transactionId/toggle-paid',
        data: {'is_paid': isPaid},
      );
      ref.invalidate(verifiedProvider);
      unawaited(ref.read(dashboardTotalsProvider.notifier).refreshSilent());
      // Silent refresh so UI doesn't flicker during the re-fetch.
      unawaited(fetchLedgersSilent());
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteTransaction(int transactionId) async {
    try {
      await _dio.delete('/api/udhar/transactions/$transactionId');
      ref.invalidate(verifiedProvider);
      unawaited(ref.read(dashboardTotalsProvider.notifier).refreshSilent());
      unawaited(fetchLedgersSilent());
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<OrderLineItem>> fetchOrderItems(String receiptNumber) async {
    try {
      final response = await _dio.get(
        '/api/invoices/receipt/$receiptNumber/items',
      );
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

final udharProvider = NotifierProvider<UdharNotifier, UdharState>(
  UdharNotifier.new,
);
