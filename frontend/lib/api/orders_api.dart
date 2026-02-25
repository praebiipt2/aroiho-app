import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class OrdersApi {
  Uri _u(String path) => Uri.parse('${AppConfig.baseUrl}$path');

  Future<Map<String, dynamic>> listMyOrders({
    required String accessToken,
    bool includeHidden = false,
    int page = 1,
    int limit = 10,
  }) async {
    final res = await http.get(
      _u(
        '/v1/orders?includeHidden=${includeHidden ? 'true' : 'false'}'
        '&page=$page&limit=$limit',
      ),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('List orders failed: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body);
    if (data is! Map) {
      return {
        'items': <Map<String, dynamic>>[],
        'page': page,
        'limit': limit,
        'total': 0,
        'hasMore': false,
      };
    }

    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];

    return {
      'items': items,
      'page': data['page'] ?? page,
      'limit': data['limit'] ?? limit,
      'total': data['total'] ?? items.length,
      'hasMore': data['hasMore'] == true,
    };
  }

  Future<Map<String, dynamic>> getOrder({
    required String accessToken,
    required String orderId,
  }) async {
    final res = await http.get(
      _u('/v1/orders/$orderId'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Get order failed: ${res.statusCode} ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> getShipment({
    required String accessToken,
    required String orderId,
  }) async {
    final res = await http.get(
      _u('/v1/orders/$orderId/shipment'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Get shipment failed: ${res.statusCode} ${res.body}');
    }

    if (res.body.trim().isEmpty) return null;
    final data = jsonDecode(res.body);
    if (data == null) return null;
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTracking({
    required String accessToken,
    required String orderId,
  }) async {
    final res = await http.get(
      _u('/v1/orders/$orderId/tracking'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Get tracking failed: ${res.statusCode} ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancel({
    required String accessToken,
    required String orderId,
  }) async {
    final res = await http.post(
      _u('/v1/orders/$orderId/cancel'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Cancel order failed: ${res.statusCode} ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> refund({
    required String accessToken,
    required String orderId,
  }) async {
    final res = await http.post(
      _u('/v1/orders/$orderId/refund'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Refund order failed: ${res.statusCode} ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> hide({
    required String accessToken,
    required String orderId,
  }) async {
    final res = await http.post(
      _u('/v1/orders/$orderId/hide'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Hide order failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> unhide({
    required String accessToken,
    required String orderId,
  }) async {
    final res = await http.post(
      _u('/v1/orders/$orderId/unhide'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Unhide order failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> softDelete({
    required String accessToken,
    required String orderId,
  }) async {
    final res = await http.post(
      _u('/v1/orders/$orderId/delete'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Delete order failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> restoreDeleted({
    required String accessToken,
    required String orderId,
  }) async {
    final res = await http.post(
      _u('/v1/orders/$orderId/restore'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Restore order failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> checkout({
    required String accessToken,
    required String addressId,
    String shippingMethod = 'AUTO',
    num shippingSurcharge = 0,
  }) async {
    final res = await http.post(
      _u('/v1/orders/checkout'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'addressId': addressId,
        'shippingMethod': shippingMethod,
        'shippingSurcharge': shippingSurcharge,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Checkout failed: ${res.statusCode} ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
