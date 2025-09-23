import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/receipt.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../services/queue_service.dart';
import '../invoices/invoices_provider.dart';

class CheckoutPage extends StatelessWidget {
  final Receipt receipt;

  const CheckoutPage({super.key, required this.receipt});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Receipt #${receipt.id}', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: receipt.items.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final item = receipt.items[index];
                  return ListTile(
                    title: Text(item.name),
                    subtitle: Text('${item.qty} x KES ${item.unitPrice.toStringAsFixed(2)}'),
                    trailing: Text('KES ${item.lineTotal.toStringAsFixed(2)}'),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text('Subtotal: KES ${receipt.subtotal.toStringAsFixed(2)}'),
            Text('Tax: KES ${receipt.tax.toStringAsFixed(2)}'),
            Text('Discount: KES ${receipt.discount.toStringAsFixed(2)}'),
            Text('Total: KES ${receipt.total.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _submitInvoice(context),
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Submit Invoice'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitInvoice(BuildContext context) async {
    final repository = context.read<InvoiceRepository>();
    final queueService = context.read<QueueService>();
    final invoicesProvider = context.read<InvoicesProvider>();
    try {
      await repository.submitInvoice(receipt.id);
      await invoicesProvider.loadInvoices();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice submitted successfully.')),
      );
    } catch (e) {
      await queueService.enqueueInvoice(receipt.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invoice queued for retry: $e'),
        ),
      );
    }
  }
}
