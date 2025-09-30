import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/repositories/invoice_repository.dart';
import 'data/repositories/product_repository.dart';
import 'data/repositories/report_repository.dart';
import 'features/cart/cart_page.dart';
import 'features/cart/cart_provider.dart';
import 'features/invoices/invoices_page.dart';
import 'features/invoices/invoices_provider.dart';
import 'features/products/products_page.dart';
import 'features/products/products_provider.dart';
import 'features/reports/reports_page.dart';
import 'features/reports/reports_provider.dart';
import 'services/api_service.dart';
import 'services/connectivity_service.dart';
import 'services/queue_service.dart';

class SmartPosApp extends StatefulWidget {
  final ApiService apiService;
  final QueueService queueService;
  final ConnectivityService connectivityService;

  const SmartPosApp({
    super.key,
    required this.apiService,
    required this.queueService,
    required this.connectivityService,
  });

  @override
  State<SmartPosApp> createState() => _SmartPosAppState();
}

class _SmartPosAppState extends State<SmartPosApp> {
  @override
  void dispose() {
    widget.connectivityService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: widget.apiService),
        Provider<QueueService>.value(value: widget.queueService),
        Provider<ConnectivityService>.value(value: widget.connectivityService),
        ProxyProvider<ApiService, ProductRepository>(
          update: (_, api, __) => ProductRepository(api),
        ),
        ProxyProvider<ApiService, InvoiceRepository>(
          update: (_, api, __) => InvoiceRepository(api),
        ),
        ProxyProvider<ApiService, ReportRepository>(
          update: (_, api, __) => ReportRepository(api),
        ),
        ChangeNotifierProvider<ProductsProvider>(
          create: (context) => ProductsProvider(context.read<ProductRepository>())..loadProducts(),
        ),
        ChangeNotifierProvider<CartProvider>(
          create: (_) => CartProvider(),
        ),
        ChangeNotifierProvider<InvoicesProvider>(
          create: (context) => InvoicesProvider(
            repository: context.read<InvoiceRepository>(),
            queueService: widget.queueService,
          )..loadInvoices(),
        ),
        ChangeNotifierProvider<ReportsProvider>(
          create: (context) => ReportsProvider(context.read<ReportRepository>())..loadReport(),
        ),
      ],
      child: MaterialApp(
        title: 'Mpepo Smart POS',
        theme: _buildTheme(),
        home: const _HomePage(),
      ),
    );
  }
}

ThemeData _buildTheme() {
  const seed = Color(0xFFFF6F00);
  final colorScheme = ColorScheme.fromSeed(seedColor: seed);
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: colorScheme.onPrimary,
      unselectedLabelColor: colorScheme.onPrimary.withOpacity(0.7),
      indicatorColor: colorScheme.onPrimary,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.secondary,
      foregroundColor: colorScheme.onSecondary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.primary.withOpacity(0.15),
      labelTextStyle: MaterialStateProperty.resolveWith(
        (states) => TextStyle(
          fontWeight: states.contains(MaterialState.selected) ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    ),
  );
}

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  int _index = 0;

  static const _pages = [
    ProductsPage(),
    CartPage(),
    InvoicesPage(),
    ReportsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.fastfood), label: 'Products'),
          NavigationDestination(icon: Icon(Icons.shopping_cart), label: 'Cart'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Invoices'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Reports'),
        ],
      ),
    );
  }
}
