import '../../services/api_service.dart';

class ReportRepository {
  final ApiService apiService;

  ReportRepository(this.apiService);

  Future<Map<String, dynamic>> fetchDailyReport(DateTime date) => apiService.getDailyReport(date);
}
