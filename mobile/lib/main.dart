import 'package:flutter/material.dart';

import 'app.dart';
import 'services/api_service.dart';
import 'services/connectivity_service.dart';
import 'services/queue_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final apiService = ApiService();
  final queueService = QueueService();
  final connectivityService = ConnectivityService(queueService: queueService, apiService: apiService);
  await connectivityService.initialize();
  runApp(
    SmartPosApp(
      apiService: apiService,
      queueService: queueService,
      connectivityService: connectivityService,
    ),
  );
}
