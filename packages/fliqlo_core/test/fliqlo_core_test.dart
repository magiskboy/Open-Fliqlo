import 'package:flutter_test/flutter_test.dart';
import 'package:fliqlo_core/fliqlo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ClockEngine', () {
    test('emits settled digits for initial time', () {
      final engine = ClockEngine(
        clock: () => DateTime(2026, 9, 9, 14, 35, 42),
      )..start();
      final snap = engine.snapshot!;
      expect(snap.hourTens, 1);
      expect(snap.hourOnes, 4);
      expect(snap.minuteTens, 3);
      expect(snap.minuteOnes, 5);
      expect(snap.secondTens, 4);
      expect(snap.secondOnes, 2);
      expect(snap.flipFor(DigitSlot.minuteOnes).isFlipping, isFalse);
      engine.dispose();
    });

    test('12-hour mode maps midnight and 13:00 correctly', () {
      final midnight = ClockEngine(
        use24Hour: false,
        clock: () => DateTime(2026, 9, 9, 0, 0),
      )..start();
      expect(midnight.snapshot!.hourTens, 1);
      expect(midnight.snapshot!.hourOnes, 2);
      expect(midnight.snapshot!.amPmLabel, 'AM');
      expect(midnight.snapshot!.isPm, isFalse);
      midnight.dispose();

      final pm = ClockEngine(
        use24Hour: false,
        clock: () => DateTime(2026, 9, 9, 13, 5),
      )..start();
      expect(pm.snapshot!.hourTens, 0);
      expect(pm.snapshot!.hourOnes, 1);
      expect(pm.snapshot!.amPmLabel, 'PM');
      expect(pm.snapshot!.isPm, isTrue);
      pm.dispose();
    });

    test('24-hour mode hides AM/PM label', () {
      final engine = ClockEngine(
        use24Hour: true,
        clock: () => DateTime(2026, 9, 9, 15, 0),
      )..start();
      expect(engine.snapshot!.amPmLabel, isNull);
      engine.dispose();
    });

    test('detects minute digit flip when time advances', () {
      final times = <DateTime>[
        DateTime(2026, 9, 9, 10, 0, 59),
        DateTime(2026, 9, 9, 10, 1, 0),
      ];
      var index = 0;
      final engine = ClockEngine(
        showSeconds: true,
        clock: () => times[index],
      )..start();
      expect(engine.snapshot!.minuteOnes, 0);
      expect(engine.snapshot!.secondOnes, 9);

      index = 1;
      engine.refresh();
      expect(engine.snapshot!.minuteOnes, 1);
      final flip = engine.snapshot!.flipFor(DigitSlot.minuteOnes);
      expect(flip.from, 0);
      expect(flip.to, 1);
      expect(flip.isFlipping, isTrue);
      engine.dispose();
    });

    test('switching 12/24 hour resettles without flip artifact', () {
      final engine = ClockEngine(
        use24Hour: true,
        clock: () => DateTime(2026, 9, 9, 13, 0),
      )..start();
      expect(engine.snapshot!.hourTens, 1);
      expect(engine.snapshot!.hourOnes, 3);
      engine.updateOptions(use24Hour: false);
      expect(engine.snapshot!.hourOnes, 1);
      expect(engine.snapshot!.flipFor(DigitSlot.hourOnes).isFlipping, isFalse);
      engine.dispose();
    });
  });

  group('SettingsStore', () {
    test('load and persist settings', () async {
      SharedPreferences.setMockInitialValues({
        'use24Hour': false,
        'dim': 0.4,
        'forceLandscape': true,
      });
      final store = SettingsStore();
      await store.load();
      expect(store.settings.use24Hour, isFalse);
      expect(store.settings.dim, 0.4);
      expect(store.settings.forceLandscape, isTrue);

      await store.patch(showSeconds: true, scale: 0.8, forceLandscape: false);
      expect(store.settings.showSeconds, isTrue);
      expect(store.settings.scale, 0.8);
      expect(store.settings.forceLandscape, isFalse);

      final store2 = SettingsStore();
      await store2.load();
      expect(store2.settings.showSeconds, isTrue);
      expect(store2.settings.scale, 0.8);
      expect(store2.settings.use24Hour, isFalse);
      expect(store2.settings.forceLandscape, isFalse);
    });
  });
}
