import 'package:fliqlo_core/fliqlo_core.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Dark bottom sheet for clock preferences.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({
    super.key,
    required this.settings,
    required this.onChanged,
    this.onCommit,
  });

  final FliqloSettings settings;

  /// Preview / in-memory updates (e.g. every slider tick).
  final ValueChanged<FliqloSettings> onChanged;

  /// Immediate persist path for toggles and slider [onChangeEnd].
  ///
  /// Falls back to [onChanged] when null.
  final ValueChanged<FliqloSettings>? onCommit;

  static Future<void> show(
    BuildContext context, {
    required FliqloSettings settings,
    required ValueChanged<FliqloSettings> onChanged,
    ValueChanged<FliqloSettings>? onCommit,
  }) {
    return showModalBottomSheet<void>(
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
          child: SettingsSheet(
            settings: settings,
            onChanged: onChanged,
            onCommit: onCommit,
          ),
        );
      },
    );
  }

  void _commit(FliqloSettings next) => (onCommit ?? onChanged)(next);

  @override
  Widget build(BuildContext context) {
    // Bound height so the sheet can scroll when content exceeds the
    // viewport (common in phone landscape).
    final maxHeight = MediaQuery.sizeOf(context).height;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF444444),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Settings',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: FliqloTheme.sheetForeground,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('24-hour clock'),
                value: settings.use24Hour,
                onChanged: (v) => _commit(settings.copyWith(use24Hour: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show seconds'),
                value: settings.showSeconds,
                onChanged: (v) => _commit(settings.copyWith(showSeconds: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show flaps'),
                value: settings.showFlaps,
                onChanged: (v) => _commit(settings.copyWith(showFlaps: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Force landscape'),
                value: settings.forceLandscape,
                onChanged: (v) =>
                    _commit(settings.copyWith(forceLandscape: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vertical layout'),
                value: settings.layout == ClockLayout.vertical,
                onChanged: (v) => _commit(
                  settings.copyWith(
                    layout: v ? ClockLayout.vertical : ClockLayout.horizontal,
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Flip sound'),
                value: settings.enableFlipSound,
                onChanged: (v) =>
                    _commit(settings.copyWith(enableFlipSound: v)),
              ),
              const SizedBox(height: 8),
              Text(
                'Dim (${(settings.dim * 100).round()}%)',
                style: const TextStyle(color: FliqloTheme.sheetForeground),
              ),
              Slider(
                value: settings.dim,
                min: 0,
                max: 0.8,
                onChanged: (v) => onChanged(settings.copyWith(dim: v)),
                onChangeEnd: (v) => _commit(settings.copyWith(dim: v)),
              ),
              Text(
                'Scale (${(settings.scale * 100).round()}%)',
                style: const TextStyle(color: FliqloTheme.sheetForeground),
              ),
              Slider(
                value: settings.scale,
                min: 0.5,
                max: 1.0,
                onChanged: (v) => onChanged(settings.copyWith(scale: v)),
                onChangeEnd: (v) => _commit(settings.copyWith(scale: v)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
