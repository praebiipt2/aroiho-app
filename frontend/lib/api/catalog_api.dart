import 'dart:convert';
import 'package:http/http.dart' as http;

class CatalogApi {
  final String baseUrl;
  CatalogApi({required this.baseUrl});

  Future<List<Map<String, dynamic>>> listProducts({
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/products?page=$page&limit=$limit');
    final res = await http.get(uri, headers: {'Content-Type': 'application/json'});

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('List products failed: ${res.statusCode} ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected list products response shape');
    }

    final items = decoded['items'];
    if (items is! List) {
      throw Exception('Unexpected list products response items');
    }

    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> getProductDetail(String productId) async {
    final uri = Uri.parse('$baseUrl/products/$productId');
    final res = await http.get(uri, headers: {'Content-Type': 'application/json'});

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Get product failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSellerInfo(String sellerId) async {
    final uri = Uri.parse('$baseUrl/sellers/$sellerId');
    final res = await http.get(uri, headers: {'Content-Type': 'application/json'});

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Get seller failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listProductsBySeller(
    String sellerId, {
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/sellers/$sellerId/products?page=$page&limit=$limit');
    final res = await http.get(uri, headers: {'Content-Type': 'application/json'});

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('List seller products failed: ${res.statusCode} ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected list seller products response shape');
    }

    final items = decoded['items'];
    if (items is! List) {
      throw Exception('Unexpected list seller products response items');
    }

    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
