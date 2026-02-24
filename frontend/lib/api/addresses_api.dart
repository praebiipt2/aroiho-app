import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class AddressesApi {
  Uri _u(String path) => Uri.parse('${AppConfig.baseUrl}$path');

  Future<List<Map<String, dynamic>>> listMine({
    required String accessToken,
  }) async {
    final res = await http.get(
      _u('/v1/addresses'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('List addresses failed: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body);
    if (data is! List) return <Map<String, dynamic>>[];
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> updateMine({
    required String accessToken,
    required String addressId,
    required Map<String, dynamic> data,
  }) async {
    final res = await http.put(
      _u('/v1/addresses/$addressId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(data),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Update address failed: ${res.statusCode} ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setDefault({
    required String accessToken,
    required String addressId,
  }) async {
    final res = await http.patch(
      _u('/v1/addresses/$addressId/default'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Set default address failed: ${res.statusCode} ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
