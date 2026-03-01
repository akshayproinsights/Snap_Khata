import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SyncState {
  final int pendingCount;
  final bool isSyncing;

  SyncState({required this.pendingCount, this.isSyncing = false});
}

class SyncNotifier extends StateNotifier<SyncState> {
  late final Box _box;

  SyncNotifier() : super(SyncState(pendingCount: 0)) {
    _init();
  }

  void _init() {
    _box = Hive.box('sync_queue');
    state = SyncState(pendingCount: _box.length);

    // Watch for changes in the Hive box
    _box.watch().listen((_) {
      state = SyncState(pendingCount: _box.length, isSyncing: state.isSyncing);
    });
  }

  void setSyncing(bool syncing) {
    state = SyncState(pendingCount: state.pendingCount, isSyncing: syncing);
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier();
});
