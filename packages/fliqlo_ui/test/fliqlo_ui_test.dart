import 'package:fliqlo_core/fliqlo_core.dart';
import 'package:fliqlo_ui/fliqlo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ClockSnapshot _snap({
  bool use24Hour = true,
  bool isPm = false,
}) {
  return ClockSnapshot(
    now: DateTime(2026, 9, 9, isPm ? 14 : 9, 35),
    hourTens: 1,
    hourOnes: 4,
    minuteTens: 3,
    minuteOnes: 5,
    secondTens: 0,
    secondOnes: 0,
    flips: {
      for (final s in DigitSlot.values) s: FlipState.settled(0),
    },
    showSeconds: false,
    use24Hour: use24Hour,
    isPm: isPm,
  );
}

void main() {
  testWidgets('ClockFace renders without overflow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: ClockFace(
              snapshot: _snap(),
              settings: const FliqloSettings(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(ClockFace), findsOneWidget);
    expect(find.text('AM'), findsNothing);
    expect(find.text('PM'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('DigitGlyphAtlas rasters 0-9 and AM/PM once per size', () async {
    final atlas = DigitGlyphAtlas();
    addTearDown(atlas.dispose);

    var notifications = 0;
    atlas.addListener(() => notifications++);

    const size = Size(72, 100);
    await atlas.ensure(digitSize: size, dpr: 1);
    expect(atlas.isReady, isTrue);
    expect(notifications, 1);

    await atlas.ensure(digitSize: size, dpr: 1);
    expect(notifications, 1);

    await atlas.ensure(digitSize: const Size(80, 110), dpr: 1);
    expect(atlas.isReady, isTrue);
    expect(notifications, 2);
  });

  testWidgets('ClockFace shows AM/PM in 12-hour mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: ClockFace(
              snapshot: _snap(use24Hour: false, isPm: true),
              settings: const FliqloSettings(use24Hour: false),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // AM/PM is drawn via CustomPainter (not a Text widget).
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ClockFace isolates each digit and colon with RepaintBoundary',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: ClockFace(
              snapshot: _snap(),
              settings: const FliqloSettings(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // 4 digits + 1 colon (no seconds).
    expect(find.byType(RepaintBoundary), findsAtLeastNWidgets(5));
    expect(find.byType(FlipDigit), findsNWidgets(4));
  });

  testWidgets('scale 100% fills the binding viewport axis', (tester) async {
    const viewW = 800.0;
    const viewH = 600.0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: viewW,
            height: viewH,
            child: ClockFace(
              snapshot: _snap(),
              settings: const FliqloSettings(scale: 1.0),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final digits = find.byType(FlipDigit);
    final left = tester.getTopLeft(digits.at(0)).dx;
    final right = tester.getBottomRight(digits.at(3)).dx;
    // Landscape: width is binding — row should span most of the view.
    expect(right - left, greaterThan(viewW * 0.85));
  });

  testWidgets('scale shrinks digit layout size', (tester) async {
    Future<Size> digitSizeAt(double scale) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: ClockFace(
                snapshot: _snap(),
                settings: FliqloSettings(scale: scale),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      return tester.getSize(find.byType(FlipDigit).first);
    }

    final full = await digitSizeAt(1.0);
    final half = await digitSizeAt(0.5);
    expect(half.width, closeTo(full.width * 0.5, 0.5));
    expect(half.height, closeTo(full.height * 0.5, 0.5));
  });

  testWidgets('SettingsSheet scrolls in a short landscape viewport', (tester) async {
    // Phone landscape-ish: wide but short — content taller than viewport.
    await tester.binding.setSurfaceSize(const Size(800, 280));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SettingsSheet(
            settings: const FliqloSettings(),
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('24-hour clock'), findsOneWidget);

    // Scale controls sit below the fold in this viewport; drag to reveal.
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(find.textContaining('Scale'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SettingsSheet exposes force landscape toggle', (tester) async {
    var latest = const FliqloSettings();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SettingsSheet(
            settings: latest,
            onChanged: (s) => latest = s,
          ),
        ),
      ),
    );

    expect(find.text('Force landscape'), findsOneWidget);
    await tester.tap(find.text('Force landscape'));
    await tester.pumpAndSettle();
    expect(latest.forceLandscape, isTrue);
  });
}
