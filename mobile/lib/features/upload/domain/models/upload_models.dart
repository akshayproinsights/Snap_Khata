/// Per-file upload lifecycle status
enum UploadFileStatus { idle, uploading, processing, done, failed, duplicate }

/// Represents a single upload task for pagination
class UploadTask {
  final String taskId;
  final String status; // 'processing', 'completed', 'failed'
  final String message;
  final int total;
  final int processed;
  final int failed;
  final DateTime createdAt;

  UploadTask({
    required this.taskId,
    required this.status,
    required this.message,
    required this.total,
    required this.processed,
    required this.failed,
    required this.createdAt,
  });

  // Getters for presentation layer
  int get itemsCount => processed;
  int get totalItems => total;

  factory UploadTask.fromJson(Map<String, dynamic> json) {
    return UploadTask(
      taskId: json['task_id'] ?? '',
      status: json['status'] ?? 'unknown',
      message: json['message'] ?? '',
      total: json['total'] ?? 0,
      processed: json['processed'] ?? 0,
      failed: json['failed'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

/// Wraps an XFile with its individual status for per-file UI tracking
class UploadFileItem {
  final String path;
  final String name;
  final int? sizeBytes;
  UploadFileStatus status;
  String? errorMessage;

  UploadFileItem({
    required this.path,
    required this.name,
    this.sizeBytes,
    this.status = UploadFileStatus.idle,
    this.errorMessage,
  });

  bool get isPdf => name.toLowerCase().endsWith('.pdf');

  bool get isImage =>
      name.toLowerCase().endsWith('.jpg') ||
      name.toLowerCase().endsWith('.jpeg') ||
      name.toLowerCase().endsWith('.png') ||
      name.toLowerCase().endsWith('.heic') ||
      name.toLowerCase().endsWith('.webp');

  String get sizeLabel {
    if (sizeBytes == null) return '';
    if (sizeBytes! < 1024) return '${sizeBytes}B';
    if (sizeBytes! < 1024 * 1024) {
      return '${(sizeBytes! / 1024).toStringAsFixed(0)}KB';
    }
    return '${(sizeBytes! / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  UploadFileItem copyWith({UploadFileStatus? status, String? errorMessage}) {
    return UploadFileItem(
      path: path,
      name: name,
      sizeBytes: sizeBytes,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class UploadTaskStatus {
  final String taskId;
  final String status; // 'processing', 'completed', 'failed'
  final String message;
  final int total;
  final int processed;
  final int failed;
  final int skipped; // duplicates auto-skipped (FIX-3)
  final List<dynamic>? duplicates;

  /// Detailed per-file duplicate info: [{invoice_number, invoice_date, receipt_link, message}]
  final List<Map<String, dynamic>> skippedDetails;

  /// Error messages from failed files
  final List<String> errors;

  UploadTaskStatus({
    required this.taskId,
    required this.status,
    required this.message,
    required this.total,
    required this.processed,
    required this.failed,
    this.skipped = 0,
    this.duplicates,
    this.skippedDetails = const [],
    this.errors = const [],
  });

  factory UploadTaskStatus.fromJson(Map<String, dynamic> json) {
    final progress = json['progress'] as Map<String, dynamic>? ?? {};
    final rawSkippedDetails = progress['skipped_details'] as List<dynamic>? ?? [];
    final rawErrors = progress['errors'] as List<dynamic>? ?? [];

    return UploadTaskStatus(
      taskId: json['task_id'] ?? '',
      status: json['status'] ?? 'unknown',
      message: json['message'] ?? '',
      total: progress['total'] ?? 0,
      processed: progress['processed'] ?? 0,
      failed: progress['failed'] ?? 0,
      skipped: progress['skipped'] ?? json['skipped_count'] ?? 0,
      duplicates: json['duplicates'],
      skippedDetails: rawSkippedDetails
          .whereType<Map<String, dynamic>>()
          .toList(),
      errors: rawErrors.map((e) => e.toString()).toList(),
    );
  }

  UploadTaskStatus copyWith({
    String? taskId,
    String? status,
    String? message,
    int? total,
    int? processed,
    int? failed,
    int? skipped,
    List<dynamic>? duplicates,
    List<Map<String, dynamic>>? skippedDetails,
    List<String>? errors,
  }) {
    return UploadTaskStatus(
      taskId: taskId ?? this.taskId,
      status: status ?? this.status,
      message: message ?? this.message,
      total: total ?? this.total,
      processed: processed ?? this.processed,
      failed: failed ?? this.failed,
      skipped: skipped ?? this.skipped,
      duplicates: duplicates ?? this.duplicates,
      skippedDetails: skippedDetails ?? this.skippedDetails,
      errors: errors ?? this.errors,
    );
  }
}

class UploadSummary {
  final String? lastActiveDate;
  final String? lastReceiptNumber;
  final String status;

  UploadSummary({
    this.lastActiveDate,
    this.lastReceiptNumber,
    required this.status,
  });

  factory UploadSummary.fromJson(Map<String, dynamic> json) {
    return UploadSummary(
      lastActiveDate: json['last_active_date'],
      lastReceiptNumber: json['last_receipt_number'],
      status: json['status'] ?? 'unknown',
    );
  }
}

class UploadHistoryItem {
  final String date;
  final int count;
  final List<String> receiptIds;

  UploadHistoryItem({
    required this.date,
    required this.count,
    required this.receiptIds,
  });

  factory UploadHistoryItem.fromJson(Map<String, dynamic> json) {
    return UploadHistoryItem(
      date: json['date'] ?? '',
      count: json['count'] ?? 0,
      receiptIds: List<String>.from(json['receipt_ids'] ?? []),
    );
  }
}

class UploadHistoryResponse {
  final UploadSummary summary;
  final List<UploadHistoryItem> history;

  UploadHistoryResponse({
    required this.summary,
    required this.history,
  });

  factory UploadHistoryResponse.fromJson(Map<String, dynamic> json) {
    return UploadHistoryResponse(
      summary: UploadSummary.fromJson(json['summary'] ?? {}),
      history: (json['history'] as List?)
              ?.map((item) => UploadHistoryItem.fromJson(item))
              .toList() ??
          [],
    );
  }
}
