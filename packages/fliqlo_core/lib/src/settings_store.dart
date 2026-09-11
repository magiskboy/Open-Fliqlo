import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings.dart';

/// Persists [FliqloSettings] via [SharedPreferences].
///
/// [update] applies settings in memory immediately and debounces disk writes.
/// [commit] / [flush] write through right away (toggles, slider end, dispose).
class SettingsStore extends ChangeNotifier {
  SettingsStore({
    SharedPreferences? prefs,
    this.persistDebounce = defaultPersistDebounce,
  }) : _prefsOverride = prefs;

  /// Default delay before a debounced [update] hits disk.
  static const Duration defaultPersistDebounce = Duration(milliseconds: 250);

  final SharedPreferences? _prefsOverride;
  final Duration persistDebounce;

  SharedPreferences? _prefs;
  FliqloSettings _settings = const FliqloSettings();
  bool _loaded = false;
  Timer? _persistTimer;
  Future<void>? _persistInFlight;
  bool _disposed = false;

  FliqloSettings get settings => _settings;
  bool get isLoaded => _loaded;

  static const _kUse24Hour = 'use24Hour';
  static const _kShowSeconds = 'showSeconds';
  static const _kDim = 'dim';
  static const _kScale = 'scale';
  static const _kShowFlaps = 'showFlaps';
  static const _kForceLandscape = 'forceLandscape';
  static const _kLayout = 'layout';
  static const _kEnableFlipSound = 'enableFlipSound';

  static ClockLayout _parseLayout(String? raw) {
    switch (raw) {
      case 'vertical':
        return ClockLayout.vertical;
      case 'horizontal':
      default:
        return ClockLayout.horizontal;
    }
  }

  static String _layoutKey(ClockLayout layout) {
    switch (layout) {
      case ClockLayout.vertical:
        return 'vertical';
      case ClockLayout.horizontal:
        return 'horizontal';
    }
  }

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
      layout: _parseLayout(p.getString(_kLayout)),
      enableFlipSound: p.getBool(_kEnableFlipSound) ?? false,
    );
    _loaded = true;
    notifyListeners();
  }

  /// Updates memory and notifies listeners; schedules a debounced persist.
  void update(FliqloSettings next) {
    if (_disposed) return;
    _settings = next;
    notifyListeners();
    _schedulePersist();
  }

  /// Updates memory, notifies, and persists immediately (cancels debounce).
  Future<void> commit(FliqloSettings next) async {
    if (_disposed) return;
    _settings = next;
    notifyListeners();
    await flush();
  }

  /// Writes the current in-memory settings to disk now.
  Future<void> flush() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    await _persistNow(_settings);
  }

  Future<void> patch({
    bool? use24Hour,
    bool? showSeconds,
    double? dim,
    double? scale,
    bool? showFlaps,
    bool? forceLandscape,
    ClockLayout? layout,
    bool? enableFlipSound,
  }) {
    return commit(
      _settings.copyWith(
        use24Hour: use24Hour,
        showSeconds: showSeconds,
        dim: dim,
        scale: scale,
        showFlaps: showFlaps,
        forceLandscape: forceLandscape,
        layout: layout,
        enableFlipSound: enableFlipSound,
      ),
    );
  }

  void _schedulePersist() {
    if (_disposed) return;
    _persistTimer?.cancel();
    _persistTimer = Timer(persistDebounce, () {
      _persistTimer = null;
      if (_disposed) return;
      unawaited(_persistNow(_settings));
    });
  }

  Future<void> _persistNow(FliqloSettings next) async {
    // Serialize writes so overlapping flush/commit don't interleave.
    while (_persistInFlight != null) {
      await _persistInFlight;
    }

    final future = _writePrefs(next);
    _persistInFlight = future;
    try {
      await future;
    } finally {
      if (_persistInFlight == future) {
        _persistInFlight = null;
      }
    }
  }

  Future<void> _writePrefs(FliqloSettings next) async {
    final p = _prefs ?? _prefsOverride ?? await SharedPreferences.getInstance();
    _prefs = p;
    await Future.wait([
      p.setBool(_kUse24Hour, next.use24Hour),
      p.setBool(_kShowSeconds, next.showSeconds),
      p.setDouble(_kDim, next.dim),
      p.setDouble(_kScale, next.scale),
      p.setBool(_kShowFlaps, next.showFlaps),
      p.setBool(_kForceLandscape, next.forceLandscape),
      p.setString(_kLayout, _layoutKey(next.layout)),
      p.setBool(_kEnableFlipSound, next.enableFlipSound),
    ]);
  }

  @override
  void dispose() {
    _disposed = true;
    _persistTimer?.cancel();
    _persistTimer = null;
    super.dispose();
  }
}
