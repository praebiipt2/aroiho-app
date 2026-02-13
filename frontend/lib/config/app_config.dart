class AppConfig {
  //สำคัญ
  // ถ้ารันบน iOS Simulator ใช้ localhost ได้
  // ถ้ารันบน Android Emulator ให้ใช้ 10.0.2.2 **
  // ถ้ารันบนเครื่องจริง (มือถือ) ให้ใช้ IP เครื่อง Mac ของคุณ เช่น 192.168.x.x
  static const String baseUrl = 'http://localhost:3000';

  // Android emulator example:
  // static const String baseUrl = 'http://10.0.2.2:3000';
}
