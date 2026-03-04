import 'dart:async';

import 'package:flutter/material.dart';
import '../api/auth_api.dart';
import '../api/orders_api.dart';

class OrderDetailScreen extends StatefulWidget {
  final AuthApi authApi;
  final String orderId;

  const OrderDetailScreen({
    super.key,
    required this.authApi,
    required this.orderId,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late final OrdersApi ordersApi;
  Timer? _liveTimer;
  bool loading = true;
  bool acting = false;
  String? error;
  Map<String, dynamic>? order;
  Map<String, dynamic>? shipment;
  List<Map<String, dynamic>> trackingEvents = [];

  @override
  void initState() {
    super.initState();
    ordersApi = OrdersApi();
    _load();
    _liveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!acting) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _liveTimer = null;
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final token = widget.authApi.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        loading = false;
        error = 'กรุณาเข้าสู่ระบบใหม่';
      });
      return;
    }

    if (!silent && mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final orderResult = await ordersApi.getOrder(
        accessToken: token,
        orderId: widget.orderId,
      );
      final shipmentResult = await ordersApi.getShipment(
        accessToken: token,
        orderId: widget.orderId,
      );
      final tracking = await ordersApi.getTracking(
        accessToken: token,
        orderId: widget.orderId,
      );

      if (!mounted) return;
      final rawEvents = tracking['events'];

      setState(() {
        order = orderResult;
        shipment = shipmentResult;
        trackingEvents = rawEvents is List
            ? rawEvents
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : <Map<String, dynamic>>[];
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) {
          loading = false;
          error = e.toString();
        }
      });
    }
  }

  Future<void> _cancel() async {
    if (acting) return;
    final token = widget.authApi.accessToken;
    if (token == null || token.isEmpty) return;
    setState(() => acting = true);
    try {
      await ordersApi.cancel(accessToken: token, orderId: widget.orderId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ยกเลิกคำสั่งซื้อแล้ว')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ยกเลิกไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => acting = false);
    }
  }

  Future<void> _refund() async {
    if (acting) return;
    final token = widget.authApi.accessToken;
    if (token == null || token.isEmpty) return;
    setState(() => acting = true);
    try {
      await ordersApi.refund(accessToken: token, orderId: widget.orderId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ส่งคำขอคืนเงินแล้ว')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('คืนเงินไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => acting = false);
    }
  }

  num _toNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse('$value') ?? 0;
  }

  String _fmtDate(dynamic value) {
    final s = (value ?? '').toString();
    if (s.isEmpty) return '-';
    return s.replaceFirst('T', ' ').replaceFirst('Z', '');
  }

  String _thStatus(String? status) {
    switch (status) {
      case 'CONFIRMED':
        return 'ยืนยันคำสั่งซื้อ';
      case 'PREPARING':
        return 'กำลังเตรียมสินค้า';
      case 'SHIPPED':
        return 'จัดส่งแล้ว';
      case 'DELIVERED':
        return 'จัดส่งสำเร็จ';
      case 'CANCELLED':
        return 'ยกเลิกแล้ว';
      default:
        return status ?? '-';
    }
  }

  String _thEventType(String type) {
    switch (type.toUpperCase()) {
      case 'ORDER_CREATED':
        return 'สร้างคำสั่งซื้อ';
      case 'PAYMENT_PENDING':
        return 'รอชำระเงิน';
      case 'PAYMENT_CONFIRMED':
        return 'ชำระเงินแล้ว';
      case 'PREPARING':
        return 'กำลังเตรียมสินค้า';
      case 'PACKED':
        return 'แพ็กสินค้าแล้ว';
      case 'PICKED_UP':
        return 'ไรเดอร์รับสินค้าแล้ว';
      case 'IN_TRANSIT':
        return 'กำลังขนส่ง';
      case 'OUT_FOR_DELIVERY':
        return 'กำลังนำส่ง';
      case 'DELIVERED':
        return 'จัดส่งสำเร็จ';
      case 'CANCELLED':
        return 'ยกเลิกคำสั่งซื้อ';
      case 'REFUND_REQUESTED':
        return 'กำลังดำเนินการคืนเงิน';
      case 'REFUNDED':
        return 'คืนเงินสำเร็จ';
      default:
        return type;
    }
  }

  IconData _eventIcon(String type) {
    switch (type.toUpperCase()) {
      case 'DELIVERED':
        return Icons.check_circle;
      case 'OUT_FOR_DELIVERY':
      case 'IN_TRANSIT':
      case 'PICKED_UP':
        return Icons.local_shipping;
      case 'PAYMENT_PENDING':
      case 'PAYMENT_CONFIRMED':
        return Icons.payments;
      case 'CANCELLED':
        return Icons.cancel;
      case 'REFUNDED':
      case 'REFUND_REQUESTED':
        return Icons.currency_exchange;
      default:
        return Icons.schedule;
    }
  }

  Color _eventColor(String type) {
    switch (type.toUpperCase()) {
      case 'DELIVERED':
        return const Color(0xFF2E7D32);
      case 'OUT_FOR_DELIVERY':
      case 'IN_TRANSIT':
      case 'PICKED_UP':
        return const Color(0xFF1565C0);
      case 'CANCELLED':
        return const Color(0xFFC62828);
      case 'REFUNDED':
      case 'REFUND_REQUESTED':
        return const Color(0xFF6A1B9A);
      default:
        return const Color(0xFF5F6368);
    }
  }

  String _safeMessage(String type, String msg) {
    final normalized = msg.trim();
    if (normalized.isEmpty) return '';
    final lower = normalized.toLowerCase();
    if (lower.contains('should fail')) return '';
    return normalized;
  }

  List<Map<String, dynamic>> _latestByType(List<Map<String, dynamic>> source) {
    final latest = <String, Map<String, dynamic>>{};
    for (final e in source) {
      final type = (e['type'] ?? '').toString().toUpperCase();
      if (type.isEmpty) continue;
      final current = latest[type];
      if (current == null) {
        latest[type] = e;
        continue;
      }
      final nextAt = (e['createdAt'] ?? '').toString();
      final curAt = (current['createdAt'] ?? '').toString();
      if (nextAt.compareTo(curAt) > 0) {
        latest[type] = e;
      }
    }

    final result = latest.values.toList()
      ..sort((a, b) => ((b['createdAt'] ?? '').toString()).compareTo((a['createdAt'] ?? '').toString()));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final currentOrder = order;
    final orderStatus = (currentOrder?['orderStatus'] ?? '').toString();
    final paymentStatus = (currentOrder?['paymentStatus'] ?? '').toString();
    final canCancel = paymentStatus == 'PENDING' && orderStatus != 'CANCELLED';
    final canRefund = paymentStatus == 'PAID' && orderStatus != 'DELIVERED';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2EC),
        title: const Text('รายละเอียดคำสั่งซื้อ'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _orderHeader(currentOrder!),
                    const SizedBox(height: 10),
                    _itemsCard(currentOrder),
                    const SizedBox(height: 10),
                    _addressCard(currentOrder),
                    const SizedBox(height: 10),
                    _shipmentCard(shipment),
                    const SizedBox(height: 10),
                    _trackingCard(),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: canCancel && !acting ? _cancel : null,
                            child: const Text('ยกเลิกออเดอร์'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: canRefund && !acting ? _refund : null,
                            child: Text(acting ? 'กำลังดำเนินการ...' : 'ขอคืนเงิน'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }

  Widget _orderHeader(Map<String, dynamic> o) {
    final orderNo = (o['orderNo'] ?? '-').toString();
    final status = _thStatus((o['orderStatus'] ?? '').toString());
    final total = _toNum(o['total']);
    final createdAt = _fmtDate(o['createdAt']);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(orderNo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('สถานะ: $status'),
          Text('วันที่สั่งซื้อ: $createdAt'),
          const SizedBox(height: 4),
          Text('ยอดรวม: ฿${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _itemsCard(Map<String, dynamic> o) {
    final items = o['items'] is List ? o['items'] as List : <dynamic>[];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('รายการสินค้า', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...items.map((it) {
            final m = it as Map;
            final p = _toNum(m['unitPrice']);
            final q = _toNum(m['quantity']);
            final line = _toNum(m['lineTotal']);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('฿${p.toStringAsFixed(0)} x ${q.toStringAsFixed(0)} = ฿${line.toStringAsFixed(0)}'),
            );
          }),
        ],
      ),
    );
  }

  Widget _addressCard(Map<String, dynamic> o) {
    final address = o['address'] is Map ? o['address'] as Map : <dynamic, dynamic>{};
    final receiver = (address['receiverName'] ?? '-').toString();
    final phone = (address['phone'] ?? '-').toString();
    final line1 = (address['addressLine1'] ?? '-').toString();
    final district = (address['district'] ?? '').toString();
    final province = (address['province'] ?? '').toString();
    final postcode = (address['postcode'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ที่อยู่จัดส่ง', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(receiver),
          Text(phone),
          Text('$line1, $district, $province $postcode'),
        ],
      ),
    );
  }

  Widget _shipmentCard(Map<String, dynamic>? s) {
    final legs = s?['legs'] is List ? s!['legs'] as List : <dynamic>[];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ข้อมูลการจัดส่ง', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          if (s == null) const Text('ยังไม่มีข้อมูลการจัดส่ง') else ...[
            Text('สถานะ shipment: ${(s['status'] ?? '-').toString()}'),
            const SizedBox(height: 6),
            ...legs.map((l) {
              final m = l as Map;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('Leg ${m['seq']}: ${m['mode']} (${m['status']})'),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _trackingCard() {
    final displayEvents = _latestByType(trackingEvents);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ไทม์ไลน์การติดตาม', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (displayEvents.isEmpty)
            const Text('ยังไม่มีเหตุการณ์ติดตาม')
          else
            ...displayEvents.map((e) {
              final type = (e['type'] ?? '').toString();
              final msg = _safeMessage(type, (e['message'] ?? '').toString());
              final color = _eventColor(type);
              final at = _fmtDate(e['createdAt']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(_eventIcon(type), size: 16, color: color),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _thEventType(type),
                            style: TextStyle(fontWeight: FontWeight.w700, color: color),
                          ),
                          if (msg.isNotEmpty) Text(msg),
                          Text(at, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
