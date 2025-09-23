import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'invoices_provider.dart';

class InvoicesPage extends StatelessWidget {
  const InvoicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvoicesProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.loadInvoices(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.loadInvoices(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Submitted', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (provider.isLoading && provider.invoices.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (provider.invoices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No invoices yet.'),
              )
            else
              ...provider.invoices.map((invoice) {
                return Card(
                  child: ListTile(
                    title: Text('Receipt #${invoice.receiptId}'),
                    subtitle: Text('Status: ${invoice.status}'),
                    trailing: Text(invoice.createdAt.toLocal().toString().split('.').first),
                  ),
                );
              }),
            const SizedBox(height: 24),
            Text('Offline queue', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (provider.jobs.isEmpty)
              const Text('No pending jobs.')
            else
              ...provider.jobs.map((job) {
                return Card(
                  child: ListTile(
                    title: Text('Job ${job.id} • ${job.type}'),
                    subtitle: Text('Attempts: ${job.attempts} • Status: ${job.status}'),
                    trailing: job.status == 'failed'
                        ? TextButton(
                            onPressed: () => provider.retryJob(job.id),
                            child: const Text('Retry'),
                          )
                        : null,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
