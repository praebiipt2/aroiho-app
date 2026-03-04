import 'dart:async';

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
  Timer? _liveTimer;
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
    _startLiveUpdates();
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _liveTimer = null;
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _startLiveUpdates() {
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      _refreshHead();
    });
  }

  Future<void> _refreshHead() async {
    if (!mounted || loading || loadingMore || orders.isEmpty) return;
    final token = widget.authApi.accessToken;
    if (token == null || token.isEmpty) return;

    try {
      final result = await ordersApi.listMyOrders(
        accessToken: token,
        includeHidden: showHidden,
        page: 1,
        limit: _pageSize,
      );
      final incoming = (result['items'] as List).cast<Map<String, dynamic>>();
      if (!mounted || incoming.isEmpty) return;

      final existingById = <String, Map<String, dynamic>>{
        for (final o in orders)
          if ((o['id'] ?? '').toString().isNotEmpty) (o['id'] ?? '').toString(): o,
      };

      for (final o in incoming) {
        final id = (o['id'] ?? '').toString();
        if (id.isEmpty) continue;
        existingById[id] = o;
      }

      final merged = existingById.values.toList()
        ..sort((a, b) => ((b['createdAt'] ?? '').toString()).compareTo((a['createdAt'] ?? '').toString()));

      setState(() {
        orders = merged;
      });
    } catch (_) {
      // live refresh failure should be silent; normal manual refresh still works.
    }
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
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _TrackingLiveSheet(
          accessToken: token,
          orderId: orderId,
          orderNo: (order['orderNo'] ?? '').toString(),
          title: _trackingCtaLabel((order['orderStatus'] ?? '').toString()),
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
    final normalized = status.trim().toUpperCase();
    if (selectedFilter == 'ALL') return true;
    if (selectedFilter == 'DELIVERED') return normalized == 'DELIVERED';
    if (selectedFilter == 'CANCELLED') return normalized == 'CANCELLED';
    return normalized == 'CONFIRMED' ||
        normalized == 'PREPARING' ||
        normalized == 'SHIPPED' ||
        normalized == 'OUT_FOR_DELIVERY' ||
        normalized == 'IN_TRANSIT';
  }

  bool _isParcelPhase(String status) {
    final s = status.trim().toUpperCase();
    return s == 'SHIPPED' ||
        s == 'PICKED_UP' ||
        s == 'IN_TRANSIT' ||
        s == 'OUT_FOR_DELIVERY' ||
        s == 'DELIVERED';
  }

  String _trackingCtaLabel(String status) {
    return _isParcelPhase(status) ? 'ติดตามพัสดุ' : 'ติดตามออเดอร์';
  }

  String _filterLabel(String filter) {
    switch (filter) {
      case 'IN_PROGRESS':
        return 'กำลังดำเนินการ';
      case 'DELIVERED':
        return 'จัดส่งสำเร็จ';
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
      final status = (o['orderStatus'] ?? '').toString().trim().toUpperCase();
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
                          final status = (o['orderStatus'] ?? '').toString().trim().toUpperCase();
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
                                            child: Text(_trackingCtaLabel(status)),
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

class _TrackingLiveSheet extends StatefulWidget {
  final String accessToken;
  final String orderId;
  final String orderNo;
  final String title;

  const _TrackingLiveSheet({
    required this.accessToken,
    required this.orderId,
    required this.orderNo,
    required this.title,
  });

  @override
  State<_TrackingLiveSheet> createState() => _TrackingLiveSheetState();
}

class _TrackingLiveSheetState extends State<_TrackingLiveSheet> {
  final OrdersApi ordersApi = OrdersApi();
  Timer? timer;
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> events = [];

  @override
  void initState() {
    super.initState();
    _load();
    timer = Timer.periodic(const Duration(seconds: 5), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    timer?.cancel();
    timer = null;
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final tracking = await ordersApi.getTracking(
        accessToken: widget.accessToken,
        orderId: widget.orderId,
      );
      final rawEvents = tracking['events'];
      final mapped = rawEvents is List
          ? rawEvents
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        events = mapped;
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
    final displayEvents = _latestByType(events);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(widget.orderNo),
              const SizedBox(height: 12),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : error != null
                        ? Center(child: Text(error!))
                        : displayEvents.isEmpty
                            ? const Center(child: Text('ยังไม่มีเหตุการณ์ติดตาม'))
                            : ListView.separated(
                                itemCount: displayEvents.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final e = displayEvents[i];
                                  final type = (e['type'] ?? '-').toString();
                                  final msg = _safeMessage(type, (e['message'] ?? '').toString());
                                  final color = _eventColor(type);
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
                                        Row(
                                          children: [
                                            Icon(_eventIcon(type), size: 18, color: color),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                _thEventType(type),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: color,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
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
    );
  }
}
