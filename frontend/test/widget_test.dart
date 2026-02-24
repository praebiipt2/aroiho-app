import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app.dart';

void main() {
  testWidgets('App boots to login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AroihoApp()));
    await tester.pumpAndSettle();

    expect(find.text('ล็อกอิน'), findsOneWidget);
  });
}
