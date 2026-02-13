import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class ThaiAdmin {
  final String province;
  final List<String> districts;

  ThaiAdmin({required this.province, required this.districts});

  factory ThaiAdmin.fromJson(Map<String, dynamic> json) {
    return ThaiAdmin(
      province: json['province'] as String,
      districts: List<String>.from(json['districts'] as List),
    );
  }
}

class ThaiAdminRepository {
  static Future<List<ThaiAdmin>> load() async {
    final raw = await rootBundle.loadString('assets/thai_admin.json');
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => ThaiAdmin.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
