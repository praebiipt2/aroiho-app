import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../api/auth_api.dart';
import '../api/catalog_api.dart';
import '../config/app_config.dart';
import 'seller_storefront_editor_screen.dart';

class SellerProductsScreen extends StatefulWidget {
  final AuthApi authApi;
  const SellerProductsScreen({super.key, required this.authApi});

  @override
  State<SellerProductsScreen> createState() => _SellerProductsScreenState();
}

class _SellerProductsScreenState extends State<SellerProductsScreen> {
  static const List<String> _lotStatuses = ['ACTIVE', 'HOLD', 'EXHAUSTED'];
  late final CatalogApi catalogApi;
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> products = [];

  @override
  void initState() {
    super.initState();
    catalogApi = CatalogApi(baseUrl: AppConfig.baseUrl);
    _load();
  }

  Future<void> _load() async {
    final token = widget.authApi.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        loading = false;
        error = 'กรุณาเข้าสู่ระบบด้วยบัญชีร้านค้า';
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final results = await Future.wait([
        catalogApi.listCategories(),
        catalogApi.listMySellerProducts(accessToken: token),
      ]);
      final loadedCategories = results[0];
      final loadedProducts = results[1];
      if (!mounted) return;
      setState(() {
        categories = loadedCategories;
        products = loadedProducts;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  int _toPrice(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  String _categoryName(String categoryId) {
    final c = categories.where((x) => (x['id'] ?? '').toString() == categoryId);
    if (c.isNotEmpty) return (c.first['name'] ?? '-').toString();
    return '-';
  }

  Future<String?> _pickProductImageFromDevice() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!kIsWeb && Platform.isMacOS) {
        final file = await fs.openFile(
          acceptedTypeGroups: const [
            fs.XTypeGroup(
              label: 'images',
              extensions: ['jpg', 'jpeg', 'png', 'webp', 'heic'],
            ),
          ],
          confirmButtonText: 'เลือกรูป',
        );
        if (!mounted) return null;
        if (file == null || file.path.isEmpty) return null;
        return _persistImageToAppTemp(file.path);
      }

      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        lockParentWindow: true,
        dialogTitle: 'เลือกรูปสินค้า',
      );
      if (!mounted) return null;
      if (picked == null || picked.files.isEmpty) return null;
      final path = picked.files.first.path;
      if (path == null || path.isEmpty) return null;
      return _persistImageToAppTemp(path);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _persistImageToAppTemp(String sourcePath) async {
    try {
      final source = File(sourcePath);
      if (!await source.exists()) return sourcePath;
      final ext = sourcePath.contains('.')
          ? sourcePath.split('.').last.toLowerCase()
          : 'png';
      final safeExt = ext.replaceAll(RegExp(r'[^a-z0-9]'), '');
      final targetDir = Directory('${Directory.systemTemp.path}/aroiho_product_images');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      final targetPath =
          '${targetDir.path}/img_${DateTime.now().millisecondsSinceEpoch}.${safeExt.isEmpty ? 'png' : safeExt}';
      await source.copy(targetPath);
      return targetPath;
    } catch (_) {
      return sourcePath;
    }
  }

  Future<void> _openProductForm({Map<String, dynamic>? existing}) async {
    final token = widget.authApi.accessToken;
    if (token == null || token.isEmpty) return;

    if (categories.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ยังไม่มีหมวดหมู่ให้เลือก')));
      return;
    }

    final nameCtl = TextEditingController(
      text: (existing?['name'] ?? '').toString(),
    );
    final unitCtl = TextEditingController(
      text: (existing?['unit'] ?? '').toString(),
    );
    final priceCtl = TextEditingController(
      text: existing == null ? '' : _toPrice(existing['basePrice']).toString(),
    );
    final descCtl = TextEditingController(
      text: (existing?['description'] ?? '').toString(),
    );
    final thumbCtl = TextEditingController(
      text: (existing?['thumbnailUrl'] ?? '').toString(),
    );
    String selectedCategoryId =
        (existing?['categoryId'] ?? categories.first['id']).toString();
    bool active = existing == null ? true : (existing['isActive'] == true);
    String? localError;
    bool saving = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'เพิ่มสินค้า' : 'แก้ไขสินค้า'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedCategoryId,
                  items: categories
                      .map(
                        (c) => DropdownMenuItem<String>(
                          value: (c['id'] ?? '').toString(),
                          child: Text((c['name'] ?? '-').toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setLocal(() => selectedCategoryId = v);
                  },
                  decoration: const InputDecoration(labelText: 'หมวดหมู่'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtl,
                  decoration: const InputDecoration(labelText: 'ชื่อสินค้า'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: unitCtl,
                  decoration: const InputDecoration(
                    labelText: 'หน่วย (เช่น kg / ชุด)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: priceCtl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'ราคา'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: thumbCtl,
                  decoration: const InputDecoration(
                    labelText: 'URL รูปสินค้า (ไม่บังคับ)',
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            final pickedPath =
                                await _pickProductImageFromDevice();
                            if (pickedPath == null || pickedPath.isEmpty) {
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('ไม่ได้เลือกรูป')),
                              );
                              return;
                            }
                            setLocal(() => thumbCtl.text = pickedPath);
                          },
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('เลือกจากอุปกรณ์'),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'รายละเอียด'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('เปิดขาย'),
                  value: active,
                  onChanged: (v) => setLocal(() => active = v),
                ),
                if (localError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      localError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameCtl.text.trim();
                      final unit = unitCtl.text.trim();
                      final price = num.tryParse(priceCtl.text.trim()) ?? -1;
                      if (name.isEmpty || unit.isEmpty || price < 0) {
                        setLocal(
                          () => localError =
                              'กรอกข้อมูลให้ครบและราคาต้องไม่ติดลบ',
                        );
                        return;
                      }

                      setLocal(() {
                        localError = null;
                        saving = true;
                      });

                      try {
                        if (existing == null) {
                          await catalogApi.createMySellerProduct(
                            accessToken: token,
                            categoryId: selectedCategoryId,
                            name: name,
                            unit: unit,
                            basePrice: price,
                            description: descCtl.text.trim(),
                            thumbnailUrl: thumbCtl.text.trim(),
                            isActive: active,
                          );
                        } else {
                          final id = (existing['id'] ?? '').toString();
                          await catalogApi.updateMySellerProduct(
                            accessToken: token,
                            productId: id,
                            categoryId: selectedCategoryId,
                            name: name,
                            unit: unit,
                            basePrice: price,
                            description: descCtl.text.trim(),
                            thumbnailUrl: thumbCtl.text.trim(),
                            isActive: active,
                          );
                        }
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
    unitCtl.dispose();
    priceCtl.dispose();
    descCtl.dispose();
    thumbCtl.dispose();

    if (saved == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'เพิ่มสินค้าแล้ว (สร้างล็อตเริ่มต้น 100 หน่วยอัตโนมัติ)'
                : 'แก้ไขสินค้าแล้ว',
          ),
        ),
      );
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> p, bool next) async {
    final token = widget.authApi.accessToken;
    if (token == null || token.isEmpty) return;
    try {
      await catalogApi.toggleMySellerProductActive(
        accessToken: token,
        productId: (p['id'] ?? '').toString(),
        isActive: next,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('อัปเดตสถานะสินค้าไม่สำเร็จ: $e')));
    }
  }

  String _dateOnly(dynamic value) {
    final s = (value ?? '').toString().trim();
    if (s.isEmpty) return '';
    final i = s.indexOf('T');
    return i > 0 ? s.substring(0, i) : s;
  }

  Future<void> _openLotFormDialog({
    required String accessToken,
    required String productId,
    required Future<void> Function() reloadLots,
    Map<String, dynamic>? existing,
  }) async {
    final lotCodeCtl = TextEditingController(
      text: (existing?['lotCode'] ?? '').toString(),
    );
    final qtyCtl = TextEditingController(
      text: existing == null
          ? ''
          : (existing['quantityAvailable'] ?? '').toString(),
    );
    final harvestedCtl = TextEditingController(
      text: _dateOnly(existing?['harvestedAt']),
    );
    final packedCtl = TextEditingController(
      text: _dateOnly(existing?['packedAt']),
    );
    final expiresCtl = TextEditingController(
      text: _dateOnly(existing?['expiresAt']),
    );
    final consumeBeforeCtl = TextEditingController(
      text: _dateOnly(existing?['recommendedConsumeBefore']),
    );
    final storageCtl = TextEditingController(
      text: (existing?['storageCondition'] ?? '').toString(),
    );
    var status = ((existing?['status'] ?? 'ACTIVE').toString().toUpperCase());
    if (!_lotStatuses.contains(status)) status = 'ACTIVE';

    String? localError;
    bool saving = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'เพิ่มล็อตสินค้า' : 'แก้ไขล็อตสินค้า'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: lotCodeCtl,
                    decoration: const InputDecoration(
                      labelText: 'รหัสล็อต (ไม่บังคับ)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: qtyCtl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'จำนวนคงเหลือ',
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    items: _lotStatuses
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s,
                            child: Text(s),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setLocal(() => status = v ?? 'ACTIVE'),
                    decoration: const InputDecoration(labelText: 'สถานะล็อต'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: harvestedCtl,
                    decoration: const InputDecoration(
                      labelText: 'วันที่เก็บเกี่ยว (YYYY-MM-DD)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: packedCtl,
                    decoration: const InputDecoration(
                      labelText: 'วันที่แพ็ค (YYYY-MM-DD)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: expiresCtl,
                    decoration: const InputDecoration(
                      labelText: 'วันหมดอายุ (YYYY-MM-DD)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: consumeBeforeCtl,
                    decoration: const InputDecoration(
                      labelText: 'ควรบริโภคก่อน (YYYY-MM-DD)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: storageCtl,
                    decoration: const InputDecoration(labelText: 'การจัดเก็บ'),
                  ),
                  if (localError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        localError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final qty = num.tryParse(qtyCtl.text.trim());
                      if (qty == null || qty < 0) {
                        setLocal(
                          () =>
                              localError = 'จำนวนต้องเป็นตัวเลขและต้องไม่ติดลบ',
                        );
                        return;
                      }
                      if (existing == null && qty <= 0) {
                        setLocal(
                          () => localError =
                              'การสร้างล็อตใหม่ จำนวนต้องมากกว่า 0',
                        );
                        return;
                      }

                      setLocal(() {
                        saving = true;
                        localError = null;
                      });

                      try {
                        if (existing == null) {
                          await catalogApi.createMyProductLot(
                            accessToken: accessToken,
                            productId: productId,
                            lotCode: lotCodeCtl.text.trim(),
                            quantityAvailable: qty,
                            status: status,
                            harvestedAt: harvestedCtl.text.trim(),
                            packedAt: packedCtl.text.trim(),
                            expiresAt: expiresCtl.text.trim(),
                            recommendedConsumeBefore: consumeBeforeCtl.text
                                .trim(),
                            storageCondition: storageCtl.text.trim(),
                          );
                        } else {
                          await catalogApi.updateMyLot(
                            accessToken: accessToken,
                            lotId: (existing['id'] ?? '').toString(),
                            lotCode: lotCodeCtl.text.trim(),
                            quantityAvailable: qty,
                            status: status,
                            harvestedAt: harvestedCtl.text.trim(),
                            packedAt: packedCtl.text.trim(),
                            expiresAt: expiresCtl.text.trim(),
                            recommendedConsumeBefore: consumeBeforeCtl.text
                                .trim(),
                            storageCondition: storageCtl.text.trim(),
                          );
                        }
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

    lotCodeCtl.dispose();
    qtyCtl.dispose();
    harvestedCtl.dispose();
    packedCtl.dispose();
    expiresCtl.dispose();
    consumeBeforeCtl.dispose();
    storageCtl.dispose();

    if (saved == true) {
      await reloadLots();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null ? 'เพิ่มล็อตแล้ว' : 'อัปเดตล็อตแล้ว'),
        ),
      );
    }
  }

  Future<void> _openLotsManager(Map<String, dynamic> product) async {
    final token = widget.authApi.accessToken;
    if (token == null || token.isEmpty) return;
    final productId = (product['id'] ?? '').toString();
    final productName = (product['name'] ?? 'สินค้า').toString();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF2F2EC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool initialLoaded = false;
        bool modalLoading = true;
        String? modalError;
        List<Map<String, dynamic>> lots = [];

        return StatefulBuilder(
          builder: (ctx, setModal) {
            Future<void> loadLots() async {
              setModal(() {
                modalLoading = true;
                modalError = null;
              });
              try {
                final loaded = await catalogApi.listMyProductLots(
                  accessToken: token,
                  productId: productId,
                );
                setModal(() {
                  lots = loaded;
                  modalLoading = false;
                });
              } catch (e) {
                setModal(() {
                  modalLoading = false;
                  modalError = e.toString();
                });
              }
            }

            if (!initialLoaded) {
              initialLoaded = true;
              Future.microtask(loadLots);
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                child: SizedBox(
                  height: MediaQuery.of(ctx).size.height * 0.85,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'ล็อตสินค้า: $productName',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () => _openLotFormDialog(
                              accessToken: token,
                              productId: productId,
                              reloadLots: loadLots,
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('เพิ่มล็อต'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (modalLoading)
                        const Expanded(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (modalError != null)
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text('โหลดล็อตไม่สำเร็จ\n$modalError'),
                            ),
                          ),
                        )
                      else if (lots.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Text('ยังไม่มีล็อตสำหรับสินค้านี้'),
                          ),
                        )
                      else
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: loadLots,
                            child: ListView.separated(
                              itemCount: lots.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final lot = lots[i];
                                final code = (lot['lotCode'] ?? '-').toString();
                                final qty = (lot['quantityAvailable'] ?? 0)
                                    .toString();
                                final status = (lot['status'] ?? '-')
                                    .toString();
                                final expires = _dateOnly(lot['expiresAt']);
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              code,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'จำนวน: $qty | สถานะ: $status',
                                            ),
                                            if (expires.isNotEmpty)
                                              Text(
                                                'หมดอายุ: $expires',
                                                style: const TextStyle(
                                                  color: Colors.black54,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _openLotFormDialog(
                                          accessToken: token,
                                          productId: productId,
                                          existing: lot,
                                          reloadLots: loadLots,
                                        ),
                                        icon: const Icon(Icons.edit_outlined),
                                        tooltip: 'แก้ไขล็อต',
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2EC),
        title: const Text('จัดการสินค้าร้านค้า'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SellerStorefrontEditorScreen(authApi: widget.authApi),
                ),
              );
            },
            icon: const Icon(Icons.storefront_outlined),
            tooltip: 'ตกแต่งหน้าร้าน',
          ),
          IconButton(
            onPressed: () => _openProductForm(),
            icon: const Icon(Icons.add),
            tooltip: 'เพิ่มสินค้า',
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(error!),
              ),
            )
          : products.isEmpty
          ? const Center(child: Text('ยังไม่มีสินค้าในร้าน'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: products.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final p = products[i];
                  final name = (p['name'] ?? '-').toString();
                  final price = _toPrice(p['basePrice']);
                  final unit = (p['unit'] ?? '').toString();
                  final isActive = p['isActive'] == true;
                  final thumb = (p['thumbnailUrl'] ?? '').toString();
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildProductImageThumb(thumb),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('฿$price ${unit.isEmpty ? '' : '/ $unit'}'),
                              Text(
                                'หมวด: ${_categoryName((p['categoryId'] ?? '').toString())}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            IconButton(
                              onPressed: () => _openProductForm(existing: p),
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'แก้ไข',
                            ),
                            IconButton(
                              onPressed: () => _openLotsManager(p),
                              icon: const Icon(Icons.inventory_2_outlined),
                              tooltip: 'จัดการล็อต',
                            ),
                            Switch(
                              value: isActive,
                              onChanged: (v) => _toggleActive(p, v),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openProductForm(),
        label: const Text('เพิ่มสินค้า'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _thumbFallback() {
    return Container(
      width: 72,
      height: 72,
      color: const Color(0xFFE0E8CE),
      alignment: Alignment.center,
      child: const Text('🥬'),
    );
  }

  Widget _buildProductImageThumb(String src) {
    if (src.trim().isEmpty) return _thumbFallback();
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return Image.network(
        src,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _thumbFallback(),
      );
    }
    try {
      final path = src.startsWith('file://')
          ? src.replaceFirst('file://', '')
          : src;
      return Image.file(
        File(path),
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _thumbFallback(),
      );
    } catch (_) {
      return _thumbFallback();
    }
  }
}
