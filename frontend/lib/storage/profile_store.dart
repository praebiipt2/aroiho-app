import 'package:shared_preferences/shared_preferences.dart';

class ProfileStore {
  static const _kName = 'profile_name';
  static const _kEmail = 'profile_email';
  static const _kPhone = 'profile_phone';
  static const _kProvince = 'profile_province';
  static const _kDistrict = 'profile_district';
  static const _kAddress = 'profile_address';

  // onboarding
  static const _kOnboardingDone = 'onboarding_done';
  static const _kOnboardingReasons = 'onboarding_reasons';
  static const _kOnboardingFoods = 'onboarding_foods';

  static Future<void> save({
    required String name,
    required String email,
    required String phone,
    required String? province,
    required String? district,
    required String address,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kName, name);
    await sp.setString(_kEmail, email);
    await sp.setString(_kPhone, phone);
    await sp.setString(_kProvince, province ?? '');
    await sp.setString(_kDistrict, district ?? '');
    await sp.setString(_kAddress, address);
  }

  static Future<Map<String, String>> load() async {
    final sp = await SharedPreferences.getInstance();
    return {
      'name': sp.getString(_kName) ?? '',
      'email': sp.getString(_kEmail) ?? '',
      'phone': sp.getString(_kPhone) ?? '',
      'province': sp.getString(_kProvince) ?? '',
      'district': sp.getString(_kDistrict) ?? '',
      'address': sp.getString(_kAddress) ?? '',
    };
  }

  static Future<void> saveOnboarding({
    required List<String> reasons,
    required List<String> foods,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_kOnboardingReasons, reasons);
    await sp.setStringList(_kOnboardingFoods, foods);
    await sp.setBool(_kOnboardingDone, true);
  }

  static Future<bool> isOnboardingDone() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kOnboardingDone) ?? false;
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kName);
    await sp.remove(_kEmail);
    await sp.remove(_kPhone);
    await sp.remove(_kProvince);
    await sp.remove(_kDistrict);
    await sp.remove(_kAddress);

    // onboarding
    await sp.remove(_kOnboardingDone);
    await sp.remove(_kOnboardingReasons);
    await sp.remove(_kOnboardingFoods);
  }
}