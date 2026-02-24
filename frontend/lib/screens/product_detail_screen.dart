import 'package:flutter/material.dart';
import '../api/catalog_api.dart';
import '../api/cart_api.dart';
import '../api/auth_api.dart';
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
    catalogApi = CatalogApi(baseUrl: 'http://localhost:3000');
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

    final lots = detail?['lots'];
    if (lots is! List || lots.isEmpty) {
      _showMessage('สินค้านี้ยังไม่มีล็อตพร้อมขาย');
      return;
    }

    final firstLot = lots.first;
    final inventoryLotId =
        firstLot is Map ? firstLot['id']?.toString() : null;
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
      _showMessage('เพิ่มลงตะกร้าแล้ว');
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
                  const Text(
                    'aroiho',
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.3),
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
                                  builder: (_) => SellerDetailScreen(sellerId: sellerId),
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
    if (lots is! List || lots.isEmpty) return 'ไม่มีล็อตสินค้าที่เปิดขาย';
    final activeLots = lots.length;
    final firstQty = (lots.first as Map?)?['quantityAvailable'];
    return '✓ มีล็อตพร้อมขาย $activeLots ล็อต\n✓ คงเหลือประมาณ ${firstQty ?? '-'} หน่วย';
  }

  String _sellerCertificationSummary() {
    final certs = (detail?['seller'] as Map?)?['certifications'];
    if (certs is! List || certs.isEmpty) {
      return 'ยังไม่มีข้อมูลใบรับรองจากผู้ขาย';
    }
    return 'มีใบรับรอง ${certs.length} รายการ และผ่านการตรวจสอบล่าสุด';
  }

  String? _mainImageUrl() {
    final images = detail?['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is Map && first['url'] is String) return first['url'] as String;
    }
    return widget.item['thumbnailUrl'] as String?;
  }

  Widget _thumb(String? thumb, {required double height}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: thumb != null && thumb.isNotEmpty
          ? Image.network(
              thumb,
              height: height,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stackTrace) => _fallback(height),
            )
          : _fallback(height),
    );
  }

  Widget _fallback(double height) {
    return Container(
      height: height,
      width: double.infinity,
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
