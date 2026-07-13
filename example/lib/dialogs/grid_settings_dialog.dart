import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// Grid/Snap settings dialog (WORK_PACKAGE_022, ENGINE-TASK-000097).
Future<void> showGridSettingsDialog(BuildContext context, ViewStateService viewState) async {
  var settings = viewState.current.grid;
  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Grid & Snap Settings'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Spacing'),
                    Expanded(
                      child: Slider(
                        min: 5,
                        max: 100,
                        value: settings.spacing.clamp(5, 100),
                        label: settings.spacing.round().toString(),
                        onChanged: (value) {
                          setState(() => settings = settings.copyWith(spacing: value));
                        },
                      ),
                    ),
                    Text(settings.spacing.round().toString()),
                  ],
                ),
                Row(
                  children: [
                    const Text('Major every'),
                    Expanded(
                      child: Slider(
                        min: 2,
                        max: 10,
                        divisions: 8,
                        value: settings.majorEvery.clamp(2, 10).toDouble(),
                        label: settings.majorEvery.toString(),
                        onChanged: (value) {
                          setState(() => settings = settings.copyWith(majorEvery: value.round()));
                        },
                      ),
                    ),
                    Text(settings.majorEvery.toString()),
                  ],
                ),
                SwitchListTile(
                  title: const Text('Show grid'),
                  value: settings.visible,
                  onChanged: (value) => setState(() => settings = settings.copyWith(visible: value)),
                ),
                SwitchListTile(
                  title: const Text('Snap to grid'),
                  value: settings.snapEnabled,
                  onChanged: (value) =>
                      setState(() => settings = settings.copyWith(snapEnabled: value)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  viewState.setGridSettings(settings);
                  Navigator.of(context).pop();
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      );
    },
  );
}
