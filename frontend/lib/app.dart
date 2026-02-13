import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'api/auth_api.dart';

import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_reason_screen.dart';
import 'screens/onboarding_food_screen.dart';

class AroihoApp extends StatefulWidget {
  const AroihoApp({super.key});

  @override
  State<AroihoApp> createState() => _AroihoAppState();
}

class _AroihoAppState extends State<AroihoApp> {
  late final AuthApi authApi;

  @override
  void initState() {
    super.initState();
    authApi = AuthApi();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aroiho',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF5F6E8),
        useMaterial3: true,
      ),
      routes: {
        '/': (_) => LoginScreen(authApi: authApi),
        '/signup': (_) => SignupScreen(authApi: authApi),
        '/home': (_) => HomeScreen(authApi: authApi),

        // ✅ onboarding
        '/onboarding/reason': (_) => const OnboardingReasonScreen(),
        '/onboarding/food': (_) => const OnboardingFoodScreen(),
      },
    );
  }
}
