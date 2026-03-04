import 'package:flutter/material.dart';

import '../api/auth_api.dart';
import '../api/catalog_api.dart';
import '../config/app_config.dart';

class SellerDashboardScreen extends StatefulWidget {
  final AuthApi authApi;
  const SellerDashboardScreen({super.key, required this.authApi});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  late final CatalogApi _catalogApi;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _dashboard;
  int _selectedDays = 7;
  List<Map<String, dynamic>> _activePromotions = [];

  @override
  void initState() {
    super.initState();
    _catalogApi = CatalogApi(baseUrl: AppConfig.baseUrl);
    _load();
  }

  Future<void> _load() async {
    final token = widget.authApi.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'กรุณาเข้าสู่ระบบด้วยบัญชีร้านค้า';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _catalogApi.getSellerDashboard(accessToken: token, days: _selectedDays),
        _catalogApi.listMyPromotionCampaigns(
          accessToken: token,
          status: 'ACTIVE',
        ),
      ]);
      final data = results[0] as Map<String, dynamic>;
      final promotions = results[1] as List<Map<String, dynamic>>;
      if (!mounted) return;
      setState(() {
        _dashboard = data;
        _activePromotions = promotions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final periodDays = _asInt(_dashboard?['periodDays']) == 0
        ? _selectedDays
        : _asInt(_dashboard?['periodDays']);
    final kpis = (_dashboard?['kpis'] as Map?) ?? const {};
    final insights = (_dashboard?['insights'] as Map?) ?? const {};
    final inventory = (_dashboard?['inventory'] as Map?) ?? const {};
    final topProducts = _toMapList(_dashboard?['topProductsPeriod']);
    final bestSeller = (insights['bestSellerPeriod'] as Map?) != null
        ? Map<String, dynamic>.from(insights['bestSellerPeriod'] as Map)
        : null;
    final slowMoving = _toMapList(insights['slowMovingProductsPeriod']);
    final dailyTrend = _toMapList(_dashboard?['dailyTrendPeriod']);
    final recommendations = _toMapList(insights['recommendations']);
    final lowStock = _toMapList(inventory['lowStockProducts']);
    final expiringLots = _toMapList(inventory['expiringLots']);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2EC),
        title: const Text('แดชบอร์ดร้านค้า'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                children: [
                  _periodFilter(),
                  const SizedBox(height: 10),
                  _summaryGrid(context, kpis, periodDays),
                  const SizedBox(height: 12),
                  _insightSection(
                    bestSeller,
                    slowMoving,
                    recommendations,
                    periodDays,
                  ),
                  const SizedBox(height: 12),
                  _activePromotionsSection(),
                  const SizedBox(height: 12),
                  _salesTrendSection(dailyTrend, periodDays),
                  const SizedBox(height: 12),
                  _sectionCard(
                    title: 'สรุปคลังสินค้า',
                    subtitle:
                        'สินค้าเปิดขาย ${_asInt(inventory['activeProducts'])} รายการ',
                    child: Column(
                      children: [
                        _kvRow(
                          'สินค้าใกล้หมด (<= ${_asInt(inventory['lowStockThreshold'])})',
                          '${lowStock.length} รายการ',
                        ),
                        _kvRow(
                          'ล็อตใกล้หมดอายุ (${_asInt(inventory['expiringInDays'])} วัน)',
                          '${expiringLots.length} ล็อต',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _listSection(
                    title: 'สินค้าใกล้หมดสต็อก',
                    emptyText: 'ยังไม่มีสินค้าที่สต็อกต่ำ',
                    items: lowStock
                        .map(
                          (p) =>
                              '${(p['name'] ?? '-').toString()} • คงเหลือ ${_asNum(p['totalQty'])}',
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  _listSection(
                    title: 'ล็อตใกล้หมดอายุ',
                    emptyText: 'ยังไม่มีล็อตใกล้หมดอายุ',
                    items: expiringLots.map((lot) {
                      final code = (lot['lotCode'] ?? '-').toString();
                      final name = ((lot['product'] as Map?)?['name'] ?? '-')
                          .toString();
                      final exp = _dateThai(lot['expiresAt']?.toString());
                      final qty = _asNum(lot['quantityAvailable']);
                      return '$name • $code • หมดอายุ $exp • คงเหลือ $qty';
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  _listSection(
                    title: 'สินค้าขายดี $periodDays วัน',
                    emptyText:
                        'ยังไม่มีข้อมูลการขายในช่วง $periodDays วันล่าสุด',
                    items: topProducts.map((p) {
                      final name = (p['productName'] ?? '-').toString();
                      final amount = _currency(p['totalAmount']);
                      final qty = _asNum(p['totalQty']);
                      return '$name • ยอดขาย $amount • จำนวน $qty';
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'อัปเดตล่าสุด: ${_dateTimeThai((_dashboard?['generatedAt']).toString())}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _periodFilter() {
    return Wrap(
      spacing: 8,
      children: [7, 14, 30].map((d) {
        final selected = _selectedDays == d;
        return ChoiceChip(
          selected: selected,
          label: Text('$d วัน'),
          onSelected: (_) async {
            if (_selectedDays == d) return;
            setState(() => _selectedDays = d);
            await _load();
          },
        );
      }).toList(),
    );
  }

  Widget _summaryGrid(BuildContext context, Map kpis, int periodDays) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;
    final cardWidth = isWide
        ? (width - 16 * 2 - 10 * 3) / 4
        : (width - 16 * 2 - 10) / 2;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        SizedBox(
          width: cardWidth,
          child: _kpiCard(
            'ยอดขายวันนี้',
            _currency(kpis['salesToday']),
            const Color(0xFFEFF7D8),
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: _kpiCard(
            'ยอดขาย $periodDays วัน',
            _currency(kpis['salesPeriod']),
            const Color(0xFFE7F2FF),
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: _kpiCard(
            'ออเดอร์วันนี้',
            '${_asInt(kpis['ordersToday'])}',
            const Color(0xFFFFF4DD),
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: _kpiCard(
            'รอจัดส่ง',
            '${_asInt(kpis['pendingShipmentOrders'])}',
            const Color(0xFFFFE7E7),
          ),
        ),
      ],
    );
  }

  Widget _kpiCard(String title, String value, Color color) {
    return Container(
      height: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _salesTrendSection(
    List<Map<String, dynamic>> dailyTrend,
    int periodDays,
  ) {
    final maxSales = dailyTrend.isEmpty
        ? 0.0
        : dailyTrend
              .map((e) => _asDouble(e['sales']))
              .reduce((a, b) => a > b ? a : b);

    return _sectionCard(
      title: 'แนวโน้มยอดขาย $periodDays วัน',
      subtitle: 'ดูจังหวะขายขึ้น/ลง และจำนวนออเดอร์รายวัน',
      child: dailyTrend.isEmpty
          ? const Text('ยังไม่มีข้อมูลยอดขายย้อนหลัง')
          : Column(
              children: [
                SizedBox(
                  height: 150,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: dailyTrend.map((d) {
                      final sales = _asDouble(d['sales']);
                      final orders = _asInt(d['orders']);
                      final h = maxSales <= 0
                          ? 8.0
                          : (sales / maxSales) * 100 + 8;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                _currencyCompact(sales),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black54,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: h.clamp(8.0, 120.0),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF9DC56D),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$ordersออเดอร์',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _dayLabel(d['date']?.toString()),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'สูงสุดในช่วงนี้: ${_currency(maxSales)}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _insightSection(
    Map<String, dynamic>? bestSeller,
    List<Map<String, dynamic>> slowMoving,
    List<Map<String, dynamic>> recommendations,
    int periodDays,
  ) {
    return _sectionCard(
      title: 'Insight การขาย',
      subtitle: 'โฟกัสตัวขายดีและตัวที่ควรเร่งโปรโมต',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bestSeller != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF7D8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'ขายดีสุด $periodDays วัน: ${(bestSeller['productName'] ?? '-').toString()}'
                ' • ยอดขาย ${_currency(bestSeller['totalAmount'])}'
                ' • จำนวน ${_asNum(bestSeller['totalQty'])}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ] else ...[
            const Text(
              'ยังไม่มีสินค้าขายดีใน 7 วันล่าสุด',
              style: TextStyle(color: Colors.black54),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'สินค้าเคลื่อนไหวช้า',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          if (slowMoving.isEmpty)
            const Text(
              'ไม่มีข้อมูลสินค้าเคลื่อนไหวช้า',
              style: TextStyle(color: Colors.black54),
            )
          else
            Column(
              children: slowMoving.take(5).map((p) {
                final qty = _asDouble(p['totalQty']);
                final amount = _asDouble(p['totalAmount']);
                final reason = qty <= 0
                    ? 'ยังไม่มียอดขายใน $periodDays วัน'
                    : 'ยอดขายต่ำใน $periodDays วัน';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(
                        child: Text(
                          '${(p['productName'] ?? '-').toString()}'
                          ' • ขาย ${_asNum(qty)}'
                          ' • ${_currency(amount)}'
                          ' ($reason)',
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 10),
          const Text(
            'แนะนำโปรโมตอัตโนมัติ',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          if (recommendations.isEmpty)
            const Text(
              'ยังไม่มีสินค้าที่เข้าเกณฑ์โปรโมต',
              style: TextStyle(color: Colors.black54),
            )
          else
            Column(
              children: recommendations.map((r) {
                final plan = (r['suggestedPlan'] as Map?) ?? const {};
                final name = (r['productName'] ?? '-').toString();
                final reason = (r['reason'] ?? '-').toString();
                final planName = (plan['name'] ?? '-').toString();
                final perDay = _currency(plan['pricePerDay']);
                final days = _asInt(plan['recommendedDays']);
                final est = _currency(plan['estimatedCost']);
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6DC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'แนะนำโปรโมต: $name',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'เหตุผล: $reason',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'แพ็กเกจ: $planName ($perDay/วัน x $days วัน = $est)',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'ยังไม่คิดเงินจนกว่าจะกดยืนยันเริ่มโปรโมต',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonal(
                          onPressed: () => _confirmStartPromotion(r),
                          child: const Text('เริ่มโปรโมต'),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _activePromotionsSection() {
    return _sectionCard(
      title: 'แคมเปญโปรโมตที่กำลังรัน',
      subtitle: 'ระบบเริ่มคิดค่าบริการตามแพ็กเกจหลังกดยืนยันเริ่มโปรโมต',
      child: _activePromotions.isEmpty
          ? const Text(
              'ยังไม่มีแคมเปญที่กำลังรัน',
              style: TextStyle(color: Colors.black54),
            )
          : Column(
              children: _activePromotions.take(5).map((p) {
                final product = ((p['product'] as Map?)?['name'] ?? '-')
                    .toString();
                final plan = (p['planName'] ?? '-').toString();
                final endsAt = _dateThai((p['endsAt'] ?? '').toString());
                final est = _currency(p['estimatedCost']);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(
                        child: Text('$product • $plan • ถึง $endsAt • งบ $est'),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Future<void> _confirmStartPromotion(
    Map<String, dynamic> recommendation,
  ) async {
    final token = widget.authApi.accessToken;
    if (token == null || token.isEmpty) return;
    final productId = (recommendation['productId'] ?? '').toString();
    final productName = (recommendation['productName'] ?? '-').toString();
    final plan = ((recommendation['suggestedPlan'] as Map?) ?? const {});
    final planCode = (plan['planCode'] ?? '').toString();
    final planName = (plan['name'] ?? '').toString();
    final days = _asInt(plan['recommendedDays']);
    final est = _currency(plan['estimatedCost']);
    if (productId.isEmpty || planCode.isEmpty || days <= 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันเริ่มโปรโมต'),
        content: Text(
          'สินค้า: $productName\n'
          'แพ็กเกจ: $planName\n'
          'ระยะเวลา: $days วัน\n'
          'ค่าใช้จ่ายประมาณ: $est\n\n'
          'กดยืนยันเพื่อเริ่มโปรโมตผ่านแพลตฟอร์ม',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _catalogApi.startPromotionCampaign(
        accessToken: token,
        productId: productId,
        planCode: planCode,
        days: days,
        note: 'Started from dashboard recommendation',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เริ่มโปรโมต $productName แล้ว')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เริ่มโปรโมตไม่สำเร็จ: $e')));
    }
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _listSection({
    required String title,
    required String emptyText,
    required List<String> items,
  }) {
    return _sectionCard(
      title: title,
      child: items.isEmpty
          ? Text(emptyText, style: const TextStyle(color: Colors.black54))
          : Column(
              children: items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(child: Text(item)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _kvRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              key,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _toMapList(dynamic raw) {
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _asNum(dynamic value) {
    if (value == null) return '0';
    final n = value is num ? value : num.tryParse(value.toString());
    if (n == null) return '0';
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toStringAsFixed(2);
  }

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _currency(dynamic value) => '฿${_asNum(value)}';

  String _currencyCompact(dynamic value) {
    final n = _asDouble(value);
    if (n >= 1000000) return '฿${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '฿${(n / 1000).toStringAsFixed(1)}k';
    return '฿${n.toStringAsFixed(n == n.roundToDouble() ? 0 : 1)}';
  }

  String _dateThai(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    const m = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];
    final local = d.toLocal();
    return '${local.day} ${m[local.month - 1]} ${local.year}';
  }

  String _dateTimeThai(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    final local = d.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${_dateThai(local.toIso8601String())} $hh:$mm';
  }

  String _dayLabel(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    const wk = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];
    final local = d.toLocal();
    final idx = (local.weekday - 1).clamp(0, 6);
    return '${wk[idx]} ${local.day}';
  }
}
