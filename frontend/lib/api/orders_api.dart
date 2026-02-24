import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class OrdersApi {
  Uri _u(String path) => Uri.parse('${AppConfig.baseUrl}$path');

  Future<List<Map<String, dynamic>>> listMyOrders({
    required String accessToken,
  }) async {
    final res = await http.get(
      _u('/v1/orders'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('List orders failed: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body);
    if (data is! List) return <Map<String, dynamic>>[];
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
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
