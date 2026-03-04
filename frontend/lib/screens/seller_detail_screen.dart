import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../api/auth_api.dart';
import '../api/catalog_api.dart';
import '../config/app_config.dart';
import 'seller_products_screen.dart';

class SellerDetailScreen extends StatefulWidget {
  final String sellerId;
  final AuthApi? authApi;
  const SellerDetailScreen({super.key, required this.sellerId, this.authApi});

  @override
  State<SellerDetailScreen> createState() => _SellerDetailScreenState();
}

class _SellerDetailScreenState extends State<SellerDetailScreen> {
  late final CatalogApi catalogApi;
  Map<String, dynamic>? seller;
  List<Map<String, dynamic>> products = [];
  bool loading = true;
  String? error;
  bool isMySeller = false;

  @override
  void initState() {
    super.initState();
    catalogApi = CatalogApi(baseUrl: AppConfig.baseUrl);
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        catalogApi.getSellerInfo(widget.sellerId),
        catalogApi.listProductsBySeller(widget.sellerId),
      ]);

      var mySeller = false;
      final token = widget.authApi?.accessToken;
      if (token != null && token.isNotEmpty) {
        try {
          final mine = await catalogApi.getMySeller(accessToken: token);
          mySeller = (mine?['id'] ?? '').toString() == widget.sellerId;
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        seller = results[0] as Map<String, dynamic>;
        products = results[1] as List<Map<String, dynamic>>;
        isMySeller = mySeller;
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
    final address = (seller?['addressText'] ?? '').toString();
    final about = (seller?['aboutText'] ?? '').toString();
    final coverImageUrl = (seller?['coverImageUrl'] ?? '').toString();

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
                              onPressed: () {},
                              icon: const Icon(Icons.shopping_cart_outlined),
                            ),
                          ],
                        ),
                        _coverSection(coverImageUrl),
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
                        if (address.isNotEmpty)
                          Text(
                            address,
                            style: TextStyle(color: Colors.grey.shade800, fontSize: 12),
                          ),
                        if (about.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            about,
                            style: TextStyle(color: Colors.grey.shade800, fontSize: 12, height: 1.4),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _certTags(),
                        ),
                        const SizedBox(height: 10),
                        if (isMySeller && widget.authApi != null) ...[
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SellerProductsScreen(
                                          authApi: widget.authApi!,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.inventory_2_outlined),
                                  label: const Text('จัดการสินค้า'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _openEditShopDialog,
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('แก้ไขหน้าร้าน'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
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

  Future<void> _openEditShopDialog() async {
    final token = widget.authApi?.accessToken;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อน')),
      );
      return;
    }

    final nameCtl = TextEditingController(text: (seller?['name'] ?? '').toString());
    final phoneCtl = TextEditingController(text: (seller?['phone'] ?? '').toString());
    final addressCtl = TextEditingController(text: (seller?['addressText'] ?? '').toString());
    final aboutCtl = TextEditingController(text: (seller?['aboutText'] ?? '').toString());
    final imageCtl = TextEditingController(text: (seller?['coverImageUrl'] ?? '').toString());
    final latCtl = TextEditingController(text: _toDoubleString(seller?['lat']));
    final lngCtl = TextEditingController(text: _toDoubleString(seller?['lng']));
    String? localError;
    bool saving = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('แก้ไขหน้าร้าน'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'ชื่อร้าน *')),
                const SizedBox(height: 8),
                TextField(controller: phoneCtl, decoration: const InputDecoration(labelText: 'เบอร์ติดต่อร้าน')),
                const SizedBox(height: 8),
                TextField(controller: addressCtl, decoration: const InputDecoration(labelText: 'ที่อยู่ร้าน')),
                const SizedBox(height: 8),
                TextField(controller: imageCtl, decoration: const InputDecoration(labelText: 'URL รูปร้าน')),
                const SizedBox(height: 8),
                TextField(
                  controller: aboutCtl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'รายละเอียดร้าน'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latCtl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(labelText: 'ละติจูด'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: lngCtl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(labelText: 'ลองจิจูด'),
                      ),
                    ),
                  ],
                ),
                if (localError != null) ...[
                  const SizedBox(height: 8),
                  Text(localError!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (nameCtl.text.trim().isEmpty) {
                        setLocal(() => localError = 'กรุณากรอกชื่อร้าน');
                        return;
                      }
                      final lat = latCtl.text.trim().isEmpty ? null : double.tryParse(latCtl.text.trim());
                      final lng = lngCtl.text.trim().isEmpty ? null : double.tryParse(lngCtl.text.trim());
                      if ((latCtl.text.trim().isNotEmpty && lat == null) ||
                          (lngCtl.text.trim().isNotEmpty && lng == null)) {
                        setLocal(() => localError = 'พิกัดไม่ถูกต้อง');
                        return;
                      }

                      setLocal(() {
                        saving = true;
                        localError = null;
                      });
                      try {
                        await catalogApi.updateMySeller(
                          accessToken: token,
                          name: nameCtl.text.trim(),
                          phone: phoneCtl.text.trim(),
                          addressText: addressCtl.text.trim(),
                          coverImageUrl: imageCtl.text.trim(),
                          aboutText: aboutCtl.text.trim(),
                          lat: lat,
                          lng: lng,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx, true);
                      } catch (e) {
                        setLocal(() {
                          saving = false;
                          localError = e.toString();
                        });
                      }
                    },
              child: Text(saving ? 'กำลังบันทึก...' : 'บันทึก'),
            ),
          ],
        ),
      ),
    );

    nameCtl.dispose();
    phoneCtl.dispose();
    addressCtl.dispose();
    aboutCtl.dispose();
    imageCtl.dispose();
    latCtl.dispose();
    lngCtl.dispose();

    if (saved == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('อัปเดตหน้าร้านแล้ว')),
      );
    }
  }

  Widget _coverSection(String coverImageUrl) {
    final src = coverImageUrl.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: src.isNotEmpty
          ? _coverImage(src)
          : _coverFallback(),
    );
  }

  Widget _coverImage(String src) {
    final lower = src.toLowerCase();
    final isUrl = lower.startsWith('http://') || lower.startsWith('https://');
    if (isUrl) {
      return Image.network(
        src,
        height: 190,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _coverFallback(),
      );
    }
    if (!kIsWeb) {
      final path = src.startsWith('file://') ? src.replaceFirst('file://', '') : src;
      return Image.file(
        File(path),
        height: 190,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _coverFallback(),
      );
    }
    return _coverFallback();
  }

  Widget _coverFallback() {
    return Container(
      height: 190,
      width: double.infinity,
      color: const Color(0xFFDDE7C0),
      alignment: Alignment.center,
      child: const Text('🏡', style: TextStyle(fontSize: 52)),
    );
  }

  String _toDoubleString(dynamic v) {
    if (v == null) return '';
    if (v is num) return v.toString();
    return v.toString();
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
