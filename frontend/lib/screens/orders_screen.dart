import 'package:flutter/material.dart';
import '../api/auth_api.dart';
import '../api/orders_api.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  final AuthApi authApi;
  const OrdersScreen({super.key, required this.authApi});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late final OrdersApi ordersApi;
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> orders = [];

  @override
  void initState() {
    super.initState();
    ordersApi = OrdersApi();
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
      final result = await ordersApi.listMyOrders(accessToken: token);
      if (!mounted) return;
      setState(() {
        orders = result;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  Future<void> _openOrderDetail(Map<String, dynamic> order) async {
    final orderId = order['id']?.toString();
    if (orderId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          authApi: widget.authApi,
          orderId: orderId,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
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

  num _toNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse('$value') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2EC),
        title: const Text('คำสั่งซื้อของฉัน'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : orders.isEmpty
                  ? const Center(child: Text('ยังไม่มีคำสั่งซื้อ'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: orders.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final o = orders[i];
                          final orderNo = (o['orderNo'] ?? '-').toString();
                          final status = (o['orderStatus'] ?? '').toString();
                          final total = _toNum(o['total']);
                          final createdAt = (o['createdAt'] ?? '').toString();
                          final items = o['items'] is List ? (o['items'] as List).length : 0;

                          return InkWell(
                            onTap: () => _openOrderDetail(o),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                    color: Colors.black.withValues(alpha: 0.07),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          orderNo,
                                          style: const TextStyle(fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEAF3C8),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          _thStatus(status),
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text('สินค้า $items รายการ'),
                                  Text('ยอดรวม ฿${total.toStringAsFixed(0)}'),
                                  if (createdAt.isNotEmpty)
                                    Text(
                                      createdAt.replaceFirst('T', ' ').replaceFirst('Z', ''),
                                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
