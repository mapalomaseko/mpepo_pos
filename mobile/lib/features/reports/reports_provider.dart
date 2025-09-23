import 'package:flutter/foundation.dart';

import '../../data/repositories/report_repository.dart';

class ReportsProvider extends ChangeNotifier {
  final ReportRepository repository;

  Map<String, dynamic>? report;
  bool isLoading = false;
  String? error;
  DateTime selectedDate = DateTime.now();

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
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
