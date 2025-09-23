import '../../services/api_service.dart';
import '../models/invoice.dart';

class InvoiceRepository {
  final ApiService apiService;

  InvoiceRepository(this.apiService);

  Future<Invoice> submitInvoice(int receiptId) => apiService.submitInvoice(receiptId);

  Future<List<Invoice>> fetchInvoices() => apiService.getInvoices();
}
