import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class PaymentsApi {
  Uri _u(String path) => Uri.parse('${AppConfig.baseUrl}$path');

  Future<Map<String, dynamic>> createIntent({
    required String accessToken,
    required String orderId,
    required String provider,
  }) async {
    final res = await http.post(
      _u('/v1/payments/create-intent'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'orderId': orderId,
        'provider': provider,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Create payment intent failed: ${res.statusCode} ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
