import '../../services/api_service.dart';
import '../models/product.dart';

class ProductRepository {
  final ApiService apiService;

  ProductRepository(this.apiService);

  Future<List<Product>> fetchProducts() => apiService.getProducts();

  Future<Product> createProduct(String name, double price, int stock) =>
      apiService.createProduct(name: name, price: price, stock: stock);

  Future<Product> updateProduct(Product product) => apiService.updateProduct(product);

  Future<void> deleteProduct(int id) => apiService.deleteProduct(id);
}
