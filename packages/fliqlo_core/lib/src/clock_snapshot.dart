import 'digit_slot.dart';
import 'flip_state.dart';

/// Immutable view of the clock at a point in time.
class ClockSnapshot {
  const ClockSnapshot({
    required this.now,
    required this.hourTens,
    required this.hourOnes,
    required this.minuteTens,
    required this.minuteOnes,
    required this.secondTens,
    required this.secondOnes,
    required this.flips,
    required this.showSeconds,
    required this.use24Hour,
    required this.isPm,
  });

  final DateTime now;
  final int hourTens;
  final int hourOnes;
  final int minuteTens;
  final int minuteOnes;
  final int secondTens;
  final int secondOnes;
  final FlipStateMap flips;
  final bool showSeconds;
  final bool use24Hour;

  /// True when [now] is afternoon/evening. Meaningful when [use24Hour] is false.
  final bool isPm;

  /// `AM` / `PM` for 12-hour mode; `null` in 24-hour mode.
  String? get amPmLabel {
    if (use24Hour) return null;
    return isPm ? 'PM' : 'AM';
  }

  int digitFor(DigitSlot slot) {
    switch (slot) {
      case DigitSlot.hourTens:
        return hourTens;
      case DigitSlot.hourOnes:
        return hourOnes;
      case DigitSlot.minuteTens:
        return minuteTens;
      case DigitSlot.minuteOnes:
        return minuteOnes;
      case DigitSlot.secondTens:
        return secondTens;
      case DigitSlot.secondOnes:
        return secondOnes;
    }
  }

  FlipState flipFor(DigitSlot slot) =>
      flips[slot] ?? FlipState.settled(digitFor(slot));
}
