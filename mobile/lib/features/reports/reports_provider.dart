import 'package:flutter/foundation.dart';

import '../../data/repositories/report_repository.dart';

class SalesPoint {
  final DateTime date;
  final double totalSales;

  SalesPoint({required this.date, required this.totalSales});
}

class PopularProductSummary {
  final int productId;
  final String name;
  final int quantitySold;
  final double totalSales;

  PopularProductSummary({
    required this.productId,
    required this.name,
    required this.quantitySold,
    required this.totalSales,
  });
}

class ReportsProvider extends ChangeNotifier {
  final ReportRepository repository;

  Map<String, dynamic>? report;
  bool isLoading = false;
  String? error;
  DateTime selectedDate = DateTime.now();
  List<SalesPoint> salesByDay = [];
  List<PopularProductSummary> popularProducts = [];

  ReportsProvider(this.repository);

  Future<void> loadReport({DateTime? date}) async {
    if (date != null) {
      selectedDate = date;
    }
    isLoading = true;
    notifyListeners();
    try {
      report = await repository.fetchDailyReport(selectedDate);
      error = null;
      salesByDay = _parseSalesHistory(report?['sales_by_day'] as List<dynamic>?);
      popularProducts = _parsePopularProducts(report?['popular_products'] as List<dynamic>?);
    } catch (e) {
      error = e.toString();
      salesByDay = [];
      popularProducts = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  List<SalesPoint> _parseSalesHistory(List<dynamic>? raw) {
    if (raw == null) return [];
    return raw.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return SalesPoint(
        date: DateTime.parse(map['date'] as String),
        totalSales: (map['total_sales'] as num).toDouble(),
      );
    }).toList();
  }

  List<PopularProductSummary> _parsePopularProducts(List<dynamic>? raw) {
    if (raw == null) return [];
    return raw.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return PopularProductSummary(
        productId: map['product_id'] as int,
        name: map['name'] as String,
        quantitySold: map['quantity_sold'] as int,
        totalSales: (map['total_sales'] as num).toDouble(),
      );
    }).toList();
  }
}
