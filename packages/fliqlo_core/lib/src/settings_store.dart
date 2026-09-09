import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings.dart';

/// Persists [FliqloSettings] via [SharedPreferences].
class SettingsStore extends ChangeNotifier {
  SettingsStore({SharedPreferences? prefs}) : _prefsOverride = prefs;

  final SharedPreferences? _prefsOverride;
  SharedPreferences? _prefs;
  FliqloSettings _settings = const FliqloSettings();
  bool _loaded = false;

  FliqloSettings get settings => _settings;
  bool get isLoaded => _loaded;

  static const _kUse24Hour = 'use24Hour';
  static const _kShowSeconds = 'showSeconds';
  static const _kDim = 'dim';
  static const _kScale = 'scale';
  static const _kShowFlaps = 'showFlaps';
  static const _kForceLandscape = 'forceLandscape';

  Future<void> load() async {
    _prefs ??= _prefsOverride ?? await SharedPreferences.getInstance();
    final p = _prefs!;
    _settings = FliqloSettings(
      use24Hour: p.getBool(_kUse24Hour) ?? true,
      showSeconds: p.getBool(_kShowSeconds) ?? false,
      dim: (p.getDouble(_kDim) ?? 0.0).clamp(0.0, 0.8),
      scale: (p.getDouble(_kScale) ?? 1.0).clamp(0.5, 1.0),
      showFlaps: p.getBool(_kShowFlaps) ?? true,
      forceLandscape: p.getBool(_kForceLandscape) ?? false,
    );
    _loaded = true;
    notifyListeners();
  }

  Future<void> update(FliqloSettings next) async {
    _settings = next;
    notifyListeners();
    final p = _prefs ?? await SharedPreferences.getInstance();
    _prefs = p;
    await Future.wait([
      p.setBool(_kUse24Hour, next.use24Hour),
      p.setBool(_kShowSeconds, next.showSeconds),
      p.setDouble(_kDim, next.dim),
      p.setDouble(_kScale, next.scale),
      p.setBool(_kShowFlaps, next.showFlaps),
      p.setBool(_kForceLandscape, next.forceLandscape),
    ]);
  }

  Future<void> patch({
    bool? use24Hour,
    bool? showSeconds,
    double? dim,
    double? scale,
    bool? showFlaps,
    bool? forceLandscape,
  }) {
    return update(
      _settings.copyWith(
        use24Hour: use24Hour,
        showSeconds: showSeconds,
        dim: dim,
        scale: scale,
        showFlaps: showFlaps,
        forceLandscape: forceLandscape,
      ),
    );
  }
}
