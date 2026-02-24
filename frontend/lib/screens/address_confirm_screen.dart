import 'package:flutter/material.dart';
import '../api/auth_api.dart';
import '../api/addresses_api.dart';

class AddressConfirmScreen extends StatefulWidget {
  final AuthApi authApi;
  final String? selectedAddressId;

  const AddressConfirmScreen({
    super.key,
    required this.authApi,
    this.selectedAddressId,
  });

  @override
  State<AddressConfirmScreen> createState() => _AddressConfirmScreenState();
}

class _AddressConfirmScreenState extends State<AddressConfirmScreen> {
  late final AddressesApi addressesApi;
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> addresses = [];
  String? selectedId;

  @override
  void initState() {
    super.initState();
    addressesApi = AddressesApi();
    selectedId = widget.selectedAddressId;
    _load();
  }

  Future<void> _load() async {
    final token = widget.authApi.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        loading = false;
        error = 'กรุณาเข้าสู่ระบบใหม่';
      });
      return;
    }

    try {
      final result = await addressesApi.listMine(accessToken: token);
      if (selectedId == null && result.isNotEmpty) {
        final def = result.where((a) => a['isDefault'] == true);
        selectedId = def.isNotEmpty ? def.first['id']?.toString() : result.first['id']?.toString();
      }
      setState(() {
        addresses = result;
        loading = false;
        error = null;
      });
    } catch (e) {
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  Future<void> _confirm() async {
    if (selectedId == null) return;
    final token = widget.authApi.accessToken;
    if (token != null && token.isNotEmpty) {
      try {
        await addressesApi.setDefault(accessToken: token, addressId: selectedId!);
      } catch (_) {}
    }
    if (!mounted) return;

    final selected = addresses.firstWhere(
      (a) => a['id']?.toString() == selectedId,
      orElse: () => <String, dynamic>{},
    );
    Navigator.pop(context, selected);
  }

  Future<void> _editAddress(Map<String, dynamic> address) async {
    final token = widget.authApi.accessToken;
    final id = address['id']?.toString();
    if (token == null || token.isEmpty || id == null || id.isEmpty) return;

    final line1Ctl = TextEditingController(text: (address['addressLine1'] ?? '').toString());
    final phoneCtl = TextEditingController(text: (address['phone'] ?? '').toString());
    String? localError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('แก้ไขที่อยู่'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: line1Ctl,
                    decoration: const InputDecoration(labelText: 'ที่อยู่'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneCtl,
                    decoration: const InputDecoration(labelText: 'เบอร์โทร'),
                  ),
                  if (localError != null) ...[
                    const SizedBox(height: 8),
                    Text(localError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
                ElevatedButton(
                  onPressed: () {
                    if (line1Ctl.text.trim().isEmpty || phoneCtl.text.trim().isEmpty) {
                      setLocal(() => localError = 'กรุณากรอกข้อมูลให้ครบ');
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('บันทึก'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      line1Ctl.dispose();
      phoneCtl.dispose();
      return;
    }

    try {
      await addressesApi.updateMine(
        accessToken: token,
        addressId: id,
        data: {
          'addressLine1': line1Ctl.text.trim(),
          'phone': phoneCtl.text.trim(),
        },
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('แก้ไขที่อยู่ไม่สำเร็จ: $e')),
      );
    } finally {
      line1Ctl.dispose();
      phoneCtl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ยืนยันที่อยู่จัดส่ง')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : Column(
                  children: [
                    Expanded(
                      child: addresses.isEmpty
                          ? const Center(child: Text('ยังไม่มีที่อยู่ กรุณาเพิ่มในโปรไฟล์ก่อน'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: addresses.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final a = addresses[i];
                                final id = a['id']?.toString();
                                final selected = id == selectedId;
                                final receiver = (a['receiverName'] ?? '-').toString();
                                final phone = (a['phone'] ?? '-').toString();
                                final line1 = (a['addressLine1'] ?? '-').toString();
                                final district = (a['district'] ?? '').toString();
                                final province = (a['province'] ?? '').toString();
                                final postcode = (a['postcode'] ?? '').toString();

                                return InkWell(
                                  onTap: () => setState(() => selectedId = id),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selected ? const Color(0xFF9DBA3F) : Colors.transparent,
                                        width: 1.4,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          selected
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_off,
                                          color: selected ? const Color(0xFF7BA43A) : Colors.black38,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(receiver, style: const TextStyle(fontWeight: FontWeight.w800)),
                                              Text(phone),
                                              Text('$line1, $district, $province $postcode'),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'แก้ไขที่อยู่',
                                          onPressed: () => _editAddress(a),
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: selectedId == null ? null : _confirm,
                          child: const Text('ยืนยันที่อยู่นี้'),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
