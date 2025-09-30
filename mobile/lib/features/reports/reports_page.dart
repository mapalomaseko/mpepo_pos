import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'reports_provider.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportsProvider>();
    final report = provider.report;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Sales'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.loadReport(date: provider.selectedDate),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: provider.selectedDate,
                  firstDate: DateTime(2022),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  provider.loadReport(date: picked);
                }
              },
              icon: const Icon(Icons.calendar_today),
              label: Text('Select date (${provider.selectedDate.toIso8601String().substring(0, 10)})'),
            ),
            const SizedBox(height: 16),
            if (provider.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (report == null)
              const Text('No data yet. Pull to refresh.')
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Receipts: ${report['receipt_count']}'),
                      const SizedBox(height: 8),
                      Text('Total sales: ZMW ${(report['total_sales'] as num).toStringAsFixed(2)}'),
                      const SizedBox(height: 8),
                      Text('Total tax: ZMW ${(report['total_tax'] as num).toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
