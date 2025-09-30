import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'api_service.dart';
import 'queue_service.dart';

class ConnectivityService {
  final QueueService queueService;
  final ApiService apiService;
  StreamSubscription<ConnectivityResult>? _subscription;
  Timer? _retryTimer;
  ConnectivityResult _latestStatus = ConnectivityResult.none;

  ConnectivityService({required this.queueService, required this.apiService});

  Future<void> initialize() async {
    await queueService.init();
    _latestStatus = await Connectivity().checkConnectivity();
    await _drainQueue();
    _subscription = Connectivity().onConnectivityChanged.listen((event) async {
      _latestStatus = event;
      await _drainQueue();
    });
    _retryTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await _drainQueue();
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _retryTimer?.cancel();
    await queueService.dispose();
  }

  Future<void> _drainQueue() async {
    if (_latestStatus == ConnectivityResult.none) {
      return;
    }
    await queueService.resetFailedJobs();
    await queueService.processQueue((receiptId) async {
      await apiService.submitInvoice(receiptId);
    });
  }
}
