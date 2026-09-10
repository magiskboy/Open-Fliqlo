import 'dart:async';

import 'package:fliqlo_core/fliqlo_core.dart';
import 'package:fliqlo_ui/fliqlo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'launch_mode.dart';
import 'platform_shell.dart';

/// Fullscreen flip clock with tap / long-press gestures (interactive modes).
class ClockScreen extends StatefulWidget {
  const ClockScreen({super.key, this.mode = LaunchMode.normal});

  final LaunchMode mode;

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  final SettingsStore _store = SettingsStore();
  ClockEngine? _engine;
  bool _settingsOpen = false;
  bool _ready = false;
  bool _configureOpened = false;
  bool _forceLandscapeApplied = false;

  LaunchMode get _mode => widget.mode;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _store.load();
    final settings = _store.settings;
    _engine = ClockEngine(
      use24Hour: settings.use24Hour,
      showSeconds: settings.showSeconds,
    )..start();
    _store.addListener(_onSettingsChanged);
    await _applyOrientation(settings.forceLandscape);
    await PlatformShell.enableKeepAwake();
    await PlatformShell.enterImmersive();
    if (mounted) {
      setState(() => _ready = true);
    }
    if (_mode.openSettingsOnLaunch && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_configureOpened && mounted) {
          _configureOpened = true;
          _openSettings();
        }
      });
    }
  }

  Future<void> _applyOrientation(bool forceLandscape) async {
    _forceLandscapeApplied = forceLandscape;
    await PlatformShell.applyPreferredOrientations(
      forceLandscape: forceLandscape,
    );
  }

  void _onSettingsChanged() {
    final s = _store.settings;
    _engine?.updateOptions(
      use24Hour: s.use24Hour,
      showSeconds: s.showSeconds,
    );
    if (s.forceLandscape != _forceLandscapeApplied) {
      _applyOrientation(s.forceLandscape);
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onSettingsChanged);
    final store = _store;
    unawaited(store.flush().whenComplete(store.dispose));
    _engine?.dispose();
    PlatformShell.disableKeepAwake();
    super.dispose();
  }

  Future<void> _toggleSeconds() async {
    if (!_mode.allowInteractiveGestures) return;
    final next = !_store.settings.showSeconds;
    await _store.patch(showSeconds: next);
  }

  Future<void> _openSettings() async {
    if (_mode == LaunchMode.screensaver ||
        _mode == LaunchMode.lockscreen ||
        _mode == LaunchMode.preview) {
      return;
    }
    if (_settingsOpen) return;
    _settingsOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: FliqloTheme.sheetBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ListenableBuilder(
            listenable: _store,
            builder: (context, _) {
              return SettingsSheet(
                settings: _store.settings,
                onChanged: _store.update,
                onCommit: (s) => unawaited(_store.commit(s)),
              );
            },
          ),
        );
      },
    );
    _settingsOpen = false;
    await _store.flush();
    await PlatformShell.enterImmersive();
    // Configure mode: closing settings exits (Windows /c UX).
    if (_mode == LaunchMode.configure && mounted) {
      PlatformShell.requestExit();
    }
  }

  void _exitIfScreensaver() {
    if (_mode.exitOnInput) {
      PlatformShell.requestExit();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (_mode.exitOnInput) {
      _exitIfScreensaver();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_settingsOpen) {
        Navigator.of(context).maybePop();
        return KeyEventResult.handled;
      }
      PlatformShell.exitFullscreen();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.f11) {
      PlatformShell.toggleFullscreen();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _engine == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
          ),
        ),
      );
    }

    final clock = Scaffold(
      backgroundColor: FliqloTheme.background,
      body: ListenableBuilder(
        listenable: Listenable.merge([_engine!, _store]),
        builder: (context, _) {
          final snapshot = _engine!.snapshot;
          if (snapshot == null) {
            return const SizedBox.expand();
          }
          return ClockFace(
            snapshot: snapshot,
            settings: _store.settings,
          );
        },
      ),
    );

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _mode.exitOnInput
            ? _exitIfScreensaver
            : (_mode.allowInteractiveGestures ? _toggleSeconds : null),
        onLongPress: _mode.allowInteractiveGestures ? _openSettings : null,
        onPanStart: _mode.exitOnInput ? (_) => _exitIfScreensaver() : null,
        child: clock,
      ),
    );
  }
}
