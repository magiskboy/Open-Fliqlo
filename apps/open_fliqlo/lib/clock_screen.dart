import 'package:fliqlo_core/fliqlo_core.dart';
import 'package:fliqlo_ui/fliqlo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'platform_shell.dart';

/// Fullscreen flip clock with tap / long-press gestures.
class ClockScreen extends StatefulWidget {
  const ClockScreen({super.key});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  final SettingsStore _store = SettingsStore();
  ClockEngine? _engine;
  bool _settingsOpen = false;
  bool _ready = false;

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
    await PlatformShell.enableKeepAwake();
    await PlatformShell.enterImmersive();
    if (mounted) {
      setState(() => _ready = true);
    }
  }

  void _onSettingsChanged() {
    final s = _store.settings;
    _engine?.updateOptions(
      use24Hour: s.use24Hour,
      showSeconds: s.showSeconds,
    );
    setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_onSettingsChanged);
    _engine?.dispose();
    PlatformShell.disableKeepAwake();
    super.dispose();
  }

  Future<void> _toggleSeconds() async {
    final next = !_store.settings.showSeconds;
    await _store.patch(showSeconds: next);
  }

  Future<void> _openSettings() async {
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
        return ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            return SettingsSheet(
              settings: _store.settings,
              onChanged: (s) => _store.update(s),
            );
          },
        );
      },
    );
    _settingsOpen = false;
    await PlatformShell.enterImmersive();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
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

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleSeconds,
        onLongPress: _openSettings,
        child: Scaffold(
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
        ),
      ),
    );
  }
}
