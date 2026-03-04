import 'dart:convert';
import 'package:http/http.dart' as http;

class CatalogApi {
  final String baseUrl;
  CatalogApi({required this.baseUrl});

  Future<List<Map<String, dynamic>>> listProducts({
    int page = 1,
    int limit = 20,
    String? categoryId,
    String? q,
  }) async {
    final query = <String, String>{'page': '$page', 'limit': '$limit'};
    if (categoryId != null && categoryId.isNotEmpty) {
      query['categoryId'] = categoryId;
    }
    if (q != null && q.isNotEmpty) query['q'] = q;
    final uri = Uri.parse('$baseUrl/products').replace(queryParameters: query);
    final res = await http.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );

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
    final res = await http.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Get product failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSellerInfo(String sellerId) async {
    final uri = Uri.parse('$baseUrl/sellers/$sellerId');
    final res = await http.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );

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
    final uri = Uri.parse(
      '$baseUrl/sellers/$sellerId/products?page=$page&limit=$limit',
    );
    final res = await http.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'List seller products failed: ${res.statusCode} ${res.body}',
      );
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

  Future<List<Map<String, dynamic>>> listCategories() async {
    final uri = Uri.parse('$baseUrl/categories');
    final res = await http.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('List categories failed: ${res.statusCode} ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return <Map<String, dynamic>>[];
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listMySellerProducts({
    required String accessToken,
    int page = 1,
    int limit = 30,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/v1/seller/products?page=$page&limit=$limit',
    );
    final res = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'List my seller products failed: ${res.statusCode} ${res.body}',
      );
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected seller products response shape');
    }
    final items = decoded['items'];
    if (items is! List) return <Map<String, dynamic>>[];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> getSellerDashboard({
    required String accessToken,
    int days = 7,
  }) async {
    final safeDays = [7, 14, 30].contains(days) ? days : 7;
    final uri = Uri.parse('$baseUrl/v1/seller/dashboard?days=$safeDays');
    final res = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Get seller dashboard failed: ${res.statusCode} ${res.body}',
      );
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected seller dashboard response shape');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> startPromotionCampaign({
    required String accessToken,
    required String productId,
    required String planCode,
    required int days,
    String? note,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/seller/promotions/start');
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'productId': productId,
        'planCode': planCode,
        'days': days,
        'note': note,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Start promotion failed: ${res.statusCode} ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected start promotion response shape');
    }
    return decoded;
  }

  Future<List<Map<String, dynamic>>> listMyPromotionCampaigns({
    required String accessToken,
    String? status,
  }) async {
    final query = <String, String>{};
    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim();
    }
    final uri = Uri.parse(
      '$baseUrl/v1/seller/promotions',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final res = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('List promotions failed: ${res.statusCode} ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected list promotions response shape');
    }
    final items = decoded['items'];
    if (items is! List) return <Map<String, dynamic>>[];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>?> getMySeller({
    required String accessToken,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/seller/me');
    final res = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Get my seller failed: ${res.statusCode} ${res.body}');
    }
    final body = res.body.trim();
    if (body.isEmpty || body == 'null') return null;
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded;
  }

  Future<Map<String, dynamic>> applySeller({
    required String accessToken,
    required String name,
    String? phone,
    String? addressText,
    String type = 'FARM',
    String? taxId,
    String? coverImageUrl,
    String? aboutText,
    double? lat,
    double? lng,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/seller/apply');
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'addressText': addressText,
        'type': type,
        'taxId': taxId,
        'coverImageUrl': coverImageUrl,
        'aboutText': aboutText,
        'lat': lat,
        'lng': lng,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Apply seller failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateMySeller({
    required String accessToken,
    String? name,
    String? phone,
    String? addressText,
    String? type,
    String? taxId,
    String? coverImageUrl,
    String? aboutText,
    double? lat,
    double? lng,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/seller/me');
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    if (addressText != null) body['addressText'] = addressText;
    if (type != null) body['type'] = type;
    if (taxId != null) body['taxId'] = taxId;
    if (coverImageUrl != null) body['coverImageUrl'] = coverImageUrl;
    if (aboutText != null) body['aboutText'] = aboutText;
    if (lat != null) body['lat'] = lat;
    if (lng != null) body['lng'] = lng;

    final res = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Update my seller failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createMySellerProduct({
    required String accessToken,
    required String categoryId,
    required String name,
    required String unit,
    required num basePrice,
    String? description,
    String? thumbnailUrl,
    bool isActive = true,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/seller/products');
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'categoryId': categoryId,
        'name': name,
        'unit': unit,
        'basePrice': basePrice,
        'description': description,
        'thumbnailUrl': thumbnailUrl,
        'isActive': isActive,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Create seller product failed: ${res.statusCode} ${res.body}',
      );
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateMySellerProduct({
    required String accessToken,
    required String productId,
    String? categoryId,
    String? name,
    String? unit,
    num? basePrice,
    String? description,
    String? thumbnailUrl,
    bool? isActive,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/seller/products/$productId');
    final body = <String, dynamic>{};
    if (categoryId != null) body['categoryId'] = categoryId;
    if (name != null) body['name'] = name;
    if (unit != null) body['unit'] = unit;
    if (basePrice != null) body['basePrice'] = basePrice;
    if (description != null) body['description'] = description;
    if (thumbnailUrl != null) body['thumbnailUrl'] = thumbnailUrl;
    if (isActive != null) body['isActive'] = isActive;

    final res = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Update seller product failed: ${res.statusCode} ${res.body}',
      );
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> toggleMySellerProductActive({
    required String accessToken,
    required String productId,
    required bool isActive,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/v1/seller/products/$productId/toggle-active',
    );
    final res = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'isActive': isActive}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Toggle seller product failed: ${res.statusCode} ${res.body}',
      );
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> claimMySellerProduct({
    required String accessToken,
    required String productId,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/seller/products/$productId/claim');
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Claim seller product failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listMyProductLots({
    required String accessToken,
    required String productId,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/seller/products/$productId/lots');
    final res = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'List product lots failed: ${res.statusCode} ${res.body}',
      );
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected lots response shape');
    }
    final items = decoded['items'];
    if (items is! List) return <Map<String, dynamic>>[];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> createMyProductLot({
    required String accessToken,
    required String productId,
    String? lotCode,
    String? harvestedAt,
    String? packedAt,
    String? expiresAt,
    String? recommendedConsumeBefore,
    String? storageCondition,
    required num quantityAvailable,
    String status = 'ACTIVE',
  }) async {
    final uri = Uri.parse('$baseUrl/v1/seller/products/$productId/lots');
    final body = <String, dynamic>{
      'quantityAvailable': quantityAvailable,
      'status': status,
    };
    if (lotCode != null && lotCode.trim().isNotEmpty) {
      body['lotCode'] = lotCode.trim();
    }
    if (harvestedAt != null && harvestedAt.trim().isNotEmpty) {
      body['harvestedAt'] = harvestedAt.trim();
    }
    if (packedAt != null && packedAt.trim().isNotEmpty) {
      body['packedAt'] = packedAt.trim();
    }
    if (expiresAt != null && expiresAt.trim().isNotEmpty) {
      body['expiresAt'] = expiresAt.trim();
    }
    if (recommendedConsumeBefore != null &&
        recommendedConsumeBefore.trim().isNotEmpty) {
      body['recommendedConsumeBefore'] = recommendedConsumeBefore.trim();
    }
    if (storageCondition != null && storageCondition.trim().isNotEmpty) {
      body['storageCondition'] = storageCondition.trim();
    }

    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Create product lot failed: ${res.statusCode} ${res.body}',
      );
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateMyLot({
    required String accessToken,
    required String lotId,
    String? lotCode,
    String? harvestedAt,
    String? packedAt,
    String? expiresAt,
    String? recommendedConsumeBefore,
    String? storageCondition,
    num? quantityAvailable,
    String? status,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/seller/lots/$lotId');
    final body = <String, dynamic>{};
    if (lotCode != null) body['lotCode'] = lotCode.trim();
    if (harvestedAt != null) {
      body['harvestedAt'] = harvestedAt.trim().isEmpty
          ? null
          : harvestedAt.trim();
    }
    if (packedAt != null) {
      body['packedAt'] = packedAt.trim().isEmpty ? null : packedAt.trim();
    }
    if (expiresAt != null) {
      body['expiresAt'] = expiresAt.trim().isEmpty ? null : expiresAt.trim();
    }
    if (recommendedConsumeBefore != null) {
      body['recommendedConsumeBefore'] = recommendedConsumeBefore.trim().isEmpty
          ? null
          : recommendedConsumeBefore.trim();
    }
    if (storageCondition != null) {
      body['storageCondition'] = storageCondition.trim().isEmpty
          ? null
          : storageCondition.trim();
    }
    if (quantityAvailable != null) {
      body['quantityAvailable'] = quantityAvailable;
    }
    if (status != null) body['status'] = status;

    final res = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Update lot failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
