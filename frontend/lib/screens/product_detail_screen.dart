import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/catalog_api.dart';
import '../api/cart_api.dart';
import '../api/auth_api.dart';
import '../config/app_config.dart';
import 'cart_screen.dart';
import 'seller_detail_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> relatedItems;
  final AuthApi authApi;

  const ProductDetailScreen({
    super.key,
    required this.item,
    required this.relatedItems,
    required this.authApi,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final CatalogApi catalogApi;
  late final CartApi cartApi;
  Map<String, dynamic>? detail;
  bool loading = true;
  bool addingToCart = false;
  String? error;

  @override
  void initState() {
    super.initState();
    catalogApi = CatalogApi(baseUrl: AppConfig.baseUrl);
    cartApi = CartApi();
    _loadDetail();
  }

  Future<void> _addToCart({required bool buyNow}) async {
    if (addingToCart) return;

    final token = widget.authApi.accessToken;
    if (token == null || token.isEmpty) {
      _showMessage('กรุณาเข้าสู่ระบบใหม่');
      return;
    }

    final productId = detail?['id']?.toString() ?? widget.item['id']?.toString();
    if (productId == null || productId.isEmpty) {
      _showMessage('ไม่พบข้อมูลสินค้า');
      return;
    }

    final lots = _extractLots(detail?['lots']);
    if (lots.isEmpty) {
      _showMessage('สินค้านี้ยังไม่มีล็อตพร้อมขาย');
      return;
    }

    final selectedLot = await _showLotPickerDialog(lots);
    if (selectedLot == null) return;

    final inventoryLotId = selectedLot['id']?.toString();
    if (inventoryLotId == null || inventoryLotId.isEmpty) {
      _showMessage('ไม่พบ inventory lot');
      return;
    }

    setState(() => addingToCart = true);
    try {
      await cartApi.addItem(
        accessToken: token,
        productId: productId,
        inventoryLotId: inventoryLotId,
        quantity: 1,
      );
      if (!mounted) return;
      final lotCode = (selectedLot['lotCode'] ?? '').toString();
      _showMessage(
        lotCode.isEmpty ? 'เพิ่มลงตะกร้าแล้ว' : 'เพิ่มลงตะกร้าแล้ว (ล็อต $lotCode)',
      );
      if (buyNow) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CartScreen(authApi: widget.authApi),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('เพิ่มลงตะกร้าไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => addingToCart = false);
    }
  }

  List<Map<String, dynamic>> _extractLots(dynamic rawLots) {
    if (rawLots is! List) return <Map<String, dynamic>>[];
    return rawLots
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => (e['id'] ?? '').toString().isNotEmpty)
        .toList();
  }

  Future<Map<String, dynamic>?> _showLotPickerDialog(
    List<Map<String, dynamic>> lots,
  ) async {
    var selectedIndex = 0;
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('เลือกลอตที่จะสั่งซื้อ'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(lots.length, (i) {
                  final lot = lots[i];
                  final lotCode = (lot['lotCode'] ?? '-').toString();
                  final qty = _formatQuantity(lot['quantityAvailable']) ?? '-';
                  final expiresAt = _formatDateThaiShort(
                    lot['expiresAt']?.toString(),
                  );
                  final subtitle = expiresAt == null
                      ? 'คงเหลือ $qty หน่วย'
                      : 'คงเหลือ $qty หน่วย • หมดอายุ $expiresAt';
                  final selected = selectedIndex == i;
                  return ListTile(
                    onTap: () => setLocal(() => selectedIndex = i),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: selected ? Theme.of(context).primaryColor : Colors.grey,
                    ),
                    title: Text(lotCode, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(subtitle),
                  );
                }),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, lots[selectedIndex]),
              child: const Text('ยืนยัน'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadDetail() async {
    final productId = widget.item['id']?.toString();
    if (productId == null || productId.isEmpty) {
      setState(() {
        loading = false;
        error = 'ไม่พบ product id';
      });
      return;
    }

    try {
      final data = await catalogApi.getProductDetail(productId);
      if (!mounted) return;
      setState(() {
        detail = data;
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

  @override
  Widget build(BuildContext context) {
    final name = (detail?['name'] ?? widget.item['name'] ?? '-') as String;
    final price = _toPrice(detail?['basePrice'] ?? widget.item['basePrice']);
    final productId = (detail?['id'] ?? widget.item['id'] ?? '').toString();
    final thumb = _mainImageUrl();
    final seller = detail?['seller'] as Map<String, dynamic>?;
    final sellerId = (seller?['id'] ?? widget.item['sellerId'])?.toString();
    final rawSellerName = (seller?['name'] ?? 'ฟาร์มลุงน้อย') as String;
    final sellerName = _displaySellerName(rawSellerName);
    final unit = (detail?['unit'] ?? widget.item['unit'] ?? '') as String;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2EC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  SizedBox(
                    height: 40,
                    width: 130,
                    child: ClipRect(
                                child: Transform.scale(
                        scale: 3.5,
                        alignment: Alignment.centerLeft,
                        child: Image.asset(
                          'assets/logo/aroiho_logo.png',
                          fit: BoxFit.contain,
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CartScreen(authApi: widget.authApi),
                        ),
                      );
                    },
                    icon: const Icon(Icons.shopping_cart_outlined),
                  ),
                ],
              ),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : error != null
                        ? _errorBox()
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _thumb(thumb, height: 190),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '฿$price',
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'ราคา ฿$price ${unit.isNotEmpty ? '/ $unit' : ''}',
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(Icons.storefront, color: Color(0xFFE5A400), size: 16),
                                    const SizedBox(width: 4),
                                    Text(sellerName, style: TextStyle(color: Colors.grey.shade800, fontSize: 12)),
                                  ],
                                ),
                                if (productId.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'รหัสสินค้า: $productId',
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          await Clipboard.setData(
                                            ClipboardData(text: productId),
                                          );
                                          if (!mounted) return;
                                          _showMessage('คัดลอกรหัสสินค้าแล้ว');
                                        },
                                        child: const Text('คัดลอก'),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _buildTags(),
                                ),
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 12),
                                const Text('เกี่ยวกับสินค้า', style: TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 8),
                                Text(
                                  (detail?['description'] ?? 'ไม่มีรายละเอียดเพิ่มเติม').toString(),
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.5),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _lotSummary(),
                                  style: const TextStyle(fontSize: 13, height: 1.5),
                                ),
                                const SizedBox(height: 14),
                                const Text('ฟาร์มรับรอง', style: TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 8),
                                Text(
                                  _sellerCertificationSummary(),
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.5),
                                ),
                                const SizedBox(height: 12),
                                if (widget.relatedItems.isNotEmpty) ...[
                                  const Text('สินค้าแนะนำ', style: TextStyle(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 150,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: widget.relatedItems.take(4).length,
                                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                                      itemBuilder: (_, i) => _miniCard(widget.relatedItems[i]),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: sellerId == null || sellerId.isEmpty
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SellerDetailScreen(
                                    sellerId: sellerId,
                                    authApi: widget.authApi,
                                  ),
                                ),
                              );
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFA58B00),
                        side: const BorderSide(color: Color(0xFFE0CC67)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('ดูร้านค้า'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: addingToCart ? null : () => _addToCart(buyNow: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC1D75F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(addingToCart ? 'กำลังเพิ่ม...' : 'เพิ่มลงตะกร้า'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorBox() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('โหลดรายละเอียดสินค้าไม่สำเร็จ'),
          const SizedBox(height: 6),
          Text(error ?? '-', style: const TextStyle(fontSize: 12, color: Colors.red)),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: _loadDetail, child: const Text('ลองใหม่')),
        ],
      ),
    );
  }

  List<Widget> _buildTags() {
    final rawTags = detail?['tags'];
    if (rawTags is List && rawTags.isNotEmpty) {
      return rawTags.take(4).map((e) => _Tag(e.toString())).toList();
    }
    return const [_Tag('ไม่มีแท็กสินค้า')];
  }

  String _lotSummary() {
    final lots = detail?['lots'];
    if (lots is! List || lots.isEmpty) {
      return 'ยังไม่มีสต็อกล็อตที่เปิดขายในตอนนี้\n(เพิ่มสินค้าแล้ว ต้องตั้งล็อตสต็อกก่อนจึงจะซื้อได้)';
    }
    final activeLots = lots.length;
    final firstLot = lots.first as Map?;
    final firstQty = _formatQuantity(firstLot?['quantityAvailable']);
    final expiresAt = firstLot?['expiresAt']?.toString();
    final formattedExpire = _formatDateThaiShort(expiresAt);
    final expireText = formattedExpire != null
        ? '\n✓ ล็อตล่าสุดหมดอายุ: $formattedExpire'
        : '';
    return '✓ มีล็อตพร้อมขาย $activeLots ล็อต\n✓ คงเหลือประมาณ ${firstQty ?? '-'} หน่วย$expireText';
  }

  String? _formatDateThaiShort(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) return null;
    final local = parsed.toLocal();
    const months = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.'
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  String? _formatQuantity(dynamic value) {
    if (value == null) return null;
    final numValue = value is num ? value : num.tryParse(value.toString());
    if (numValue == null) return null;
    if (numValue == numValue.roundToDouble()) {
      return numValue.toInt().toString();
    }
    return numValue.toString();
  }

  String _sellerCertificationSummary() {
    final certs = (detail?['seller'] as Map?)?['certifications'];
    if (certs is! List || certs.isEmpty) {
      return 'ร้านค้ายังไม่ได้อัปโหลดใบรับรอง';
    }
    final names = certs
        .whereType<Map>()
        .map((e) => (e['name'] ?? e['code'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toList();
    if (names.isEmpty) return 'มีใบรับรอง ${certs.length} รายการ';
    return 'มีใบรับรอง ${certs.length} รายการ: ${names.take(3).join(', ')}';
  }

  String? _mainImageUrl() {
    final detailThumb = (detail?['thumbnailUrl'] ?? '').toString().trim();
    if (detailThumb.isNotEmpty) return detailThumb;

    final itemThumb = (widget.item['thumbnailUrl'] ?? '').toString().trim();
    if (itemThumb.isNotEmpty) return itemThumb;

    final images = detail?['images'];
    if (images is List && images.isNotEmpty) {
      for (final raw in images) {
        if (raw is Map && raw['url'] is String) {
          final url = (raw['url'] as String).trim();
          if (url.isNotEmpty) return url;
        }
      }
    }

    return null;
  }

  Widget _thumb(String? thumb, {required double height}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: _buildAnyImage(thumb, height: height, width: double.infinity),
    );
  }

  Widget _buildAnyImage(
    String? src, {
    required double height,
    required double width,
  }) {
    final value = (src ?? '').trim();
    if (value.isEmpty) return _fallback(height, width: width);

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Image.network(
        value,
        height: height,
        width: width,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _fallback(height, width: width),
      );
    }

    if (!kIsWeb) {
      try {
        final path = value.startsWith('file://')
            ? value.replaceFirst('file://', '')
            : value;
        return Image.file(
          File(path),
          height: height,
          width: width,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _fallback(height, width: width),
        );
      } catch (_) {
        return _fallback(height, width: width);
      }
    }

    return _fallback(height, width: width);
  }

  Widget _fallback(double height, {double width = double.infinity}) {
    return Container(
      height: height,
      width: width,
      alignment: Alignment.center,
      color: const Color(0xFFE0E8CE),
      child: const Text('🦐', style: TextStyle(fontSize: 44)),
    );
  }

  Widget _miniCard(Map<String, dynamic> p) {
    final name = (p['name'] ?? '-') as String;
    final price = _toPrice(p['basePrice'] ?? 0);
    final thumb = p['thumbnailUrl'] as String?;
    final unit = (p['unit'] ?? '').toString();
    return Container(
      width: 140,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            blurRadius: 5,
            offset: const Offset(0, 2),
            color: Colors.black.withValues(alpha: 0.12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _thumb(thumb, height: 74),
          const SizedBox(height: 5),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          Row(
            children: [
              Text('฿$price', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(unit, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _toPrice(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  String _displaySellerName(String name) {
    if (name.toLowerCase().contains('aroi farm')) return 'ฟาร์มลุงน้อย';
    return name;
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F0BC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
