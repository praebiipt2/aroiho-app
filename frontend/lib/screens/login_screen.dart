import 'package:flutter/material.dart';
import '../api/auth_api.dart';
import '../storage/profile_store.dart';

enum LoginTab { phone, email }
enum PhoneStep { enterPhone, enterOtp }

class LoginScreen extends StatefulWidget {
  final AuthApi authApi;
  const LoginScreen({super.key, required this.authApi});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  LoginTab tab = LoginTab.phone;
  PhoneStep step = PhoneStep.enterPhone;

  final phoneCtl = TextEditingController(text: '0800000001');
  final otpCtl = TextEditingController();
  String? requestId;

  bool loading = false;
  String? error;

  Future<void> sendOtp() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final phone = phoneCtl.text.trim();
      requestId = await widget.authApi.requestOtp(phone);
      setState(() => step = PhoneStep.enterOtp);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> verifyOtp() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final phone = phoneCtl.text.trim();
      final otp = otpCtl.text.trim();
      final rid = requestId ?? '';

      await widget.authApi.verifyOtp(phone: phone, otp: otp, requestId: rid);
      await widget.authApi.me();

      final done = await ProfileStore.isOnboardingDone();
      if (!mounted) return;

      Navigator.pushReplacementNamed(context, done ? '/home' : '/onboarding/reason');
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    phoneCtl.dispose();
    otpCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget tabButton(String text, bool active, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFB8C94A) : const Color(0xFFE9E9E9),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('เข้าสู่ระบบ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      tabButton('phone', tab == LoginTab.phone, () {
                        setState(() {
                          tab = LoginTab.phone;
                          step = PhoneStep.enterPhone;
                          error = null;
                        });
                      }),
                      const SizedBox(width: 10),
                      tabButton('email', tab == LoginTab.email, () {
                        setState(() {
                          tab = LoginTab.email;
                          error = null;
                        });
                      }),
                    ],
                  ),

                  const SizedBox(height: 18),

                  if (tab == LoginTab.phone) ...[
                    TextField(
                      controller: phoneCtl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: 'กรอกเบอร์โทรศัพท์',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (step == PhoneStep.enterOtp) ...[
                      TextField(
                        controller: otpCtl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'กรอกรหัส OTP',
                          filled: true,
                          fillColor: Colors.white,
                          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                          helperText: requestId != null ? 'requestId: $requestId' : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (error != null) ...[
                      Text(error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                    ],

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: loading ? null : (step == PhoneStep.enterPhone ? sendOtp : verifyOtp),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2F2F2F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          loading
                              ? 'กำลังทำรายการ...'
                              : (step == PhoneStep.enterPhone ? 'ส่งรหัส OTP' : 'ยืนยัน OTP'),
                        ),
                      ),
                    ),
                  ] else ...[
                    const TextField(
                      decoration: InputDecoration(
                        hintText: 'Enter your email',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const TextField(
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Email login จะเชื่อม API ในขั้นถัดไป')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2F2F2F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('เข้าสู่ระบบ'),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/signup'),
                    child: const Text('ยังไม่มีบัญชี? ลงทะเบียน'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}