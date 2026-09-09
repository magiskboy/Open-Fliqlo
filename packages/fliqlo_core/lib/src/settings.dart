/// User-configurable display options for Open Fliqlo.
class FliqloSettings {
  const FliqloSettings({
    this.use24Hour = true,
    this.showSeconds = false,
    this.dim = 0.0,
    this.scale = 1.0,
    this.showFlaps = true,
  });

  final bool use24Hour;
  final bool showSeconds;

  /// Black overlay opacity from 0.0 to 0.8.
  final double dim;

  /// Clock face scale from 0.5 to 1.0.
  final double scale;

  /// Whether to draw the horizontal flap hinge.
  final bool showFlaps;

  FliqloSettings copyWith({
    bool? use24Hour,
    bool? showSeconds,
    double? dim,
    double? scale,
    bool? showFlaps,
  }) {
    return FliqloSettings(
      use24Hour: use24Hour ?? this.use24Hour,
      showSeconds: showSeconds ?? this.showSeconds,
      dim: dim ?? this.dim,
      scale: scale ?? this.scale,
      showFlaps: showFlaps ?? this.showFlaps,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FliqloSettings &&
        other.use24Hour == use24Hour &&
        other.showSeconds == showSeconds &&
        other.dim == dim &&
        other.scale == scale &&
        other.showFlaps == showFlaps;
  }

  @override
  int get hashCode => Object.hash(
        use24Hour,
        showSeconds,
        dim,
        scale,
        showFlaps,
      );
}
