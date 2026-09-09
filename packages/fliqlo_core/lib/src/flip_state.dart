import 'digit_slot.dart';

/// Flip animation state for a single digit slot.
class FlipState {
  const FlipState({
    required this.from,
    required this.to,
    this.progress = 1.0,
  });

  /// Settled digit with no active flip.
  factory FlipState.settled(int digit) => FlipState(
        from: digit,
        to: digit,
        progress: 1.0,
      );

  final int from;
  final int to;

  /// 0.0 = showing [from], 1.0 = showing [to] (settled).
  final double progress;

  bool get isFlipping => from != to && progress < 1.0;

  int get visibleDigit => progress < 0.5 ? from : to;

  FlipState copyWith({
    int? from,
    int? to,
    double? progress,
  }) {
    return FlipState(
      from: from ?? this.from,
      to: to ?? this.to,
      progress: progress ?? this.progress,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FlipState &&
        other.from == from &&
        other.to == to &&
        other.progress == progress;
  }

  @override
  int get hashCode => Object.hash(from, to, progress);
}

/// Map of flip states keyed by [DigitSlot].
typedef FlipStateMap = Map<DigitSlot, FlipState>;
