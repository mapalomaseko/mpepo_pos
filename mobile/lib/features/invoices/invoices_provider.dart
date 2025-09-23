import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/invoice.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../services/queue_service.dart';

class InvoicesProvider extends ChangeNotifier {
  final InvoiceRepository repository;
  final QueueService queueService;

  List<Invoice> invoices = [];
  List<QueueJob> jobs = [];
  bool isLoading = false;
  String? error;

  StreamSubscription<List<QueueJob>>? _jobsSubscription;

  InvoicesProvider({required this.repository, required this.queueService}) {
    _jobsSubscription = queueService.jobsStream.listen((event) {
      jobs = event;
      notifyListeners();
    });
  }

  Future<void> loadInvoices() async {
    isLoading = true;
    notifyListeners();
    try {
      invoices = await repository.fetchInvoices();
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> retryJob(int id) async {
    await queueService.retryFailedJob(id);
    await queueService.processQueue((receiptId) async {
      await repository.submitInvoice(receiptId);
    });
  }

  @override
  void dispose() {
    _jobsSubscription?.cancel();
    super.dispose();
  }
}
