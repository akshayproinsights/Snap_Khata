class KPICard {
  final double currentValue;
  final double previousValue;
  final double changePercent;
  final String label;
  final String formatType;

  KPICard({
    required this.currentValue,
    required this.previousValue,
    required this.changePercent,
    required this.label,
    required this.formatType,
  });

  factory KPICard.fromJson(Map<String, dynamic> json) {
    return KPICard(
      currentValue: _parseDouble(json['current_value']),
      previousValue: _parseDouble(json['previous_value']),
      changePercent: _parseDouble(json['change_percent']),
      label: json['label']?.toString() ?? '',
      formatType: json['format_type']?.toString() ?? 'number',
    );
  }
}

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class DashboardKPIs {
  final KPICard totalRevenue;
  final KPICard avgJobValue;
  final KPICard inventoryAlerts;
  final KPICard pendingActions;

  DashboardKPIs({
    required this.totalRevenue,
    required this.avgJobValue,
    required this.inventoryAlerts,
    required this.pendingActions,
  });

  factory DashboardKPIs.fromJson(Map<String, dynamic> json) {
    // Use Map.from() to safely cast nested maps from Hive cache (_Map<dynamic,dynamic>)
    Map<String, dynamic> safeMap(dynamic value) {
      if (value == null) return {};
      if (value is Map<String, dynamic>) return value;
      return Map<String, dynamic>.from(value as Map);
    }

    return DashboardKPIs(
      totalRevenue: KPICard.fromJson(safeMap(json['total_revenue'])),
      avgJobValue: KPICard.fromJson(safeMap(json['avg_job_value'])),
      inventoryAlerts: KPICard.fromJson(safeMap(json['inventory_alerts'])),
      pendingActions: KPICard.fromJson(safeMap(json['pending_actions'])),
    );
  }
}

// ─── Revenue Summary ──────────────────────────────────────────────────────────

class RevenueSummary {
  final double totalRevenue;
  final double partRevenue;
  final double labourRevenue;
  final int totalTransactions;
  final String dateFrom;
  final String dateTo;

  RevenueSummary({
    required this.totalRevenue,
    required this.partRevenue,
    required this.labourRevenue,
    required this.totalTransactions,
    required this.dateFrom,
    required this.dateTo,
  });

  double get partPercent =>
      totalRevenue > 0 ? (partRevenue / totalRevenue * 100) : 0;
  double get labourPercent =>
      totalRevenue > 0 ? (labourRevenue / totalRevenue * 100) : 0;

  factory RevenueSummary.fromJson(Map<String, dynamic> json) {
    return RevenueSummary(
      totalRevenue: _parseDouble(json['total_revenue']),
      partRevenue: _parseDouble(json['part_revenue']),
      labourRevenue: _parseDouble(json['labour_revenue']),
      totalTransactions: _parseInt(json['total_transactions']),
      dateFrom: json['date_from']?.toString() ?? '',
      dateTo: json['date_to']?.toString() ?? '',
    );
  }

  static RevenueSummary empty() => RevenueSummary(
        totalRevenue: 0,
        partRevenue: 0,
        labourRevenue: 0,
        totalTransactions: 0,
        dateFrom: '',
        dateTo: '',
      );
}

// ─── Period Selector ──────────────────────────────────────────────────────────

enum DashboardPeriod {
  week(7, '7D'),
  month(30, '30D'),
  quarter(90, '90D');

  final int days;
  final String label;
  const DashboardPeriod(this.days, this.label);
}

class StockSummary {
  final double totalStockValue;
  final int lowStockCount;
  final int outOfStockCount;
  final int belowReorderCount;
  final int totalItems;

  StockSummary({
    required this.totalStockValue,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.belowReorderCount,
    required this.totalItems,
  });

  factory StockSummary.fromJson(Map<String, dynamic> json) {
    return StockSummary(
      totalStockValue: _parseDouble(json['total_stock_value']),
      lowStockCount: _parseInt(json['low_stock_count']),
      outOfStockCount: _parseInt(json['out_of_stock_count']),
      belowReorderCount: _parseInt(json['below_reorder_count']),
      totalItems: _parseInt(json['total_items']),
    );
  }
}

class DailySalesVolume {
  final String date;
  final double revenue;
  final int volume;
  final double partsRevenue;
  final double laborRevenue;

  DailySalesVolume({
    required this.date,
    required this.revenue,
    required this.volume,
    required this.partsRevenue,
    required this.laborRevenue,
  });

  factory DailySalesVolume.fromJson(Map<String, dynamic> json) {
    return DailySalesVolume(
      date: json['date']?.toString() ?? '',
      revenue: _parseDouble(json['revenue']),
      volume: _parseInt(json['volume']),
      partsRevenue: _parseDouble(json['parts_revenue']),
      laborRevenue: _parseDouble(json['labor_revenue']),
    );
  }
}

class StockAlert {
  final String partNumber;
  final String itemName;
  final double currentStock;
  final double reorderPoint;
  final double stockValue;
  final String status; // "Out of Stock" | "Low Stock"

  StockAlert({
    required this.partNumber,
    required this.itemName,
    required this.currentStock,
    required this.reorderPoint,
    required this.stockValue,
    required this.status,
  });

  bool get isOutOfStock => status == 'Out of Stock';

  factory StockAlert.fromJson(Map<String, dynamic> json) {
    return StockAlert(
      partNumber: json['part_number']?.toString() ?? 'N/A',
      itemName: json['item_name']?.toString() ?? 'Unknown Item',
      currentStock: _parseDouble(json['current_stock']),
      reorderPoint: _parseDouble(json['reorder_point']),
      stockValue: _parseDouble(json['stock_value']),
      status: json['status']?.toString() ?? 'Low Stock',
    );
  }
}
