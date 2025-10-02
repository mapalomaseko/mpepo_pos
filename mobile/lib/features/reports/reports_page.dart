import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'reports_provider.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportsProvider>();
    final report = provider.report;
    final dateFormatter = DateFormat('MMM d');
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
      body: RefreshIndicator(
        onRefresh: () => provider.loadReport(date: provider.selectedDate),
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
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
            if (provider.isLoading && report == null)
              const Center(child: CircularProgressIndicator())
            else if (report == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text('No data yet. Pull to refresh.'),
              )
            else ...[
              _SummaryCard(report: report),
              const SizedBox(height: 16),
              if (provider.salesByDay.isNotEmpty)
                _SalesTrendChart(data: provider.salesByDay, formatter: dateFormatter)
              else
                const _EmptyPlaceholder(message: 'No sales recorded for the selected period.'),
              const SizedBox(height: 24),
              if (provider.popularProducts.isNotEmpty)
                _PopularProductsChart(data: provider.popularProducts)
              else
                const _EmptyPlaceholder(message: 'No product sales to display.'),
              const SizedBox(height: 16),
              if (provider.popularProducts.isNotEmpty)
                _PopularProductsList(products: provider.popularProducts),
            ],
            if (provider.isLoading && report != null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Map<String, dynamic> report;

  const _SummaryCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Card(
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
    );
  }
}

class _SalesTrendChart extends StatelessWidget {
  final List<SalesPoint> data;
  final DateFormat formatter;

  const _SalesTrendChart({required this.data, required this.formatter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxY = data.fold<double>(0, (previous, element) => math.max(previous, element.totalSales));
    final yMax = maxY == 0 ? 1.0 : maxY * 1.2;
    final spots = data.asMap().entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.totalSales))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sales by day', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (data.length - 1).toDouble(),
                  minY: 0,
                  maxY: yMax,
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if (index < 0 || index >= data.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              formatter.format(data[index].date),
                              style: theme.textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        interval: yMax <= 5 ? 1 : null,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value == 0 ? '0' : value.toStringAsFixed(0),
                            style: theme.textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      color: theme.colorScheme.primary,
                      barWidth: 4,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withOpacity(0.2),
                            theme.colorScheme.primary.withOpacity(0.05),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      spots: spots,
                    ),
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

class _PopularProductsChart extends StatelessWidget {
  final List<PopularProductSummary> data;

  const _PopularProductsChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxQuantity = data.fold<int>(1, (previous, element) => math.max(previous, element.quantitySold));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top products', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final barHeight = 28.0;
                final spacing = 20.0;
                return Column(
                  children: data.asMap().entries.map((entry) {
                    final index = entry.key;
                    final product = entry.value;
                    final fillFraction = product.quantitySold <= 0
                        ? 0.0
                        : (product.quantitySold / maxQuantity).clamp(0.0, 1.0);
                    return Padding(
                      padding: EdgeInsets.only(bottom: index == data.length - 1 ? 0 : spacing),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              Container(
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(barHeight / 2),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: fillFraction,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  height: barHeight,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(barHeight / 2),
                                    gradient: LinearGradient(
                                      colors: [
                                        theme.colorScheme.secondary,
                                        theme.colorScheme.primary,
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  product.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Sold: ${product.quantitySold}',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PopularProductsList extends StatelessWidget {
  final List<PopularProductSummary> products;

  const _PopularProductsList({required this.products});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ListTile(
            title: Text('Popular products breakdown'),
            subtitle: Text('Quantity sold and revenue for the selected period.'),
          ),
          const Divider(height: 0),
          ...products.map((product) {
            return ListTile(
              title: Text(product.name),
              subtitle: Text('Sold: ${product.quantitySold} • Revenue: ZMW ${product.totalSales.toStringAsFixed(2)}'),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  final String message;

  const _EmptyPlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
