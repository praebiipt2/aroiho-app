import 'package:flutter/material.dart';
import '../api/auth_api.dart';
import '../widgets/province_district_picker.dart';
import '../storage/profile_store.dart';

enum SignupStep { form, otp }

class SignupScreen extends StatefulWidget {
  final AuthApi authApi;
  const SignupScreen({super.key, required this.authApi});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  SignupStep step = SignupStep.form;

  // จังหวัด/อำเภอ
  ProvinceDistrictValue pd = const ProvinceDistrictValue();

  // controllers
  final nameCtl = TextEditingController();
  final emailCtl = TextEditingController();
  final phoneCtl = TextEditingController(text: '0800000001');
  final addressCtl = TextEditingController();
  final passCtl = TextEditingController();
  final pass2Ctl = TextEditingController();

  // otp
  final otpCtl = TextEditingController();
  String? requestId;

  bool acceptTerms = false;
  bool loading = false;
  String? error;

  InputDecoration _deco(String hint, {IconData? icon}) => InputDecoration(
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      );

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('409') || msg.contains('Email นี้ถูกใช้งานแล้ว')) {
      return 'อีเมลนี้ถูกใช้งานแล้ว กรุณาเปลี่ยนอีเมล';
    }
    if (msg.contains('P2002') && msg.toLowerCase().contains('email')) {
      return 'อีเมลนี้ถูกใช้งานแล้ว กรุณาเปลี่ยนอีเมล';
    }
    return msg;
  }

  bool _validateForm() {
    final name = nameCtl.text.trim();
    final email = emailCtl.text.trim();
    final phone = phoneCtl.text.trim();
    final pass = passCtl.text;
    final pass2 = pass2Ctl.text;

    if (name.isEmpty) {
      error = 'กรุณากรอกชื่อ-นามสกุล';
      return false;
    }
    if (email.isEmpty || !email.contains('@')) {
      error = 'กรุณากรอกอีเมลให้ถูกต้อง';
      return false;
    }
    if (phone.length < 9) {
      error = 'กรุณากรอกเบอร์โทรศัพท์ให้ถูกต้อง';
      return false;
    }
    if (pd.province == null || pd.district == null) {
      error = 'กรุณาเลือกจังหวัด/อำเภอ';
      return false;
    }
    if (addressCtl.text.trim().isEmpty) {
      error = 'กรุณากรอกที่อยู่';
      return false;
    }
    if (pass.length < 6) {
      error = 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
      return false;
    }
    if (pass != pass2) {
      error = 'รหัสผ่านและยืนยันรหัสผ่านไม่ตรงกัน';
      return false;
    }
    if (!acceptTerms) {
      error = 'กรุณายอมรับข้อตกลงและเงื่อนไข';
      return false;
    }

    error = null;
    return true;
  }

  Future<void> _createAccountSendOtp() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      if (!_validateForm()) {
        setState(() => loading = false);
        return;
      }

      requestId = await widget.authApi.requestOtp(phoneCtl.text.trim());

      setState(() {
        step = SignupStep.otp;
      });
    } catch (e) {
      setState(() => error = _friendlyError(e));
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _verifyOtpFinish() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final otp = otpCtl.text.trim();
      if (otp.length < 4) {
        setState(() {
          error = 'กรุณากรอกรหัส OTP';
          loading = false;
        });
        return;
      }

      await widget.authApi.verifyOtp(
        phone: phoneCtl.text.trim(),
        otp: otp,
        requestId: requestId ?? '',
      );

      await widget.authApi.updateMe(
        displayName: nameCtl.text.trim(),
        email: emailCtl.text.trim(),
      );

      await widget.authApi.me();

      await ProfileStore.save(
        name: nameCtl.text.trim(),
        email: emailCtl.text.trim(),
        phone: phoneCtl.text.trim(),
        province: pd.province,
        district: pd.district,
        address: addressCtl.text.trim(),
      );

      if (!mounted) return;

      // ✅ สมัครใหม่ -> พาไป onboarding ทันที
      Navigator.pushReplacementNamed(context, '/onboarding/reason');
    } catch (e) {
      setState(() => error = _friendlyError(e));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    nameCtl.dispose();
    emailCtl.dispose();
    phoneCtl.dispose();
    addressCtl.dispose();
    passCtl.dispose();
    pass2Ctl.dispose();
    otpCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6E8),
      appBar: AppBar(
        title: const Text('ลงทะเบียน'),
        backgroundColor: const Color(0xFFF5F6E8),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6E8),
                borderRadius: BorderRadius.circular(18),
              ),
              child: step == SignupStep.form ? _buildForm() : _buildOtp(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ลงทะเบียน',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: nameCtl,
          decoration: _deco('ชื่อ-นามสกุล', icon: Icons.person_outline),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: emailCtl,
          decoration: _deco('อีเมล', icon: Icons.email_outlined),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: phoneCtl,
          keyboardType: TextInputType.phone,
          decoration: _deco('เบอร์โทรศัพท์', icon: Icons.phone_outlined),
        ),
        const SizedBox(height: 10),
        ProvinceDistrictPicker(
          value: pd,
          onChanged: (v) => setState(() => pd = v),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: addressCtl,
          decoration: _deco('ที่อยู่', icon: Icons.location_on_outlined),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: passCtl,
          obscureText: true,
          decoration: _deco('รหัสผ่านใหม่', icon: Icons.lock_outline),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: pass2Ctl,
          obscureText: true,
          decoration: _deco('ยืนยันรหัสผ่าน', icon: Icons.lock_outline),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Checkbox(
              value: acceptTerms,
              onChanged: (v) => setState(() => acceptTerms = v ?? false),
            ),
            const Expanded(
              child: Text(
                'ยินยอมรับข้อตกลงและเงื่อนไข รวมถึงนโยบายความเป็นส่วนตัว',
              ),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: loading ? null : _createAccountSendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F2F2F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(loading ? 'กำลังทำรายการ...' : 'สร้างบัญชี'),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('มีบัญชีอยู่แล้ว? เข้าสู่ระบบ'),
          ),
        ),
      ],
    );
  }

  Widget _buildOtp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ยืนยันตัวตน',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text('เราได้ส่งรหัส OTP ไปที่เบอร์ ${phoneCtl.text.trim()} แล้ว'),
        const SizedBox(height: 12),
        TextField(
          controller: otpCtl,
          keyboardType: TextInputType.number,
          decoration: _deco('กรอกรหัส OTP', icon: Icons.sms_outlined),
        ),
        const SizedBox(height: 6),
        if (requestId != null)
          Text('requestId: $requestId', style: const TextStyle(fontSize: 12)),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: loading ? null : _verifyOtpFinish,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F2F2F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(loading ? 'กำลังตรวจสอบ...' : 'ยืนยัน OTP'),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: loading
                ? null
                : () async {
                    setState(() {
                      error = null;
                      loading = true;
                    });
                    try {
                      requestId = await widget.authApi.requestOtp(phoneCtl.text.trim());
                      setState(() {});
                    } catch (e) {
                      setState(() => error = _friendlyError(e));
                    } finally {
                      setState(() => loading = false);
                    }
                  },
            child: const Text('ส่งรหัสใหม่'),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: loading
                ? null
                : () {
                    setState(() {
                      step = SignupStep.form;
                      otpCtl.clear();
                      error = null;
                    });
                  },
            child: const Text('แก้ไขข้อมูล'),
          ),
        ),
      ],
    );
  }
}