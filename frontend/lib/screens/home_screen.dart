import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../api/auth_api.dart';
import '../api/addresses_api.dart';
import '../api/cart_api.dart';
import '../api/catalog_api.dart';
import '../storage/profile_store.dart';
import 'address_confirm_screen.dart';
import 'cart_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'product_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final AuthApi authApi;
  const HomeScreen({super.key, required this.authApi});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tabIndex = 0;
  late final CatalogApi catalogApi;
  late final CartApi cartApi;
  late final AddressesApi addressesApi;

  bool loading = true;
  bool buyingNow = false;
  String? error;
  String locationLabel = 'Current location';
  List<Map<String, dynamic>> recommended = [];

  final categories = const [
    {'label': 'ออร์แกนิก', 'emoji': '🥬'},
    {'label': 'ของสด', 'emoji': '🦐'},
    {'label': 'โฮมเมด', 'emoji': '🍞'},
    {'label': 'อร่อยมาก!', 'emoji': '✨'},
  ];

  @override
  void initState() {
    super.initState();
    catalogApi = CatalogApi(baseUrl: 'http://localhost:3000');
    cartApi = CartApi();
    addressesApi = AddressesApi();
    _loadCurrentLocation();
    _loadProducts();
  }

  Future<void> _loadCurrentLocation() async {
    final token = widget.authApi.accessToken;
    if (token == null || token.isEmpty) return;
    try {
      final addresses = await addressesApi.listMine(accessToken: token);
      if (addresses.isEmpty) return;
      Map<String, dynamic>? selected;
      for (final a in addresses) {
        if (a['isDefault'] == true) {
          selected = a;
          break;
        }
      }
      selected ??= addresses.first;
      if (!mounted) return;
      setState(() {
        locationLabel = _addressLabel(selected!);
      });
    } catch (_) {}
  }

  Future<void> _openAddressManager() async {
    final selected = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressConfirmScreen(authApi: widget.authApi),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        locationLabel = _addressLabel(selected);
      });
    }
  }

  String _addressLabel(Map<String, dynamic> address) {
    final district = (address['district'] ?? '').toString();
    final province = (address['province'] ?? '').toString();
    final label = '$district ${province.isNotEmpty ? ', $province' : ''}'.trim();
    return label.isEmpty ? 'Current location' : label;
  }

  Future<void> _loadProducts() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      final results = await Future.wait([
        catalogApi.listProducts(page: 1, limit: 20),
        ProfileStore.loadOnboardingFoods(),
      ]);

      final items = results[0] as List<Map<String, dynamic>>;
      final foods = results[1] as List<String>;
      final ranked = _rankProductsByPreference(items, foods);

      setState(() {
        recommended = ranked;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _resetOnboardingDev() async {
    await ProfileStore.clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
  }

  void _openProduct(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          item: item,
          relatedItems: recommended,
          authApi: widget.authApi,
        ),
      ),
    );
  }

  Future<void> _buyNow(Map<String, dynamic> item) async {
    if (buyingNow) return;
    final token = widget.authApi.accessToken;
    if (token == null || token.isEmpty) {
      _showMessage('กรุณาเข้าสู่ระบบใหม่');
      return;
    }

    final productId = item['id']?.toString();
    if (productId == null || productId.isEmpty) {
      _showMessage('ไม่พบรหัสสินค้า');
      return;
    }

    setState(() => buyingNow = true);
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

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CartScreen(authApi: widget.authApi),
        ),
      );
    } catch (e) {
      _showMessage('ซื้อเลยไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => buyingNow = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2EC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProducts,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _topBar(),
                const SizedBox(height: 18),
                if (kDebugMode)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _resetOnboardingDev,
                      child: const Text('Reset Onboarding'),
                    ),
                  ),
                _sectionTitle('แนะนำสำหรับคุณวันนี้', showMore: true),
                const SizedBox(height: 10),
                if (loading) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ] else if (error != null) ...[
                  _errorBox(),
                ] else if (recommended.isEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('ยังไม่มีสินค้าในระบบ'),
                  ),
                ] else ...[
                  _recommendedStrip(),
                ],
                const SizedBox(height: 10),
                const Text(
                  'หมวดหมู่',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map((c) => _categoryChip(c)).toList(),
                ),
                const SizedBox(height: 20),
                _sectionTitle('คัดมาแล้ววันนี้', showMore: true),
                const SizedBox(height: 10),
                _highlightCard(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tabIndex,
        onTap: (i) {
          setState(() => tabIndex = i);
          if (i == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrdersScreen(authApi: widget.authApi),
              ),
            );
          }
          if (i == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CartScreen(authApi: widget.authApi),
              ),
            );
          }
          if (i == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(authApi: widget.authApi),
              ),
            );
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_outlined), label: 'Cart'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        const Text(
          'aroiho',
          style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1.5),
        ),
        const Spacer(),
        InkWell(
          onTap: _openAddressManager,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFFE5A400), size: 15),
                const SizedBox(width: 4),
                Text(
                  locationLabel,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const Icon(Icons.keyboard_arrow_down, size: 14),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, {bool showMore = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.8),
        ),
        if (showMore)
          TextButton(
            onPressed: _loadProducts,
            child: const Text('ดูเพิ่มเติม', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }

  Widget _errorBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('โหลดสินค้าไม่สำเร็จ', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: _loadProducts, child: const Text('ลองใหม่')),
        ],
      ),
    );
  }

  Widget _recommendedStrip() {
    final items = recommended.take(5).toList();
    return SizedBox(
      height: 184,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _recommendedCard(items[i]),
      ),
    );
  }

  Widget _recommendedCard(Map<String, dynamic> item) {
    final name = (item['name'] ?? '-') as String;
    final price = _toPrice(item['basePrice']);
    final unit = (item['unit'] ?? '').toString();
    final thumb = item['thumbnailUrl'] as String?;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openProduct(item),
      child: Container(
        width: 138,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
            _productThumb(thumb, height: 82, width: double.infinity, radius: 8),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const Spacer(),
            Row(
              children: [
                Text(
                  '฿$price',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    unit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFC1D75F),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'ตราสินค้า',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(Map<String, String> c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEDDD79),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${c['emoji']} ${c['label']}',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  Widget _highlightCard() {
    final item = recommended.isNotEmpty ? recommended.first : null;
    final thumb = item?['thumbnailUrl'] as String?;
    final name = (item?['name'] ?? 'ยังไม่มีสินค้าไฮไลต์') as String;
    final price = _toPrice(item?['basePrice'] ?? 0);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _productThumb(thumb, height: 170, width: double.infinity, radius: 10),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text('฿$price', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 2),
          const Text('ฟาร์มลุงน้อย', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: item == null ? null : () => _openProduct(item),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFA58B00),
                    side: const BorderSide(color: Color(0xFFE0CC67)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('ดูรายละเอียด'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: (item == null || buyingNow) ? null : () => _buyNow(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC1D75F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(buyingNow ? 'กำลังโหลด...' : 'ซื้อเลย'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _productThumb(
    String? thumb, {
    required double height,
    required double width,
    required double radius,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: thumb != null && thumb.isNotEmpty
          ? Image.network(
              thumb,
              height: height,
              width: width,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stackTrace) => _thumbFallback(height, width),
            )
          : _thumbFallback(height, width),
    );
  }

  Widget _thumbFallback(double height, double width) {
    return Container(
      height: height,
      width: width,
      color: const Color(0xFFE0E8CE),
      alignment: Alignment.center,
      child: const Text('🥗', style: TextStyle(fontSize: 36)),
    );
  }

  int _toPrice(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  List<Map<String, dynamic>> _rankProductsByPreference(
    List<Map<String, dynamic>> items,
    List<String> foods,
  ) {
    if (foods.isEmpty) return items;

    final preferredKeywords = <String>{
      for (final f in foods) ..._foodKeywords(f),
    };
    if (preferredKeywords.isEmpty) return items;

    final matched = <Map<String, dynamic>>[];
    final others = <Map<String, dynamic>>[];

    for (final item in items) {
      final haystack = '${item['name'] ?? ''} ${item['unit'] ?? ''}'.toLowerCase();
      final isMatch = preferredKeywords.any(haystack.contains);
      if (isMatch) {
        matched.add(item);
      } else {
        others.add(item);
      }
    }
    return [...matched, ...others];
  }

  Set<String> _foodKeywords(String food) {
    final normalized = food.toLowerCase();
    if (normalized.contains('ผัก') || normalized.contains('ออร์แกนิค')) {
      return {'ผัก', 'สลัด', 'คะน้า', 'กะหล่ำ', 'organic', 'vegetable', 'greens'};
    }
    if (normalized.contains('ของทะเล') || normalized.contains('กุ้ง')) {
      return {'กุ้ง', 'ปลา', 'ปู', 'หอย', 'หมึก', 'lobster', 'shrimp', 'seafood'};
    }
    if (normalized.contains('ผลไม้')) {
      return {'ผลไม้', 'แอปเปิล', 'มะม่วง', 'ส้ม', 'banana', 'apple', 'fruit'};
    }
    if (normalized.contains('โฮมเมด')) {
      return {'โฮมเมด', 'homemade', 'ขนมปัง', 'bread', 'bakery'};
    }
    if (normalized.contains('อาหารคลีน')) {
      return {'คลีน', 'clean', 'healthy', 'สุขภาพ'};
    }
    if (normalized.contains('พร้อมทาน')) {
      return {'พร้อมทาน', 'อาหาร', 'meal', 'ready'};
    }
    return {};
  }
}
