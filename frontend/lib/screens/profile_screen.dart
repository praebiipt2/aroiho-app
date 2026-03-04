import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../api/auth_api.dart';
import '../api/catalog_api.dart';
import '../config/app_config.dart';
import '../storage/profile_store.dart';
import 'address_confirm_screen.dart';
import 'orders_screen.dart';
import 'seller_apply_screen.dart';
import 'seller_dashboard_screen.dart';
import 'seller_storefront_editor_screen.dart';
import 'seller_products_screen.dart';

class ProfileScreen extends StatefulWidget {
  final AuthApi authApi;
  const ProfileScreen({super.key, required this.authApi});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final CatalogApi _catalogApi;
  bool loading = true;
  String? error;
  String name = '-';
  String email = '-';
  String phone = '-';
  String province = '';
  String district = '';
  String address = '';
  bool marketingNoti = true;
  bool orderNoti = true;
  bool hasSeller = false;
  String? sellerName;

  @override
  void initState() {
    super.initState();
    _catalogApi = CatalogApi(baseUrl: AppConfig.baseUrl);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final local = await ProfileStore.load();
      Map<String, dynamic>? me;
      try {
        me = await widget.authApi.me();
      } catch (_) {}

      if (!mounted) return;
      String? currentSellerName;
      var currentHasSeller = false;
      final token = widget.authApi.accessToken;
      if (token != null && token.isNotEmpty) {
        try {
          final seller = await _catalogApi.getMySeller(accessToken: token);
          if (seller != null) {
            currentHasSeller = true;
            currentSellerName = (seller['name'] ?? '').toString();
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        name = (me?['displayName'] ?? local['name'] ?? '-').toString();
        email = (me?['email'] ?? local['email'] ?? '-').toString();
        phone = (me?['phone'] ?? local['phone'] ?? '-').toString();
        province = (local['province'] ?? '').toString();
        district = (local['district'] ?? '').toString();
        address = (local['address'] ?? '').toString();
        hasSeller = currentHasSeller;
        sellerName = currentSellerName;
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

  Future<void> _openSellerCenter() async {
    final token = widget.authApi.accessToken;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อน')));
      return;
    }

    try {
      final seller = await _catalogApi.getMySeller(accessToken: token);
      if (!mounted) return;

      if (seller != null) {
        await _openSellerManageMenu();
      } else {
        final created = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => SellerApplyScreen(authApi: widget.authApi),
          ),
        );
        if (created == true && mounted) {
          await _load();
          if (!mounted) return;
          await _openSellerManageMenu();
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เปิดเมนูร้านค้าไม่สำเร็จ: $e')));
    }
  }

  Future<void> _openSellerManageMenu() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'จัดการร้านค้า',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.insights_outlined),
                  title: const Text('แดชบอร์ดร้านค้า'),
                  subtitle: const Text('ยอดขาย ออเดอร์ และสต็อกสำคัญ'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SellerDashboardScreen(authApi: widget.authApi),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('จัดการสินค้า'),
                  subtitle: const Text('เพิ่ม แก้ไข เปิด/ปิดขาย'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SellerProductsScreen(authApi: widget.authApi),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.add_business_outlined),
                  title: const Text('รับสินค้าเข้าร้าน'),
                  subtitle: const Text('ใช้รหัสสินค้าเพื่อเคลมเข้าร้านนี้'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _claimProductToMySeller();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: const Text('ตกแต่งหน้าร้าน'),
                  subtitle: const Text('รูปหน้าร้าน โลเคชั่น และรายละเอียดร้าน'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SellerStorefrontEditorScreen(
                          authApi: widget.authApi,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _claimProductToMySeller() async {
    final token = widget.authApi.accessToken;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อน')));
      return;
    }

    final ctl = TextEditingController();
    bool claiming = false;
    String? localError;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('รับสินค้าเข้าร้าน'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ใส่รหัสสินค้า (productId)',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctl,
                decoration: const InputDecoration(
                  hintText: 'เช่น 31a8024e-0d2a-4247-a9a3-9629a18607c8',
                ),
              ),
              if (localError != null) ...[
                const SizedBox(height: 8),
                Text(
                  localError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: claiming ? null : () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: claiming
                  ? null
                  : () async {
                      final productId = ctl.text.trim();
                      if (productId.isEmpty) {
                        setLocal(() => localError = 'กรุณากรอกรหัสสินค้า');
                        return;
                      }
                      setLocal(() {
                        localError = null;
                        claiming = true;
                      });

                      try {
                        await _catalogApi.claimMySellerProduct(
                          accessToken: token,
                          productId: productId,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx, true);
                      } catch (e) {
                        setLocal(() {
                          claiming = false;
                          localError = 'เคลมไม่สำเร็จ: $e';
                        });
                      }
                    },
              child: Text(claiming ? 'กำลังเคลม...' : 'ยืนยัน'),
            ),
          ],
        ),
      ),
    );

    ctl.dispose();
    if (submitted == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('รับสินค้าเข้าร้านแล้ว')));
    }
  }

  Future<void> _logout() async {
    widget.authApi.accessToken = null;
    widget.authApi.refreshToken = null;
    await ProfileStore.clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
  }

  Future<void> _resetOnboardingDev() async {
    await ProfileStore.clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
  }

  Future<void> _openAddressManager() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddressConfirmScreen(authApi: widget.authApi),
      ),
    );
  }

  Future<void> _editProfile() async {
    final nameCtl = TextEditingController(text: name == '-' ? '' : name);
    final emailCtl = TextEditingController(text: email == '-' ? '' : email);
    final provinceCtl = TextEditingController(text: province);
    final districtCtl = TextEditingController(text: district);
    final addressCtl = TextEditingController(text: address);
    String? localError;
    bool saving = false;
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('แก้ไขข้อมูลส่วนตัว'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtl,
                  decoration: const InputDecoration(labelText: 'ชื่อแสดงผล'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailCtl,
                  decoration: const InputDecoration(labelText: 'อีเมล'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: provinceCtl,
                  decoration: const InputDecoration(labelText: 'จังหวัด'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: districtCtl,
                  decoration: const InputDecoration(labelText: 'อำเภอ/เขต'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: addressCtl,
                  decoration: const InputDecoration(labelText: 'ที่อยู่'),
                ),
                if (localError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    localError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
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
                      final name = nameCtl.text.trim();
                      final email = emailCtl.text.trim();
                      if (name.isEmpty) {
                        setLocal(() => localError = 'กรุณากรอกชื่อ');
                        return;
                      }
                      if (email.isNotEmpty && !emailRegex.hasMatch(email)) {
                        setLocal(() => localError = 'รูปแบบอีเมลไม่ถูกต้อง');
                        return;
                      }
                      setLocal(() {
                        saving = true;
                        localError = null;
                      });
                      try {
                        await widget.authApi.updateMe(
                          displayName: name,
                          email: email.isEmpty ? null : email,
                          province: provinceCtl.text.trim().isEmpty
                              ? null
                              : provinceCtl.text.trim(),
                          district: districtCtl.text.trim().isEmpty
                              ? null
                              : districtCtl.text.trim(),
                          addressLine1: addressCtl.text.trim().isEmpty
                              ? null
                              : addressCtl.text.trim(),
                        );
                        await ProfileStore.save(
                          name: name,
                          email: email,
                          phone: phone == '-' ? '' : phone,
                          province: provinceCtl.text.trim(),
                          district: districtCtl.text.trim(),
                          address: addressCtl.text.trim(),
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
    emailCtl.dispose();
    provinceCtl.dispose();
    districtCtl.dispose();
    addressCtl.dispose();

    if (saved == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('บันทึกข้อมูลแล้ว')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2EC),
        title: const Text('โปรไฟล์'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error!))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFFC1D75F),
                        child: Text(
                          (name.isNotEmpty && name != '-')
                              ? name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email,
                              style: const TextStyle(color: Colors.black54),
                            ),
                            Text(
                              'โทร: $phone',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _editProfile,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _menuSection('บัญชีของฉัน', [
                  _menuTile(
                    icon: Icons.person_outline,
                    title: 'ข้อมูลส่วนตัว',
                    subtitle: 'ชื่อ อีเมล เบอร์โทร และที่อยู่',
                    onTap: _editProfile,
                  ),
                  _menuTile(
                    icon: Icons.location_on_outlined,
                    title: 'ที่อยู่จัดส่ง',
                    subtitle: (district.isNotEmpty || province.isNotEmpty)
                        ? '$district${district.isNotEmpty && province.isNotEmpty ? ', ' : ''}$province'
                        : 'เพิ่มหรือแก้ไขที่อยู่',
                    onTap: _openAddressManager,
                  ),
                  _menuTile(
                    icon: Icons.receipt_long_outlined,
                    title: 'ประวัติคำสั่งซื้อ',
                    subtitle: 'ดูรายการสั่งซื้อย้อนหลัง',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrdersScreen(authApi: widget.authApi),
                      ),
                    ),
                  ),
                  _menuTile(
                    icon: Icons.storefront_outlined,
                    title: hasSeller ? 'จัดการร้านค้า' : 'เปิดบัญชีร้านค้า',
                    subtitle: hasSeller
                        ? 'ร้าน ${sellerName?.isNotEmpty == true ? sellerName : 'ของฉัน'} • สินค้าและหน้าร้าน'
                        : 'เปิดร้านด้วยบัญชีนี้ได้ทันที',
                    onTap: _openSellerCenter,
                  ),
                ]),
                const SizedBox(height: 12),
                _menuSection('การตั้งค่า', [
                  SwitchListTile(
                    value: orderNoti,
                    onChanged: (v) => setState(() => orderNoti = v),
                    title: const Text('แจ้งเตือนคำสั่งซื้อ'),
                    subtitle: const Text('อัปเดตสถานะคำสั่งซื้อและการจัดส่ง'),
                    secondary: const Icon(Icons.notifications_active_outlined),
                  ),
                  SwitchListTile(
                    value: marketingNoti,
                    onChanged: (v) => setState(() => marketingNoti = v),
                    title: const Text('แจ้งเตือนโปรโมชัน'),
                    subtitle: const Text('ดีลพิเศษและคูปองส่วนลด'),
                    secondary: const Icon(Icons.local_offer_outlined),
                  ),
                  _menuTile(
                    icon: Icons.lock_outline,
                    title: 'ความปลอดภัย',
                    subtitle: 'จัดการการเข้าสู่ระบบ',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('ฟีเจอร์ความปลอดภัยจะเพิ่มในขั้นถัดไป'),
                      ),
                    ),
                  ),
                  _menuTile(
                    icon: Icons.help_outline,
                    title: 'ช่วยเหลือและติดต่อ',
                    subtitle: 'FAQ และช่องทางติดต่อ',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('หน้าช่วยเหลือจะเพิ่มในขั้นถัดไป'),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                if (kDebugMode) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _resetOnboardingDev,
                      child: const Text('Reset Onboarding (DEV)'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _load,
                    child: const Text('รีเฟรชข้อมูล'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('ออกจากระบบ'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _menuSection(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
