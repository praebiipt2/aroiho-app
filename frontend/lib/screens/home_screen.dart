import 'package:flutter/material.dart';
import '../api/auth_api.dart';
import '../storage/profile_store.dart';

class HomeScreen extends StatefulWidget {
  final AuthApi authApi;
  const HomeScreen({super.key, required this.authApi});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tabIndex = 0;

  // ---------- dummy data ----------
  final recommended = const [
    {
      'name': 'มะเขือเทศเชอรี่',
      'price': 95,
      'badge': 'คัดพิเศษ',
      'image': '🍅',
    },
    {
      'name': 'กรีนโอ๊ค',
      'price': 80,
      'badge': 'ออร์แกนิค',
      'image': '🥬',
    },
    {
      'name': 'ชุดผักสลัด',
      'price': 120,
      'badge': 'สดใหม่',
      'image': '🥗',
    },
  ];

  final categories = const [
    {'label': 'ออร์แกนิค', 'emoji': '🥬'},
    {'label': 'ของสด', 'emoji': '🦐'},
    {'label': 'โฮมเมด', 'emoji': '🍞'},
    {'label': 'อร่อยเหาะ', 'emoji': '✨'},
  ];

  Future<void> _resetOnboardingDev() async {
    await ProfileStore.clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6E8),
        elevation: 0,
        title: const Text(
          'aroiho',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Reset Onboarding (DEV)',
            icon: const Icon(Icons.bug_report),
            onPressed: _resetOnboardingDev,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _locationRow(),
              const SizedBox(height: 12),

              // ✅ ปุ่ม DEV (ถ้าไม่อยากโชว์บนหน้า ลบ widget นี้ได้)
              _devResetButton(),
              const SizedBox(height: 16),

              // ---------- Recommended ----------
              _sectionHeader('แนะนำสำหรับคุณวันนี้'),
              const SizedBox(height: 12),
              SizedBox(
                height: 190,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: recommended.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _recommendedCard(recommended[i]),
                ),
              ),

              const SizedBox(height: 24),

              // ---------- Categories ----------
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: categories
                    .map(
                      (c) => Chip(
                        avatar: Text(c['emoji']!),
                        label: Text(c['label']!),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    )
                    .toList(),
              ),

              const SizedBox(height: 28),

              // ---------- Highlight ----------
              _sectionHeader('คัดมาแล้ววันนี้'),
              const SizedBox(height: 12),
              _highlightCard(),
            ],
          ),
        ),
      ),

      // ---------- Bottom Nav ----------
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tabIndex,
        onTap: (i) => setState(() => tabIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Cart'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  // ---------- widgets ----------

  Widget _devResetButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _resetOnboardingDev,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text('Reset Onboarding (DEV)'),
      ),
    );
  }

  Widget _locationRow() {
    return Row(
      children: const [
        Icon(Icons.location_on, size: 18),
        SizedBox(width: 6),
        Text(
          'Current location',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        Icon(Icons.keyboard_arrow_down),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        TextButton(
          onPressed: () {},
          child: const Text('ดูเพิ่มเติม'),
        ),
      ],
    );
  }

  Widget _recommendedCard(Map<String, dynamic> item) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFB8C94A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item['badge'],
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const Spacer(),
          Text(item['image'], style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 6),
          Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            '฿${item['price']}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF4A5D23),
            ),
          ),
        ],
      ),
    );
  }

  Widget _highlightCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ชุดผักสลัด ฟาร์ม A',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'สดใหม่จากฟาร์ม ส่งตรงถึงคุณ',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '฿165',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF4A5D23),
                ),
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('ดูรายละเอียด'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB8C94A),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('ซื้อเลย'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}