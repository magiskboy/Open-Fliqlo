import 'package:flutter_test/flutter_test.dart';
import 'package:open_fliqlo/launch_mode.dart';
import 'package:open_fliqlo/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OpenFliqloApp builds in normal mode', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const OpenFliqloApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(OpenFliqloApp), findsOneWidget);
  });

  testWidgets('screensaver mode has no settings long-press path', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const OpenFliqloApp(mode: LaunchMode.screensaver));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.longPress(find.byType(OpenFliqloApp));
    await tester.pump();
    expect(find.text('Settings'), findsNothing);
  });
}
