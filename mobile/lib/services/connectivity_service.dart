import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'api_service.dart';
import 'queue_service.dart';

class ConnectivityService {
  final QueueService queueService;
  final ApiService apiService;
  StreamSubscription<ConnectivityResult>? _subscription;

  ConnectivityService({required this.queueService, required this.apiService});

  Future<void> initialize() async {
    await queueService.init();
    // Kick off queue processing immediately at start-up.
    await queueService.processQueue((receiptId) async {
      await apiService.submitInvoice(receiptId);
    });
    _subscription = Connectivity().onConnectivityChanged.listen((event) async {
      if (event != ConnectivityResult.none) {
        await queueService.processQueue((receiptId) async {
          await apiService.submitInvoice(receiptId);
        });
      }
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await queueService.dispose();
  }
}
