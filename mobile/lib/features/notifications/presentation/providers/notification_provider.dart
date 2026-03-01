import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/notifications/data/notification_repository.dart';
import 'package:mobile/features/notifications/domain/models/notification_models.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

class NotificationState {
  final List<NotificationItem> items;
  final int unreadCount;

  NotificationState({required this.items, required this.unreadCount});

  factory NotificationState.empty() =>
      NotificationState(items: [], unreadCount: 0);

  NotificationState copyWith(
      {List<NotificationItem>? items, int? unreadCount}) {
    return NotificationState(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationRepository _repo;

  NotificationNotifier(this._repo) : super(NotificationState.empty()) {
    _reload();
  }

  void _reload() {
    final items = _repo.getAll();
    state = NotificationState(
      items: items,
      unreadCount: items.where((n) => !n.isRead).length,
    );
  }

  /// Called by NotificationService on new Firebase message
  Future<void> addFromFirebase({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    await _repo.addFromFirebase(title: title, body: body, data: data);
    _reload();
  }

  /// Add a local system-generated notification
  Future<void> addLocal({
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) async {
    await _repo.addLocal(title: title, body: body, type: type, data: data);
    _reload();
  }

  Future<void> markRead(String id) async {
    await _repo.markRead(id);
    _reload();
  }

  Future<void> markAllRead() async {
    await _repo.markAllRead();
    _reload();
  }

  Future<void> dismiss(String id) async {
    await _repo.dismiss(id);
    _reload();
  }

  Future<void> clearAll() async {
    await _repo.clearAll();
    _reload();
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return NotificationNotifier(repo);
});

/// Simple count-only provider used by bell badge — avoids rebuilding entire page
final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationProvider).unreadCount;
});
