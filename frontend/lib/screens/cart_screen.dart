import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../api/auth_api.dart';
import '../api/cart_api.dart';
import '../api/addresses_api.dart';
import '../api/orders_api.dart';
import '../api/payments_api.dart';
import 'address_confirm_screen.dart';

enum DeliveryOption { standard, express, air }
enum PaymentOption { promptPay, card, cod }

class CartScreen extends StatefulWidget {
  final AuthApi authApi;
  const CartScreen({super.key, required this.authApi});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late final CartApi cartApi;
  late final AddressesApi addressesApi;
  late final OrdersApi ordersApi;
  late final PaymentsApi paymentsApi;

  bool loading = true;
  bool checkingOut = false;
  String? error;
  String? lastOrderNo;
  String? lastPaymentInfo;
  List<Map<String, dynamic>> items = [];
  Map<String, dynamic>? selectedAddress;
  DeliveryOption selectedDelivery = DeliveryOption.standard;
  PaymentOption selectedPayment = PaymentOption.promptPay;

  @override
  void initState() {
    super.initState();
    cartApi = CartApi();
    addressesApi = AddressesApi();
    ordersApi = OrdersApi();
    paymentsApi = PaymentsApi();
    _loadCart();
  }

  Future<void> _loadCart() async {
    final token = widget.authApi.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        loading = false;
        error = 'กรุณาเข้าสู่ระบบใหม่';
      });
      return;
    }

    try {
      final results = await Future.wait([
        cartApi.getCart(accessToken: token),
        addressesApi.listMine(accessToken: token),
      ]);
      final cart = results[0] as Map<String, dynamic>;
      final addresses = results[1] as List<Map<String, dynamic>>;
      final rawItems = cart['items'];
      Map<String, dynamic>? picked;
      for (final a in addresses) {
        if (a['isDefault'] == true) {
          picked = a;
          break;
        }
      }
      picked ??= addresses.isNotEmpty ? addresses.first : null;

      setState(() {
        items = rawItems is List
            ? rawItems
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : <Map<String, dynamic>>[];
        selectedAddress = selectedAddress == null
            ? picked
            : addresses.cast<Map<String, dynamic>?>().firstWhere(
                  (a) => a?['id']?.toString() == selectedAddress?['id']?.toString(),
                  orElse: () => picked,
                );
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

  Future<void> _changeQuantity(Map<String, dynamic> item, num nextQty) async {
    final token = widget.authApi.accessToken;
    final cartItemId = item['id']?.toString();
    if (token == null || token.isEmpty || cartItemId == null) return;

    try {
      await cartApi.updateItem(
        accessToken: token,
        cartItemId: cartItemId,
        quantity: nextQty,
      );
      await _loadCart();
    } catch (e) {
      _showMessage('อัปเดตจำนวนไม่สำเร็จ: $e');
    }
  }

  Future<void> _removeItem(Map<String, dynamic> item) async {
    final token = widget.authApi.accessToken;
    final cartItemId = item['id']?.toString();
    if (token == null || token.isEmpty || cartItemId == null) return;

    try {
      await cartApi.removeItem(
        accessToken: token,
        cartItemId: cartItemId,
      );
      await _loadCart();
    } catch (e) {
      _showMessage('ลบสินค้าไม่สำเร็จ: $e');
    }
  }

  Future<void> _checkout() async {
    if (checkingOut) return;
    final token = widget.authApi.accessToken;
    if (token == null || token.isEmpty) {
      _showMessage('กรุณาเข้าสู่ระบบใหม่');
      return;
    }

    setState(() => checkingOut = true);
    try {
      if (selectedAddress == null) {
        _showMessage('ยังไม่มีที่อยู่จัดส่ง กรุณาเพิ่มที่อยู่ก่อน');
        return;
      }
      final addressId = selectedAddress?['id']?.toString();
      if (addressId == null || addressId.isEmpty) {
        _showMessage('ไม่พบ addressId');
        return;
      }

      final order = await ordersApi.checkout(
        accessToken: token,
        addressId: addressId,
        shippingMethod: _shippingMethodForCheckout(),
        shippingSurcharge: _shippingSurchargeForCheckout(),
      );

      final orderId = order['id']?.toString();
      if (orderId == null || orderId.isEmpty) {
        _showMessage('สร้างคำสั่งซื้อสำเร็จ แต่ไม่พบ orderId');
        await _loadCart();
        return;
      }

      if (selectedPayment != PaymentOption.cod) {
        final intent = await paymentsApi.createIntent(
          accessToken: token,
          orderId: orderId,
          provider: _paymentProvider(),
        );
        setState(() {
          lastOrderNo = (order['orderNo'] ?? orderId).toString();
          lastPaymentInfo = intent['mockQrText']?.toString() ?? _paymentLabel();
        });
      } else {
        setState(() {
          lastOrderNo = (order['orderNo'] ?? orderId).toString();
          lastPaymentInfo = 'ชำระปลายทาง';
        });
      }
      await _loadCart();
    } catch (e) {
      _showMessage('ชำระเงินไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => checkingOut = false);
    }
  }

  Future<void> _openAddressConfirm() async {
    final selected = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressConfirmScreen(
          authApi: widget.authApi,
          selectedAddressId: selectedAddress?['id']?.toString(),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => selectedAddress = selected);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  num _lineTotal(Map<String, dynamic> item) {
    final price = _toNum(item['unitPrice']);
    final qty = _toNum(item['quantity']);
    return price * qty;
  }

  num _cartTotal() {
    return items.fold<num>(0, (sum, i) => sum + _lineTotal(i));
  }

  num _deliveryFee() {
    switch (selectedDelivery) {
      case DeliveryOption.standard:
        return 40;
      case DeliveryOption.express:
        return 140;
      case DeliveryOption.air:
        return 240;
    }
  }

  num _grandTotal() {
    return _cartTotal() + _deliveryFee();
  }

  String _shippingMethodForCheckout() {
    if (selectedDelivery == DeliveryOption.air) return 'AIR';
    return 'GROUND';
  }

  num _shippingSurchargeForCheckout() {
    if (selectedDelivery == DeliveryOption.express) return 100;
    return 0;
  }

  num _toNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse('$value') ?? 0;
  }

  String _paymentProvider() {
    switch (selectedPayment) {
      case PaymentOption.promptPay:
        return 'PROMPTPAY';
      case PaymentOption.card:
        return 'CARD';
      case PaymentOption.cod:
        return 'COD';
    }
  }

  String _paymentLabel() {
    switch (selectedPayment) {
      case PaymentOption.promptPay:
        return 'PromptPay';
      case PaymentOption.card:
        return 'บัตรเครดิต/เดบิต';
      case PaymentOption.cod:
        return 'ชำระปลายทาง';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2EC),
        title: const Text('ตะกร้าสินค้า'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : items.isEmpty
                  ? _emptyState()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        ...List.generate(items.length, (i) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 10),
                            child: _cartItemCard(items[i]),
                          );
                        }),
                        const SizedBox(height: 12),
                        _addressCard(),
                        const SizedBox(height: 12),
                        _deliverySelectorCard(),
                        const SizedBox(height: 12),
                        _paymentSelectorCard(),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('ค่าสินค้า', style: TextStyle(fontWeight: FontWeight.w600)),
                                  Text(
                                    '฿${_cartTotal().toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('ค่าขนส่ง', style: TextStyle(fontWeight: FontWeight.w600)),
                                  Text(
                                    '฿${_deliveryFee().toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const Divider(height: 18),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('ยอดรวมทั้งหมด', style: TextStyle(fontWeight: FontWeight.w800)),
                                  Text(
                                    '฿${_grandTotal().toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: checkingOut ? null : _checkout,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE0C14E),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(checkingOut ? 'กำลังชำระเงิน...' : 'ชำระเงิน'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _cartItemCard(Map<String, dynamic> item) {
    final product = item['product'] is Map
        ? Map<String, dynamic>.from(item['product'] as Map)
        : <String, dynamic>{};
    final name = (product['name'] ?? '-') as String;
    final thumb = product['thumbnailUrl'] as String?;
    final qty = _toNum(item['quantity']);
    final price = _toNum(item['unitPrice']);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            blurRadius: 4,
            offset: const Offset(0, 2),
            color: Colors.black.withValues(alpha: 0.08),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildAnyImage(thumb, height: 54, width: 54),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('฿${price.toStringAsFixed(0)}'),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _removeItem(item),
            icon: const Icon(Icons.delete_outline),
          ),
          _qtyButton('-', () {
            final next = qty - 1;
            _changeQuantity(item, next <= 0 ? 0 : next);
          }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(qty.toStringAsFixed(qty % 1 == 0 ? 0 : 3)),
          ),
          _qtyButton('+', () => _changeQuantity(item, qty + 1)),
        ],
      ),
    );
  }

  Widget _emptyState() {
    if (lastOrderNo == null) {
      return const Center(child: Text('ยังไม่มีสินค้าในตะกร้า'));
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 62),
            const SizedBox(height: 10),
            const Text(
              'สั่งซื้อสำเร็จแล้ว',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Order: $lastOrderNo',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              'ช่องทางชำระ: ${_paymentLabel()}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (lastPaymentInfo != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  lastPaymentInfo!,
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 14),
            const Text('ตะกร้าถูกล้างหลัง checkout อัตโนมัติ'),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('กลับไปเลือกสินค้า'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deliverySelectorCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('เลือกบริการจัดส่ง', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _deliveryOptionTile(
            option: DeliveryOption.standard,
            title: 'Standard',
            subtitle: 'ปกติ ส่งภายใน 2-3 วัน',
            fee: 40,
          ),
          _deliveryOptionTile(
            option: DeliveryOption.express,
            title: 'Express',
            subtitle: 'เร็วพิเศษ ส่งภายในวันถัดไป',
            fee: 140,
          ),
          _deliveryOptionTile(
            option: DeliveryOption.air,
            title: 'ทางอากาศ',
            subtitle: 'เร็วที่สุด (Air surcharge)',
            fee: 240,
          ),
        ],
      ),
    );
  }

  Widget _addressCard() {
    final a = selectedAddress;
    final hasAddress = a != null;
    final receiver = (a?['receiverName'] ?? '-').toString();
    final phone = (a?['phone'] ?? '-').toString();
    final line1 = (a?['addressLine1'] ?? '-').toString();
    final district = (a?['district'] ?? '').toString();
    final province = (a?['province'] ?? '').toString();
    final postcode = (a?['postcode'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ยืนยันที่อยู่จัดส่ง', style: TextStyle(fontWeight: FontWeight.w800)),
              TextButton(onPressed: _openAddressConfirm, child: Text(hasAddress ? 'เปลี่ยน' : 'เลือก')),
            ],
          ),
          if (!hasAddress)
            const Text('ยังไม่ได้เลือกที่อยู่จัดส่ง')
          else ...[
            Text(receiver, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(phone),
            const SizedBox(height: 2),
            Text('$line1, $district, $province $postcode'),
          ],
        ],
      ),
    );
  }

  Widget _paymentSelectorCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ช่องทางชำระเงิน', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _paymentOptionTile(
            option: PaymentOption.promptPay,
            title: 'PromptPay',
            subtitle: 'สแกน QR เพื่อชำระเงิน',
          ),
          _paymentOptionTile(
            option: PaymentOption.card,
            title: 'บัตรเครดิต/เดบิต',
            subtitle: 'ชำระผ่านบัตรออนไลน์',
          ),
          _paymentOptionTile(
            option: PaymentOption.cod,
            title: 'ชำระปลายทาง',
            subtitle: 'จ่ายเงินเมื่อรับสินค้า',
          ),
        ],
      ),
    );
  }

  Widget _paymentOptionTile({
    required PaymentOption option,
    required String title,
    required String subtitle,
  }) {
    final selected = selectedPayment == option;
    return InkWell(
      onTap: () => setState(() => selectedPayment = option),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? const Color(0xFF7BA43A) : Colors.black38,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deliveryOptionTile({
    required DeliveryOption option,
    required String title,
    required String subtitle,
    required num fee,
  }) {
    final selected = selectedDelivery == option;
    return InkWell(
      onTap: () => setState(() => selectedDelivery = option),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? const Color(0xFF7BA43A) : Colors.black38,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            Text('฿${fee.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _qtyButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0xFFEED36E),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _thumbFallback() {
    return Container(
      height: 54,
      width: 54,
      color: const Color(0xFFE0E8CE),
      alignment: Alignment.center,
      child: const Text('🥬', style: TextStyle(fontSize: 24)),
    );
  }

  Widget _buildAnyImage(
    String? src, {
    required double height,
    required double width,
  }) {
    final value = (src ?? '').trim();
    if (value.isEmpty) return _thumbFallback();

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Image.network(
        value,
        height: height,
        width: width,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _thumbFallback(),
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
          errorBuilder: (context, error, stackTrace) => _thumbFallback(),
        );
      } catch (_) {
        return _thumbFallback();
      }
    }

    return _thumbFallback();
  }
}
