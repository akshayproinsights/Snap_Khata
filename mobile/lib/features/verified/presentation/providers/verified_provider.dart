import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/verified/data/verified_repository.dart';
import 'package:mobile/features/verified/domain/models/verified_models.dart';

final verifiedRepositoryProvider =
    Provider<VerifiedRepository>((ref) => VerifiedRepository());

class VerifiedState {
  final List<VerifiedInvoice> records;
  final bool isLoading;
  final String? error;

  VerifiedState({
    this.records = const [],
    this.isLoading = false,
    this.error,
  });

  VerifiedState copyWith({
    List<VerifiedInvoice>? records,
    bool? isLoading,
    String? error,
  }) {
    return VerifiedState(
      records: records ?? this.records,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class VerifiedNotifier extends Notifier<VerifiedState> {
  late final VerifiedRepository _repository;

  @override
  VerifiedState build() {
    _repository = ref.watch(verifiedRepositoryProvider);
    return VerifiedState();
  }

  Future<void> fetchRecords({
    String? search,
    String? dateFrom,
    String? dateTo,
    String? receiptNumber,
    String? vehicleNumber,
    String? customerName,
    String? description,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final records = await _repository.getVerifiedInvoices(
        search: search,
        dateFrom: dateFrom,
        dateTo: dateTo,
        receiptNumber: receiptNumber,
        vehicleNumber: vehicleNumber,
        customerName: customerName,
        description: description,
      );
      state = state.copyWith(
        records: records,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateRecord(VerifiedInvoice record) async {
    try {
      // Optimistic update
      final newRecords = state.records.map((r) {
        if (r.rowId == record.rowId) {
          return record;
        }
        return r;
      }).toList();
      state = state.copyWith(records: newRecords);

      await _repository.updateVerifiedInvoice(record);
    } catch (e) {
      state = state.copyWith(error: 'Failed to update record: $e');
      await fetchRecords(); // Revert
    }
  }

  Future<void> deleteBulk(List<String> ids) async {
    try {
      // Optimistic update
      final newRecords =
          state.records.where((r) => !ids.contains(r.rowId)).toList();
      state = state.copyWith(records: newRecords);

      await _repository.deleteBulk(ids);
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete records: $e');
      await fetchRecords(); // Revert
    }
  }
}

final verifiedProvider =
    NotifierProvider<VerifiedNotifier, VerifiedState>(VerifiedNotifier.new);
