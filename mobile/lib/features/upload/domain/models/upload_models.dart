/// Per-file upload lifecycle status
enum UploadFileStatus { idle, uploading, processing, done, failed, duplicate }

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
  final String
      status; // 'processing', 'completed', 'failed', 'duplicate_detected'
  final String message;
  final int total;
  final int processed;
  final int failed;
  final List<dynamic>? duplicates;

  UploadTaskStatus({
    required this.taskId,
    required this.status,
    required this.message,
    required this.total,
    required this.processed,
    required this.failed,
    this.duplicates,
  });

  factory UploadTaskStatus.fromJson(Map<String, dynamic> json) {
    return UploadTaskStatus(
      taskId: json['task_id'] ?? '',
      status: json['status'] ?? 'unknown',
      message: json['message'] ?? '',
      total: json['progress']?['total'] ?? 0,
      processed: json['progress']?['processed'] ?? 0,
      failed: json['progress']?['failed'] ?? 0,
      duplicates: json['duplicates'],
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
