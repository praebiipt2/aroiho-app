import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../api/auth_api.dart';
import '../api/catalog_api.dart';
import '../config/app_config.dart';
import 'seller_detail_screen.dart';

class SellerStorefrontEditorScreen extends StatefulWidget {
  final AuthApi authApi;
  const SellerStorefrontEditorScreen({super.key, required this.authApi});

  @override
  State<SellerStorefrontEditorScreen> createState() =>
      _SellerStorefrontEditorScreenState();
}

class _SellerStorefrontEditorScreenState
    extends State<SellerStorefrontEditorScreen> {
  static const String _pickFromDeviceToken = '__PICK_FROM_DEVICE__';
  late final CatalogApi _catalogApi;
  bool loading = true;
  bool saving = false;
  String? error;
  Map<String, dynamic>? seller;

  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _addressCtl = TextEditingController();
  final _aboutCtl = TextEditingController();
  final _coverCtl = TextEditingController();
  final _latCtl = TextEditingController();
  final _lngCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _catalogApi = CatalogApi(baseUrl: AppConfig.baseUrl);
    _coverCtl.addListener(_onCoverChanged);
    _load();
  }

  @override
  void dispose() {
    _coverCtl.removeListener(_onCoverChanged);
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _addressCtl.dispose();
    _aboutCtl.dispose();
    _coverCtl.dispose();
    _latCtl.dispose();
    _lngCtl.dispose();
    super.dispose();
  }

  void _onCoverChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final token = widget.authApi.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        loading = false;
        error = 'กรุณาเข้าสู่ระบบก่อน';
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });
    try {
      final mine = await _catalogApi.getMySeller(accessToken: token);
      if (!mounted) return;
      if (mine == null) {
        setState(() {
          loading = false;
          error = 'ยังไม่มีบัญชีร้านค้า';
        });
        return;
      }
      seller = mine;
      _nameCtl.text = (mine['name'] ?? '').toString();
      _phoneCtl.text = (mine['phone'] ?? '').toString();
      _addressCtl.text = (mine['addressText'] ?? '').toString();
      _aboutCtl.text = (mine['aboutText'] ?? '').toString();
      _coverCtl.text = (mine['coverImageUrl'] ?? '').toString();
      _latCtl.text = _toDoubleString(mine['lat']);
      _lngCtl.text = _toDoubleString(mine['lng']);
      setState(() => loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  Future<void> _save() async {
    final token = widget.authApi.accessToken;
    if (token == null || token.isEmpty) return;
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อร้าน')),
      );
      return;
    }
    final lat = _latCtl.text.trim().isEmpty ? null : double.tryParse(_latCtl.text.trim());
    final lng = _lngCtl.text.trim().isEmpty ? null : double.tryParse(_lngCtl.text.trim());
    if ((_latCtl.text.trim().isNotEmpty && lat == null) ||
        (_lngCtl.text.trim().isNotEmpty && lng == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('พิกัดไม่ถูกต้อง')),
      );
      return;
    }

    setState(() => saving = true);
    try {
      final updated = await _catalogApi.updateMySeller(
        accessToken: token,
        name: name,
        phone: _phoneCtl.text.trim(),
        addressText: _addressCtl.text.trim(),
        coverImageUrl: _coverCtl.text.trim(),
        aboutText: _aboutCtl.text.trim(),
        lat: lat,
        lng: lng,
      );
      if (!mounted) return;
      setState(() {
        seller = updated;
        saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกหน้าร้านแล้ว')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')),
      );
    }
  }

  Future<void> _changeCoverUrl() async {
    final ctl = TextEditingController(text: _coverCtl.text.trim());
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('เปลี่ยนรูปหน้าร้าน'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'URL รูปร้าน',
                  hintText: 'https://...',
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx, _pickFromDeviceToken),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('เลือกจากอุปกรณ์'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('ลบรูป'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
              child: const Text('ยืนยัน'),
            ),
          ],
        );
      },
    );
    ctl.dispose();
    if (next == null) return;
    if (next == _pickFromDeviceToken) {
      await _pickCoverFromDevice();
      return;
    }
    _coverCtl.text = next;
  }

  Future<void> _pickCoverFromDevice() async {
    try {
      // Give route transition a moment to fully close the previous dialog.
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
        if (!mounted) return;
        if (file == null || file.path.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่ได้เลือกรูป')),
          );
          return;
        }
        _coverCtl.text = file.path;
        return;
      }

      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        lockParentWindow: true,
        dialogTitle: 'เลือกรูปหน้าร้าน',
      );
      if (!mounted) return;
      if (picked == null || picked.files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่ได้เลือกรูป')),
        );
        return;
      }
      final path = picked.files.first.path;
      if (path == null || path.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถอ่านไฟล์รูปจากอุปกรณ์ได้')),
        );
        return;
      }
      _coverCtl.text = path;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เปิดตัวเลือกรูปไม่สำเร็จ: $e')),
      );
    }
  }

  void _openPreview() {
    final sellerId = (seller?['id'] ?? '').toString();
    if (sellerId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellerDetailScreen(
          sellerId: sellerId,
          authApi: widget.authApi,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2EC),
        title: const Text('ตกแต่งหน้าร้าน'),
        actions: [
          IconButton(
            onPressed: loading || error != null ? null : _openPreview,
            icon: const Icon(Icons.visibility_outlined),
            tooltip: 'ดูหน้าร้าน',
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(error!),
                ))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF3C8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'รูปหน้าร้าน',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _buildCoverPreview(_coverCtl.text.trim()),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _changeCoverUrl,
                              icon: const Icon(Icons.image_outlined),
                              label: const Text('เปลี่ยนรูปร้าน'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _nameCtl,
                            decoration: const InputDecoration(labelText: 'ชื่อร้าน *'),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _phoneCtl,
                            decoration: const InputDecoration(labelText: 'เบอร์ติดต่อร้าน'),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _addressCtl,
                            decoration: const InputDecoration(labelText: 'ที่อยู่ร้าน'),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _coverCtl,
                            decoration: const InputDecoration(labelText: 'URL รูปร้าน'),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _aboutCtl,
                            maxLines: 4,
                            decoration: const InputDecoration(labelText: 'รายละเอียดร้าน'),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _latCtl,
                                  keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                                  decoration: const InputDecoration(labelText: 'ละติจูด'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _lngCtl,
                                  keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                                  decoration: const InputDecoration(labelText: 'ลองจิจูด'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openPreview,
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('ดูหน้าร้าน'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: saving ? null : _save,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(saving ? 'กำลังบันทึก...' : 'บันทึก'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }

  String _toDoubleString(dynamic v) {
    if (v == null) return '';
    if (v is num) return v.toString();
    return v.toString();
  }

  Widget _buildCoverPreview(String src) {
    if (src.isEmpty) return _coverFallback(const Text('🏡', style: TextStyle(fontSize: 44)));
    final lower = src.toLowerCase();
    final isUrl = lower.startsWith('http://') || lower.startsWith('https://');
    if (isUrl) {
      return Image.network(
        src,
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _coverFallback(const Text('URL รูปไม่ถูกต้อง')),
      );
    }
    if (!kIsWeb) {
      final path = src.startsWith('file://') ? src.replaceFirst('file://', '') : src;
      return Image.file(
        File(path),
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _coverFallback(const Text('อ่านไฟล์รูปไม่สำเร็จ')),
      );
    }
    return _coverFallback(const Text('ยังไม่รองรับไฟล์ในแพลตฟอร์มนี้'));
  }

  Widget _coverFallback(Widget child) {
    return Container(
      height: 150,
      width: double.infinity,
      color: const Color(0xFFDDE7C0),
      alignment: Alignment.center,
      child: child,
    );
  }
}
