import 'package:flutter/material.dart';
import '../api/catalog_api.dart';

class SellerDetailScreen extends StatefulWidget {
  final String sellerId;
  const SellerDetailScreen({super.key, required this.sellerId});

  @override
  State<SellerDetailScreen> createState() => _SellerDetailScreenState();
}

class _SellerDetailScreenState extends State<SellerDetailScreen> {
  late final CatalogApi catalogApi;
  Map<String, dynamic>? seller;
  List<Map<String, dynamic>> products = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    catalogApi = CatalogApi(baseUrl: 'http://localhost:3000');
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        catalogApi.getSellerInfo(widget.sellerId),
        catalogApi.listProductsBySeller(widget.sellerId),
      ]);
      if (!mounted) return;
      setState(() {
        seller = results[0] as Map<String, dynamic>;
        products = results[1] as List<Map<String, dynamic>>;
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
    final rawSellerName = (seller?['name'] ?? 'ฟาร์มลุงน้อย') as String;
    final sellerName = _displaySellerName(rawSellerName);
    final lat = seller?['lat'];
    final lng = seller?['lng'];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2EC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? _errorView()
                  : Column(
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
                              onPressed: () {},
                              icon: const Icon(Icons.shopping_cart_outlined),
                            ),
                          ],
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 190,
                            width: double.infinity,
                            color: const Color(0xFFDDE7C0),
                            alignment: Alignment.center,
                            child: const Text('🏡', style: TextStyle(fontSize: 52)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          sellerName,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Color(0xFFE5A400), size: 16),
                            const SizedBox(width: 4),
                            Text(
                              (lat != null && lng != null)
                                  ? 'พิกัดร้าน: $lat, $lng'
                                  : 'ไม่พบพิกัดร้าน',
                              style: TextStyle(color: Colors.grey.shade800, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _certTags(),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'มีสินค้าในร้าน ${products.length} รายการ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: products.isEmpty
                              ? const Center(child: Text('ร้านนี้ยังไม่มีสินค้า'))
                              : GridView.builder(
                                  itemCount: products.length,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: 0.85,
                                  ),
                                  itemBuilder: (_, i) => _productCard(products[i]),
                                ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('โหลดข้อมูลร้านไม่สำเร็จ'),
          const SizedBox(height: 6),
          Text(error ?? '-', style: const TextStyle(fontSize: 12, color: Colors.red)),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: _load, child: const Text('ลองใหม่')),
        ],
      ),
    );
  }

  List<Widget> _certTags() {
    final certs = seller?['certifications'];
    if (certs is List && certs.isNotEmpty) {
      return certs
          .take(4)
          .map((c) {
            final cert = c is Map ? c['name'] : null;
            return _Tag((cert ?? 'Certification').toString());
          })
          .toList();
    }
    return const [_Tag('ยังไม่มีใบรับรอง')];
  }

  Widget _productCard(Map<String, dynamic> item) {
    final name = (item['name'] ?? '-') as String;
    final price = _toPrice(item['basePrice']);
    final unit = (item['unit'] ?? '').toString();
    final thumb = item['thumbnailUrl'] as String?;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            blurRadius: 4,
            offset: const Offset(0, 2),
            color: Colors.black.withValues(alpha: 0.1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: thumb != null && thumb.isNotEmpty
                ? Image.network(
                    thumb,
                    height: 84,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stackTrace) => _thumbFallback(),
                  )
                : _thumbFallback(),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            '฿$price${unit.isNotEmpty ? ' / $unit' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _thumbFallback() {
    return Container(
      height: 84,
      width: double.infinity,
      color: const Color(0xFFE0E8CE),
      alignment: Alignment.center,
      child: const Text('🦐', style: TextStyle(fontSize: 28)),
    );
  }

  int _toPrice(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  String _displaySellerName(String name) {
    if (name.toLowerCase().contains('aro farm')) return 'ฟาร์มลุงน้อย';
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
