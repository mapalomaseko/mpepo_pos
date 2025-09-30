import '../../services/api_service.dart';
import '../models/product.dart';

class ProductRepository {
  final ApiService apiService;

  ProductRepository(this.apiService);

  Future<List<Product>> fetchProducts() => apiService.getProducts();

  Future<Product> createProduct({
    required String name,
    required double price,
    required int stock,
    String? description,
    String? category,
    String? imageUrl,
  }) =>
      apiService.createProduct(
        name: name,
        price: price,
        stock: stock,
        description: description,
        category: category,
        imageUrl: imageUrl,
      );

  Future<Product> updateProduct(Product product) => apiService.updateProduct(product);

  Future<void> deleteProduct(int id) => apiService.deleteProduct(id);
}
