import 'dart:async';

import 'package:flutter/foundation.dart';

import 'clock_snapshot.dart';
import 'digit_slot.dart';
import 'flip_state.dart';

/// Drives clock digits and notifies listeners when the display should update.
///
/// Flip *progress* is owned by the UI ([AnimationController]); this engine
/// detects digit transitions and exposes from→to pairs in [ClockSnapshot.flips].
class ClockEngine extends ChangeNotifier {
  ClockEngine({
    bool use24Hour = true,
    bool showSeconds = false,
    DateTime Function()? clock,
  })  : _use24Hour = use24Hour,
        _showSeconds = showSeconds,
        _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  bool _use24Hour;
  bool _showSeconds;
  Timer? _timer;
  ClockSnapshot? _snapshot;
  FlipStateMap _flips = {};

  ClockSnapshot? get snapshot => _snapshot;
  bool get use24Hour => _use24Hour;
  bool get showSeconds => _showSeconds;
  bool get isRunning => _timer != null;

  void updateOptions({bool? use24Hour, bool? showSeconds}) {
    var changed = false;
    if (use24Hour != null && use24Hour != _use24Hour) {
      _use24Hour = use24Hour;
      changed = true;
    }
    if (showSeconds != null && showSeconds != _showSeconds) {
      _showSeconds = showSeconds;
      changed = true;
    }
    if (changed) {
      _tick(force: true);
      _restartTimer();
    }
  }

  void start() {
    if (_timer != null) return;
    _tick(force: true);
    _restartTimer();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Recompute digits from the clock (used by tests and manual refresh).
  void refresh() => _tick();

  void _restartTimer() {
    _timer?.cancel();
    final interval =
        _showSeconds ? const Duration(milliseconds: 200) : const Duration(seconds: 1);
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  void _tick({bool force = false}) {
    final now = _clock();
    final digits = _digitsFor(now);
    final previous = _snapshot;

    final nextFlips = <DigitSlot, FlipState>{};
    for (final slot in DigitSlot.values) {
      final nextDigit = digits[slot]!;
      final prevDigit = previous?.digitFor(slot);
      if (previous == null || force) {
        nextFlips[slot] = FlipState.settled(nextDigit);
      } else if (prevDigit != nextDigit) {
        nextFlips[slot] = FlipState(from: prevDigit!, to: nextDigit, progress: 0);
      } else {
        nextFlips[slot] = FlipState.settled(nextDigit);
      }
    }

    final digitsChanged = previous == null ||
        force ||
        previous.hourTens != digits[DigitSlot.hourTens] ||
        previous.hourOnes != digits[DigitSlot.hourOnes] ||
        previous.minuteTens != digits[DigitSlot.minuteTens] ||
        previous.minuteOnes != digits[DigitSlot.minuteOnes] ||
        previous.secondTens != digits[DigitSlot.secondTens] ||
        previous.secondOnes != digits[DigitSlot.secondOnes] ||
        previous.showSeconds != _showSeconds ||
        previous.use24Hour != _use24Hour ||
        previous.isPm != (now.hour >= 12);

    if (!digitsChanged && !force) {
      return;
    }

    _flips = nextFlips;
    _snapshot = ClockSnapshot(
      now: now,
      hourTens: digits[DigitSlot.hourTens]!,
      hourOnes: digits[DigitSlot.hourOnes]!,
      minuteTens: digits[DigitSlot.minuteTens]!,
      minuteOnes: digits[DigitSlot.minuteOnes]!,
      secondTens: digits[DigitSlot.secondTens]!,
      secondOnes: digits[DigitSlot.secondOnes]!,
      flips: Map.unmodifiable(_flips),
      showSeconds: _showSeconds,
      use24Hour: _use24Hour,
      isPm: now.hour >= 12,
    );
    notifyListeners();
  }

  Map<DigitSlot, int> _digitsFor(DateTime now) {
    var hour = now.hour;
    if (!_use24Hour) {
      hour = hour % 12;
      if (hour == 0) hour = 12;
    }
    final minute = now.minute;
    final second = now.second;
    return {
      DigitSlot.hourTens: hour ~/ 10,
      DigitSlot.hourOnes: hour % 10,
      DigitSlot.minuteTens: minute ~/ 10,
      DigitSlot.minuteOnes: minute % 10,
      DigitSlot.secondTens: second ~/ 10,
      DigitSlot.secondOnes: second % 10,
    };
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
