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
  final ScrollController _scrollController = ScrollController();
  bool loading = true;
  bool loadingMore = false;
  bool hasMore = true;
  int page = 1;
  static const int _pageSize = 10;
  String? error;
  List<Map<String, dynamic>> orders = [];
  String selectedFilter = 'ALL';
  bool showHidden = false;

  static const List<String> _filters = [
    'ALL',
    'IN_PROGRESS',
    'DELIVERED',
    'CANCELLED',
  ];

  @override
  void initState() {
    super.initState();
    ordersApi = OrdersApi();
    _scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 240) {
      _loadMore();
    }
  }

  Future<void> _load({bool reset = false}) async {
    final token = widget.authApi.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        loading = false;
        error = 'กรุณาเข้าสู่ระบบใหม่';
      });
      return;
    }

    if (reset) {
      setState(() {
        loading = true;
        loadingMore = false;
        page = 1;
        hasMore = true;
        orders = [];
        error = null;
      });
    }

    if (!reset && (!hasMore || loading || loadingMore)) return;
    if (!reset) {
      setState(() => loadingMore = true);
    }

    try {
      final result = await ordersApi.listMyOrders(
        accessToken: token,
        includeHidden: showHidden,
        page: page,
        limit: _pageSize,
      );
      final incoming = (result['items'] as List).cast<Map<String, dynamic>>();
      final nextHasMore = result['hasMore'] == true;
      if (!mounted) return;
      setState(() {
        if (reset) {
          orders = incoming;
        } else {
          orders = [...orders, ...incoming];
        }
        page += 1;
        hasMore = nextHasMore;
        loading = false;
        loadingMore = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadingMore = false;
        error = e.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    await _load();
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
    await _load(reset: true);
  }

  Future<void> _openTracking(Map<String, dynamic> order) async {
    final token = widget.authApi.accessToken;
    final orderId = order['id']?.toString();
    if (token == null || token.isEmpty || orderId == null) return;

    try {
      final tracking = await ordersApi.getTracking(
        accessToken: token,
        orderId: orderId,
      );
      final rawEvents = tracking['events'];
      final events = rawEvents is List
          ? rawEvents
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ติดตามพัสดุ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text((order['orderNo'] ?? '').toString()),
                  const SizedBox(height: 12),
                  Expanded(
                    child: events.isEmpty
                        ? const Center(child: Text('ยังไม่มีเหตุการณ์ติดตาม'))
                        : ListView.separated(
                            itemCount: events.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final e = events[i];
                              final type = (e['type'] ?? '-').toString();
                              final msg = (e['message'] ?? '').toString();
                              final at = (e['createdAt'] ?? '')
                                  .toString()
                                  .replaceFirst('T', ' ')
                                  .replaceFirst('Z', '');
                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE3E3E3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(type, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    if (msg.isNotEmpty) Text(msg),
                                    Text(
                                      at,
                                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดข้อมูลติดตามไม่สำเร็จ: $e')),
      );
    }
  }

  Future<void> _hideOrder(Map<String, dynamic> order) async {
    final token = widget.authApi.accessToken;
    final orderId = order['id']?.toString();
    if (token == null || token.isEmpty || orderId == null) return;
    try {
      await ordersApi.hide(accessToken: token, orderId: orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ซ่อนคำสั่งซื้อแล้ว')));
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ซ่อนไม่สำเร็จ: $e')));
    }
  }

  Future<void> _unhideOrder(Map<String, dynamic> order) async {
    final token = widget.authApi.accessToken;
    final orderId = order['id']?.toString();
    if (token == null || token.isEmpty || orderId == null) return;
    try {
      await ordersApi.unhide(accessToken: token, orderId: orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('เลิกซ่อนคำสั่งซื้อแล้ว')));
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เลิกซ่อนไม่สำเร็จ: $e')));
    }
  }

  Future<void> _deleteOrder(Map<String, dynamic> order) async {
    final token = widget.authApi.accessToken;
    final orderId = order['id']?.toString();
    if (token == null || token.isEmpty || orderId == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ลบคำสั่งซื้อ'),
        content: const Text(
          'รายการจะหายจากหน้าคำสั่งซื้อทันที และระบบจะลบถาวรอัตโนมัติภายใน 60 วัน',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยันลบ'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final result = await ordersApi.softDelete(accessToken: token, orderId: orderId);
      if (!mounted) return;
      setState(() {
        orders = orders.where((o) => o['id']?.toString() != orderId).toList();
      });
      final purgeAfter = (result['purgeAfter'] ?? '').toString();
      final suffix = purgeAfter.isEmpty ? '' : ' ลบถาวร: ${purgeAfter.replaceFirst('T', ' ').replaceFirst('Z', '')}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ลบคำสั่งซื้อแล้ว.$suffix'),
          action: SnackBarAction(
            label: 'เลิกทำ',
            onPressed: () async {
              try {
                await ordersApi.restoreDeleted(
                  accessToken: token,
                  orderId: orderId,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('กู้คืนคำสั่งซื้อแล้ว')),
                );
                await _load(reset: true);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('กู้คืนไม่สำเร็จ: $e')),
                );
              }
            },
          ),
          duration: const Duration(seconds: 10),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ลบไม่สำเร็จ: $e')));
    }
  }

  String _thStatus(String? status) {
    switch (status) {
      case 'PENDING':
      case 'PENDING_PAYMENT':
        return 'รอชำระเงิน';
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

  Color _statusTextColor(String status) {
    switch (status) {
      case 'CANCELLED':
        return const Color(0xFF9A2020);
      case 'DELIVERED':
        return const Color(0xFF216B2D);
      case 'SHIPPED':
      case 'PREPARING':
      case 'CONFIRMED':
        return const Color(0xFF35512A);
      default:
        return const Color(0xFF4C4C4C);
    }
  }

  Color _statusBgColor(String status) {
    switch (status) {
      case 'CANCELLED':
        return const Color(0xFFF9E0E0);
      case 'DELIVERED':
        return const Color(0xFFE3F3DF);
      case 'SHIPPED':
      case 'PREPARING':
      case 'CONFIRMED':
        return const Color(0xFFEAF3C8);
      default:
        return const Color(0xFFEEEEEE);
    }
  }

  bool _matchFilter(String status) {
    if (selectedFilter == 'ALL') return true;
    if (selectedFilter == 'DELIVERED') return status == 'DELIVERED';
    if (selectedFilter == 'CANCELLED') return status == 'CANCELLED';
    return status == 'CONFIRMED' || status == 'PREPARING' || status == 'SHIPPED';
  }

  String _filterLabel(String filter) {
    switch (filter) {
      case 'IN_PROGRESS':
        return 'กำลังจัดส่ง';
      case 'DELIVERED':
        return 'สำเร็จ';
      case 'CANCELLED':
        return 'ยกเลิก';
      default:
        return 'ทั้งหมด';
    }
  }

  num _toNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse('$value') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = orders.where((o) {
      final status = (o['orderStatus'] ?? '').toString().toUpperCase();
      return _matchFilter(status);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2EC),
        title: const Text('คำสั่งซื้อของฉัน'),
        actions: [
          TextButton(
            onPressed: () async {
              setState(() => showHidden = !showHidden);
              await _load(reset: true);
            },
            child: Text(showHidden ? 'กลับรายการปกติ' : 'แสดงรายการที่ซ่อน'),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : RefreshIndicator(
                  onRefresh: () => _load(reset: true),
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _filters.map((filter) {
                            final active = selectedFilter == filter;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(_filterLabel(filter)),
                                selected: active,
                                onSelected: (_) => setState(() => selectedFilter = filter),
                                selectedColor: const Color(0xFFDCE8B0),
                                backgroundColor: Colors.white,
                                labelStyle: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: active ? const Color(0xFF2E4625) : Colors.black87,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: active ? const Color(0xFFB2C972) : const Color(0xFFDFDFDF),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (orders.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: Center(child: Text('ยังไม่มีคำสั่งซื้อ')),
                        )
                      else if (filteredOrders.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: Center(child: Text('ไม่มีคำสั่งซื้อในหมวดนี้')),
                        )
                      else ...[
                        ...filteredOrders.map((o) {
                          final orderNo = (o['orderNo'] ?? '-').toString();
                          final status = (o['orderStatus'] ?? '').toString().toUpperCase();
                          final total = _toNum(o['total']);
                          final createdAt = (o['createdAt'] ?? '').toString();
                          final items = o['items'] is List ? (o['items'] as List).length : 0;
                          final hiddenAt = o['hiddenAt'];
                          final isHidden = hiddenAt != null && hiddenAt.toString().isNotEmpty;
                          final canDelete = status == 'DELIVERED' || status == 'CANCELLED';
                          final statusTextColor = _statusTextColor(status);
                          final statusBgColor = _statusBgColor(status);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
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
                                        Row(
                                          children: [
                                            PopupMenuButton<String>(
                                              onSelected: (value) {
                                                if (value == 'hide') _hideOrder(o);
                                                if (value == 'unhide') _unhideOrder(o);
                                                if (value == 'delete') _deleteOrder(o);
                                              },
                                              itemBuilder: (_) => [
                                                PopupMenuItem<String>(
                                                  value: isHidden ? 'unhide' : 'hide',
                                                  child: Text(isHidden ? 'เลิกซ่อน' : 'ซ่อน'),
                                                ),
                                                if (canDelete)
                                                  const PopupMenuItem<String>(
                                                    value: 'delete',
                                                    child: Text('ลบ (ถาวรใน 60 วัน)'),
                                                  ),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: statusBgColor,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                _thStatus(status),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: statusTextColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('สินค้า $items รายการ'),
                                    Text('ยอดรวม ฿${total.toStringAsFixed(0)}'),
                                    if (isHidden)
                                      const Text(
                                        'ซ่อนอยู่',
                                        style: TextStyle(fontSize: 12, color: Colors.black54),
                                      ),
                                    if (createdAt.isNotEmpty)
                                      Text(
                                        createdAt.replaceFirst('T', ' ').replaceFirst('Z', ''),
                                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                                      ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () => _openOrderDetail(o),
                                            child: const Text('ดูรายละเอียด'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () => _openTracking(o),
                                            child: const Text('ติดตามพัสดุ'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        if (loadingMore)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (hasMore)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                'เลื่อนลงเพื่อโหลดเพิ่ม',
                                style: TextStyle(color: Colors.black54),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
