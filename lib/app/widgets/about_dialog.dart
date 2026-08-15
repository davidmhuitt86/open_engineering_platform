import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';

/// Shows the "About OEP Studio" dialog (Help menu). Version string
/// matches the one already shown in `StudioStatusBar` -- one literal,
/// not two that could drift.
Future<void> showAboutOepStudioDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: StudioColors.surfaceRaised,
      title: const Text('OEP Studio'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Version 0.1.0-alpha', style: TextStyle(color: StudioColors.textSecondary)),
          SizedBox(height: 8),
          Text(
            'The Open Engineering Platform Studio -- a workbench for engineering repository, '
            'acquisition, knowledge, and diagram authoring.',
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    ),
  );
}
