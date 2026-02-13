// lib/api/auth_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class AuthApi {
  String? accessToken;
  String? refreshToken;

  Uri _u(String path) => Uri.parse('${AppConfig.baseUrl}$path');

  Future<String> requestOtp(String phone) async {
    final res = await http.post(
      _u('/auth/request-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );
    final data = jsonDecode(res.body);

    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('requestOtp failed: ${res.statusCode} ${res.body}');
    }
    return data['requestId'] as String;
  }

  Future<void> verifyOtp({
    required String phone,
    required String otp,
    required String requestId,
  }) async {
    final res = await http.post(
      _u('/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'otp': otp, 'requestId': requestId}),
    );

    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('verifyOtp failed: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body);
    accessToken = data['accessToken'];
    refreshToken = data['refreshToken'];
  }

  Future<Map<String, dynamic>> me() async {
    final token = accessToken;
    if (token == null) throw Exception('No accessToken. Please verifyOtp first.');

    final res = await http.get(
      _u('/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw Exception('me failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateMe({
    required String displayName,
    required String email,
    String? province,
    String? district,
    String? addressLine1,
  }) async {
    final token = accessToken;
    if (token == null) throw Exception('No accessToken. Please verifyOtp first.');

    final body = <String, dynamic>{
      'displayName': displayName,
      'email': email,
    };

    if (province != null) body['province'] = province;
    if (district != null) body['district'] = district;
    if (addressLine1 != null) body['addressLine1'] = addressLine1;

    final res = await http.patch(
      _u('/users/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw Exception('updateMe failed: ${res.statusCode} ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}