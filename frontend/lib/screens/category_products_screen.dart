import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../api/auth_api.dart';
import '../api/cart_api.dart';
import '../api/catalog_api.dart';
import 'product_detail_screen.dart';

class CategoryProductsScreen extends StatefulWidget {
  final AuthApi authApi;
  final String? categoryId;
  final String categoryLabel;

  const CategoryProductsScreen({
    super.key,
    required this.authApi,
    required this.categoryId,
    required this.categoryLabel,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  late final CatalogApi catalogApi;
  late final CartApi cartApi;
  final Set<String> addingIds = {};
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    catalogApi = CatalogApi(baseUrl: 'http://localhost:3000');
    cartApi = CartApi();
    _loadByCategory();
  }

  Future<void> _loadByCategory() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await catalogApi.listProducts(
        categoryId: (widget.categoryId == null || widget.categoryId!.isEmpty)
            ? null
            : widget.categoryId,
        q: (widget.categoryId == null || widget.categoryId!.isEmpty)
            ? widget.categoryLabel
            : null,
        page: 1,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        items = loaded;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  int _toPrice(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  Future<void> _addToCart(Map<String, dynamic> item) async {
    final token = widget.authApi.accessToken;
    if (token == null || token.isEmpty) {
      _showMessage('กรุณาเข้าสู่ระบบใหม่');
      return;
    }

    final productId = item['id']?.toString();
    if (productId == null || productId.isEmpty) {
      _showMessage('ไม่พบข้อมูลสินค้า');
      return;
    }
    if (addingIds.contains(productId)) return;

    setState(() => addingIds.add(productId));
    try {
      final detail = await catalogApi.getProductDetail(productId);
      final lots = detail['lots'];
      if (lots is! List || lots.isEmpty) {
        _showMessage('สินค้านี้ยังไม่มีล็อตพร้อมขาย');
        return;
      }
      final firstLot = lots.first;
      final lotId = firstLot is Map ? firstLot['id']?.toString() : null;
      if (lotId == null || lotId.isEmpty) {
        _showMessage('ไม่พบ inventory lot');
        return;
      }

      await cartApi.addItem(
        accessToken: token,
        productId: productId,
        inventoryLotId: lotId,
        quantity: 1,
      );
      _showMessage('เพิ่มลงตะกร้าแล้ว');
    } catch (e) {
      _showMessage('เพิ่มลงตะกร้าไม่สำเร็จ: $e');
    } finally {
      if (mounted) {
        setState(() => addingIds.remove(productId));
      }
    }
  }

  void _openProduct(Map<String, dynamic> item, List<Map<String, dynamic>> items) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          item: item,
          relatedItems: items,
          authApi: widget.authApi,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2EC),
        title: Text('หมวด: ${widget.categoryLabel}'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : items.isEmpty
          ? const Center(child: Text('ยังไม่มีสินค้าในหมวดนี้'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final item = items[i];
                final productId = (item['id'] ?? '').toString();
                final isAdding = addingIds.contains(productId);
                final name = (item['name'] ?? '-').toString();
                final price = _toPrice(item['basePrice']);
                final unit = (item['unit'] ?? '').toString();
                final thumb = _resolveThumb(item);
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openProduct(item, items),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                          color: Colors.black.withValues(alpha: 0.07),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildAnyImage(
                            thumb,
                            width: double.infinity,
                            height: 150,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '฿$price${unit.isEmpty ? '' : ' / $unit'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF395320),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _openProduct(item, items),
                                child: const Text('ดูรายละเอียด'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isAdding ? null : () => _addToCart(item),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFC1D75F),
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(isAdding ? 'กำลังเพิ่ม...' : 'เพิ่มลงตะกร้า'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _fallbackThumb() {
    return Container(
      width: double.infinity,
      height: 150,
      color: const Color(0xFFE0E8CE),
      alignment: Alignment.center,
      child: const Text('🥗', style: TextStyle(fontSize: 42)),
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
    if (value.isEmpty) return _fallbackThumb();

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Image.network(
        value,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallbackThumb(),
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
          errorBuilder: (context, error, stackTrace) => _fallbackThumb(),
        );
      } catch (_) {
        return _fallbackThumb();
      }
    }

    return _fallbackThumb();
  }
}
