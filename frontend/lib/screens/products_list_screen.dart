import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../api/auth_api.dart';
import 'product_detail_screen.dart';

class ProductsListScreen extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final AuthApi authApi;

  const ProductsListScreen({
    super.key,
    required this.title,
    required this.items,
    required this.authApi,
  });

  int _toPrice(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2EC),
        title: Text(title),
      ),
      body: items.isEmpty
          ? const Center(child: Text('ยังไม่มีสินค้า'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final item = items[i];
                final name = (item['name'] ?? '-').toString();
                final unit = (item['unit'] ?? '').toString();
                final price = _toPrice(item['basePrice']);
                final thumb = _resolveThumb(item);
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(
                          item: item,
                          relatedItems: items,
                          authApi: authApi,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildAnyImage(thumb, width: 84, height: 84),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '฿$price${unit.isNotEmpty ? ' / $unit' : ''}',
                                style: const TextStyle(
                                  color: Color(0xFF395320),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _fallback() {
    return Container(
      width: 84,
      height: 84,
      color: const Color(0xFFE0E8CE),
      alignment: Alignment.center,
      child: const Text('🥗'),
    );
  }

  String? _resolveThumb(Map<String, dynamic> item) {
    final thumb = (item['thumbnailUrl'] ?? '').toString().trim();
    if (thumb.isNotEmpty) return thumb;

    final rawImages = item['images'];
    if (rawImages is List) {
      for (final e in rawImages) {
        if (e is Map && e['url'] is String) {
          final url = (e['url'] as String).trim();
          if (url.isNotEmpty) return url;
        }
      }
    }
    return null;
  }

  Widget _buildAnyImage(
    String? src, {
    required double width,
    required double height,
  }) {
    final value = (src ?? '').trim();
    if (value.isEmpty) return _fallback();

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Image.network(
        value,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    }

    if (!kIsWeb) {
      try {
        final path = value.startsWith('file://')
            ? value.replaceFirst('file://', '')
            : value;
        return Image.file(
          File(path),
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallback(),
        );
      } catch (_) {
        return _fallback();
      }
    }

    return _fallback();
  }
}
