import 'dart:math';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobile/features/notifications/domain/models/notification_models.dart';

/// Simple UUID v4 generator (avoids adding the uuid package as a dependency)
String _newUuid() {
  final rand = Random.secure();
  final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}'
      '-${hex(bytes[4])}${hex(bytes[5])}'
      '-${hex(bytes[6])}${hex(bytes[7])}'
      '-${hex(bytes[8])}${hex(bytes[9])}'
      '-${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
}

/// Stores and retrieves notification items from a local Hive box.
/// Keys are notification IDs; values are JSON strings.
class NotificationRepository {
  static const _boxName = 'notifications';
  static const _maxStored = 100; // keep last 100 notifications

  Box get _box => Hive.box(_boxName);

  // ── Read ──────────────────────────────────────────────────────────────────

  List<NotificationItem> getAll() {
    final items = <NotificationItem>[];
    for (final key in _box.keys) {
      try {
        final raw = _box.get(key) as String?;
        if (raw != null) items.add(NotificationItem.fromHiveString(raw));
      } catch (_) {} // skip corrupted entries
    }
    // Newest first
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  int getUnreadCount() => getAll().where((n) => !n.isRead).length;

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<void> add(NotificationItem item) async {
    await _box.put(item.id, item.toHiveString());
    _trimIfNeeded();
  }

  /// Convenience: add a notification from raw Firebase payload
  Future<NotificationItem> addFromFirebase({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    final item = NotificationItem.fromFirebase(
      id: _newUuid(),
      title: title,
      body: body,
      data: data,
    );
    await add(item);
    return item;
  }

  /// Convenience: add a local system notification (e.g. sync complete)
  Future<void> addLocal({
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) async {
    final item = NotificationItem(
      id: _newUuid(),
      title: title,
      body: body,
      type: type,
      timestamp: DateTime.now(),
      data: data,
    );
    await add(item);
  }

  Future<void> markRead(String id) async {
    final raw = _box.get(id) as String?;
    if (raw == null) return;
    final item = NotificationItem.fromHiveString(raw);
    await _box.put(id, item.copyWith(isRead: true).toHiveString());
  }

  Future<void> markAllRead() async {
    for (final key in _box.keys) {
      final raw = _box.get(key) as String?;
      if (raw == null) continue;
      try {
        final item = NotificationItem.fromHiveString(raw);
        if (!item.isRead) {
          await _box.put(key, item.copyWith(isRead: true).toHiveString());
        }
      } catch (_) {}
    }
  }

  Future<void> dismiss(String id) async {
    await _box.delete(id);
  }

  Future<void> clearAll() async {
    await _box.clear();
  }

  void _trimIfNeeded() {
    final items = getAll(); // already sorted newest first
    if (items.length > _maxStored) {
      final toDelete = items.sublist(_maxStored);
      for (final item in toDelete) {
        _box.delete(item.id);
      }
    }
  }
}
