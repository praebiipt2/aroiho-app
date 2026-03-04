import 'package:flutter/material.dart';
import '../api/auth_api.dart';
import '../api/catalog_api.dart';
import '../config/app_config.dart';

class SellerApplyScreen extends StatefulWidget {
  final AuthApi authApi;
  const SellerApplyScreen({super.key, required this.authApi});

  @override
  State<SellerApplyScreen> createState() => _SellerApplyScreenState();
}

class _SellerApplyScreenState extends State<SellerApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _addressCtl = TextEditingController();
  final _taxIdCtl = TextEditingController();
  String _type = 'FARM';
  bool _saving = false;
  String? _error;

  late final CatalogApi _catalogApi;

  @override
  void initState() {
    super.initState();
    _catalogApi = CatalogApi(baseUrl: AppConfig.baseUrl);
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _addressCtl.dispose();
    _taxIdCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final token = widget.authApi.accessToken;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'กรุณาเข้าสู่ระบบก่อน');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _catalogApi.applySeller(
        accessToken: token,
        name: _nameCtl.text.trim(),
        phone: _phoneCtl.text.trim().isEmpty ? null : _phoneCtl.text.trim(),
        addressText: _addressCtl.text.trim().isEmpty ? null : _addressCtl.text.trim(),
        type: _type,
        taxId: _taxIdCtl.text.trim().isEmpty ? null : _taxIdCtl.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เปิดร้านค้าเรียบร้อยแล้ว')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2EC),
        title: const Text('เปิดบัญชีร้านค้า'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ข้อมูลร้านค้า',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _nameCtl,
                    decoration: const InputDecoration(labelText: 'ชื่อร้าน *'),
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) return 'กรุณากรอกชื่อร้าน';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'ประเภทร้าน'),
                    items: const [
                      DropdownMenuItem(value: 'FARM', child: Text('ฟาร์ม')),
                      DropdownMenuItem(value: 'SEAFOOD', child: Text('อาหารทะเล')),
                      DropdownMenuItem(value: 'ORGANIC', child: Text('ออร์แกนิก')),
                    ],
                    onChanged: (v) => setState(() => _type = v ?? 'FARM'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _phoneCtl,
                    decoration: const InputDecoration(labelText: 'เบอร์ติดต่อร้าน'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _taxIdCtl,
                    decoration: const InputDecoration(labelText: 'เลขผู้เสียภาษี'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _addressCtl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'ที่อยู่ร้าน'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      child: Text(_saving ? 'กำลังบันทึก...' : 'ยืนยันเปิดร้านค้า'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
