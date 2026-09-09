import 'package:flutter_test/flutter_test.dart';
import 'package:open_fliqlo/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OpenFliqloApp builds', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const OpenFliqloApp());
    await tester.pump();
    // Allow async bootstrap without waiting forever on timers.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(OpenFliqloApp), findsOneWidget);
  });
}
