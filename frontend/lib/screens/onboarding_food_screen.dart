import 'package:flutter/material.dart';
import '../storage/profile_store.dart';

class OnboardingFoodScreen extends StatefulWidget {
  const OnboardingFoodScreen({super.key});

  @override
  State<OnboardingFoodScreen> createState() => _OnboardingFoodScreenState();
}

class _OnboardingFoodScreenState extends State<OnboardingFoodScreen> {
  final Set<String> selected = {};
  bool saving = false;

  final List<(String emoji, String label)> options = const [
    ('🥬', 'ผัก & ออร์แกนิค'),
    ('🦐', 'ของทะเล / กุ้ง'),
    ('🍎', 'ผลไม้'),
    ('🥗', 'อาหารคลีน'),
    ('🍞', 'โฮมเมด'),
    ('🍱', 'อาหารพร้อมทาน'),
  ];

  Future<void> _finish(List<String> reasons) async {
    setState(() => saving = true);
    try {
      await ProfileStore.saveOnboarding(
        reasons: reasons,
        foods: selected.toList(),
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFFB8C94A);

    final reasons = (ModalRoute.of(context)?.settings.arguments as List<String>?) ?? <String>[];

    Widget optionTile(String emoji, String label) {
      final active = selected.contains(label);
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            if (active) {
              selected.remove(label);
            } else {
              selected.add(label);
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? brandColor : const Color(0xFFE6E6E6),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              if (active)
                const Icon(Icons.check_circle, color: brandColor, size: 20)
              else
                const SizedBox(width: 20),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/onboarding/onboarding_bg.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFFF2F2EC),
            ),
          ),
          Container(color: Colors.white.withValues(alpha: 0.48)),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios_new),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 72,
                        width: 260,
                        child: ClipRect(
                          child: Transform.scale(
                            scale: 3.3,
                            alignment: Alignment.center,
                            child: Image.asset(
                              'assets/logo/aroiho_logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const Text(
                        'ให้ aroiho แนะนำได้ตรงใจคุณมากขึ้น',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 18),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'ปกติคุณซื้ออะไรบ่อย?',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...options.map((o) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: optionTile(o.$1, o.$2),
                          )),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: saving ? null : () => _finish(reasons),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandColor,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            saving ? 'กำลังบันทึก...' : 'ถัดไป',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
