import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class CartApi {
  Uri _u(String path) => Uri.parse('${AppConfig.baseUrl}$path');

  Future<Map<String, dynamic>> getCart({
    required String accessToken,
  }) async {
    final res = await http.get(
      _u('/v1/cart'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Get cart failed: ${res.statusCode} ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addItem({
    required String accessToken,
    required String productId,
    required String inventoryLotId,
    required num quantity,
  }) async {
    final res = await http.post(
      _u('/v1/cart/items'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'productId': productId,
        'inventoryLotId': inventoryLotId,
        'quantity': quantity,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Add cart item failed: ${res.statusCode} ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateItem({
    required String accessToken,
    required String cartItemId,
    required num quantity,
  }) async {
    final res = await http.put(
      _u('/v1/cart/items/$cartItemId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'quantity': quantity}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Update cart item failed: ${res.statusCode} ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> removeItem({
    required String accessToken,
    required String cartItemId,
  }) async {
    final res = await http.delete(
      _u('/v1/cart/items/$cartItemId'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Remove cart item failed: ${res.statusCode} ${res.body}');
    }
  }
}
