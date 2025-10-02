import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/invoice.dart';
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
                final createdLabel =
                    DateFormat.yMMMd().add_jm().format(invoice.createdAt.toLocal());
                return Card(
                  child: ListTile(
                    title: Text('Receipt #${invoice.receiptId}'),
                    subtitle: Text('Status: ${invoice.status}'),
                    trailing: Text(createdLabel, textAlign: TextAlign.right),
                    onTap: () => _showReceiptDetails(context, invoice),
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

void _showReceiptDetails(BuildContext context, Invoice invoice) {
  final theme = Theme.of(context);
  final createdLabel = DateFormat.yMMMd().add_jm().format(invoice.createdAt.toLocal());
  final currency = NumberFormat.currency(symbol: 'ZMW ', decimalDigits: 2);

  double? toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  List<Map<String, dynamic>> parseItems(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => item is Map<String, dynamic>
              ? item
              : Map<String, dynamic>.from(item))
          .toList();
    }
    return const [];
  }

  final items = parseItems(invoice.payload['items']);
  final subtotal = toDouble(invoice.payload['subtotal']);
  final tax = toDouble(invoice.payload['tax']);
  final discount = toDouble(invoice.payload['discount']);
  final total = toDouble(invoice.payload['total']);

  Widget summaryRow(String label, double? value) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            currency.format(value),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.85,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Receipt #${invoice.receiptId}',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text('Created $createdLabel', style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(invoice.status.toUpperCase()),
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      labelStyle: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text('Invoice #${invoice.id}', style: theme.textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (items.isNotEmpty) ...[
                          Text('Items', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          ...items.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            final name =
                                item['name'] ?? item['product_name'] ?? 'Item ${index + 1}';
                            final qty = item['qty'] ?? item['quantity'];
                            final unitPrice =
                                toDouble(item['unit_price'] ?? item['price']);
                            final lineTotal =
                                toDouble(item['line_total'] ?? item['total']);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name.toString(),
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${qty ?? '-'} × ${unitPrice != null ? currency.format(unitPrice) : '-'}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurface.withOpacity(0.65),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    lineTotal != null ? currency.format(lineTotal) : '-',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ] else
                          Text(
                            'No line item details were provided for this receipt.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        const SizedBox(height: 24),
                        Text('Summary', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        summaryRow('Subtotal', subtotal),
                        summaryRow('Tax', tax),
                        summaryRow('Discount', discount),
                        summaryRow('Total', total),
                        if (invoice.authorityResponse != null) ...[
                          const SizedBox(height: 24),
                          Text('Authority response', style: theme.textTheme.titleSmall),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SelectableText(
                              const JsonEncoder.withIndent('  ')
                                  .convert(invoice.authorityResponse),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
