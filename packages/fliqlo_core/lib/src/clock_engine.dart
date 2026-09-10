import 'dart:async';

import 'package:flutter/foundation.dart';

import 'clock_snapshot.dart';
import 'digit_slot.dart';
import 'flip_state.dart';

/// Drives clock digits and notifies listeners when the display should update.
///
/// Flip *progress* is owned by the UI ([AnimationController]); this engine
/// detects digit transitions and exposes from→to pairs in [ClockSnapshot.flips].
///
/// Ticking uses wall-clock-aligned one-shot [Timer]s (not a fixed poll interval):
/// next second when [showSeconds] is true, otherwise next minute.
class ClockEngine extends ChangeNotifier {
  ClockEngine({
    bool use24Hour = true,
    bool showSeconds = false,
    DateTime Function()? clock,
  })  : _use24Hour = use24Hour,
        _showSeconds = showSeconds,
        _clock = clock ?? DateTime.now;

  /// Extra delay past the wall-clock boundary so [DateTime] has advanced on
  /// every platform before we sample digits.
  static const Duration boundarySlop = Duration(milliseconds: 16);

  /// Floor for one-shot delays (avoids zero/negative [Timer] edge cases).
  static const Duration minScheduleDelay = Duration(milliseconds: 1);

  final DateTime Function() _clock;

  bool _use24Hour;
  bool _showSeconds;
  Timer? _timer;
  bool _running = false;
  ClockSnapshot? _snapshot;
  FlipStateMap _flips = {};

  ClockSnapshot? get snapshot => _snapshot;
  bool get use24Hour => _use24Hour;
  bool get showSeconds => _showSeconds;
  bool get isRunning => _running;

  /// Delay from [now] until the next display boundary (+ [boundarySlop]).
  static Duration delayUntilNextBoundary(
    DateTime now, {
    required bool showSeconds,
  }) {
    final Duration elapsedInPeriod;
    final Duration period;
    if (showSeconds) {
      period = const Duration(seconds: 1);
      elapsedInPeriod = Duration(
        milliseconds: now.millisecond,
        microseconds: now.microsecond,
      );
    } else {
      period = const Duration(minutes: 1);
      elapsedInPeriod = Duration(
        seconds: now.second,
        milliseconds: now.millisecond,
        microseconds: now.microsecond,
      );
    }

    var delay = period - elapsedInPeriod + boundarySlop;
    if (delay < minScheduleDelay) {
      delay = minScheduleDelay;
    }
    return delay;
  }

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
      if (_running) {
        _scheduleNext();
      }
    }
  }

  void start() {
    if (_running) return;
    _running = true;
    _tick(force: true);
    _scheduleNext();
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Recompute digits from the clock (used by tests and manual refresh).
  void refresh() => _tick();

  void _scheduleNext() {
    _timer?.cancel();
    if (!_running) {
      _timer = null;
      return;
    }
    final delay = delayUntilNextBoundary(
      _clock(),
      showSeconds: _showSeconds,
    );
    _timer = Timer(delay, _onScheduledTick);
  }

  void _onScheduledTick() {
    if (!_running) return;
    _tick();
    _scheduleNext();
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

    // When seconds are hidden, second-digit churn must not notify — otherwise
    // the UI rebuilds/rasters every second despite an unchanged H:M face.
    final secondsChanged = previous != null &&
        _showSeconds &&
        (previous.secondTens != digits[DigitSlot.secondTens] ||
            previous.secondOnes != digits[DigitSlot.secondOnes]);

    final digitsChanged = previous == null ||
        force ||
        previous.hourTens != digits[DigitSlot.hourTens] ||
        previous.hourOnes != digits[DigitSlot.hourOnes] ||
        previous.minuteTens != digits[DigitSlot.minuteTens] ||
        previous.minuteOnes != digits[DigitSlot.minuteOnes] ||
        secondsChanged ||
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
