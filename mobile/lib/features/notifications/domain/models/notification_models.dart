import 'dart:convert';

/// Types of in-app notifications
enum NotificationType {
  invoiceReady, // OCR complete, invoice ready for review
  lowStock, // Stock alert triggered
  poCreated, // Purchase order created
  syncComplete, // Offline queue synced
  general, // Generic push notification
}

/// A single in-app notification item, stored locally in Hive.
class NotificationItem {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime timestamp;
  bool isRead;
  final Map<String, dynamic>? data; // extra payload from Firebase

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.data,
  });

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
        id: id,
        title: title,
        body: body,
        type: type,
        timestamp: timestamp,
        isRead: isRead ?? this.isRead,
        data: data,
      );

  // ── Hive serialisation (JSON string stored as value) ──────────────────────

  String toHiveString() => jsonEncode({
        'id': id,
        'title': title,
        'body': body,
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
        'data': data,
      });

  factory NotificationItem.fromHiveString(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: _typeFromString(json['type'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
    );
  }

  /// Build from a Firebase RemoteMessage data map
  factory NotificationItem.fromFirebase({
    required String id,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) {
    final typeStr = data['type'] as String? ?? 'general';
    return NotificationItem(
      id: id,
      title: title,
      body: body,
      type: _typeFromString(typeStr),
      timestamp: DateTime.now(),
      isRead: false,
      data: data,
    );
  }

  static NotificationType _typeFromString(String s) {
    switch (s) {
      case 'invoiceReady':
        return NotificationType.invoiceReady;
      case 'lowStock':
        return NotificationType.lowStock;
      case 'poCreated':
        return NotificationType.poCreated;
      case 'syncComplete':
        return NotificationType.syncComplete;
      default:
        return NotificationType.general;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get typeLabel {
    switch (type) {
      case NotificationType.invoiceReady:
        return 'Invoice';
      case NotificationType.lowStock:
        return 'Stock Alert';
      case NotificationType.poCreated:
        return 'Purchase Order';
      case NotificationType.syncComplete:
        return 'Sync';
      default:
        return 'Info';
    }
  }

  String get routeName {
    switch (type) {
      case NotificationType.invoiceReady:
        return 'review';
      case NotificationType.lowStock:
        return 'current-stock';
      case NotificationType.poCreated:
        return 'purchase-orders';
      default:
        return 'dashboard';
    }
  }
}
