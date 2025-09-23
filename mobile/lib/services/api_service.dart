import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../data/models/invoice.dart';
import '../data/models/product.dart';
import '../data/models/receipt.dart';

typedef JsonMap = Map<String, dynamic>;

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

/// Tiny wrapper around HTTP for this app.
/// Each method returns parsed JSON or throws a readable error.
class ApiService {
  final String baseUrl;
  final http.Client _client;

  ApiService({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? Config.apiBaseUrl,
        _client = client ?? http.Client();

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse(baseUrl).replace(path: path, queryParameters: query);
  }

  Future<List<Product>> getProducts() async {
    final response = await _client.get(_uri('/products/'));
    final data = _decodeResponse(response);
    final list = (data as List<dynamic>)
        .map((item) => Product.fromJson(item as JsonMap))
        .toList();
    return list;
  }

  Future<Product> createProduct({
    required String name,
    required double price,
    required int stock,
  }) async {
    final payload = {'name': name, 'price': price, 'stock': stock};
    final response = await _client.post(
      _uri('/products/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    final data = _decodeResponse(response) as JsonMap;
    return Product.fromJson(data);
  }

  Future<Product> updateProduct(Product product) async {
    final payload = {'name': product.name, 'price': product.price, 'stock': product.stock};
    final response = await _client.put(
      _uri('/products/${product.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    final data = _decodeResponse(response) as JsonMap;
    return Product.fromJson(data);
  }

  Future<void> deleteProduct(int id) async {
    final response = await _client.delete(_uri('/products/$id'));
    if (response.statusCode >= 400) {
      throw ApiException('Failed to delete product: ${response.body}');
    }
  }

  Future<Receipt> checkout(List<JsonMap> items, {double? discountPercent}) async {
    final payload = {'items': items, if (discountPercent != null) 'discount_percent': discountPercent};
    final response = await _client.post(
      _uri('/checkout/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    final data = _decodeResponse(response) as JsonMap;
    return Receipt.fromJson(data);
  }

  Future<Invoice> submitInvoice(int receiptId) async {
    final response = await _client.post(_uri('/invoices/submit/$receiptId'));
    final data = _decodeResponse(response) as JsonMap;
    return Invoice.fromJson(data);
  }

  Future<List<Invoice>> getInvoices() async {
    final response = await _client.get(_uri('/invoices/'));
    final data = _decodeResponse(response) as JsonMap;
    final list = (data['invoices'] as List<dynamic>)
        .map((item) => Invoice.fromJson(item as JsonMap))
        .toList();
    return list;
  }

  Future<JsonMap> getDailyReport(DateTime date) async {
    final response = await _client.get(
      _uri('/reports/daily', {'date': date.toIso8601String().substring(0, 10)}),
    );
    final data = _decodeResponse(response) as JsonMap;
    return data;
  }

  dynamic _decodeResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    }
    throw ApiException('Request failed: ${response.statusCode} ${response.body}');
  }
}
