import 'package:flutter/material.dart';

/// Array Placement dialog (WORK_PACKAGE_023, ENGINE-TASK-000102/000106) —
/// prompts for a grid count/spacing, then hands the values back so the
/// caller can execute `ArrayPlaceCommand`. Promoted into the Engine
/// package (WORK_PACKAGE_024) alongside the other generic, host-agnostic
/// drafting dialogs — plain Material, no Demonstration-Host-specific
/// dependencies, so both the Demonstration Host and Diagram Studio use
/// this exact class rather than each maintaining their own copy.
Future<({int countX, int countY, double spacingX, double spacingY})?> showArrayPlacementDialog(
  BuildContext context,
) {
  var countX = 2;
  var countY = 1;
  var spacingX = 150.0;
  var spacingY = 150.0;

  return showDialog<({int countX, int countY, double spacingX, double spacingY})>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Array Placement'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: 'Columns'),
                        keyboardType: TextInputType.number,
                        controller: TextEditingController(text: countX.toString()),
                        onChanged: (v) => countX = int.tryParse(v) ?? countX,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: 'Rows'),
                        keyboardType: TextInputType.number,
                        controller: TextEditingController(text: countY.toString()),
                        onChanged: (v) => countY = int.tryParse(v) ?? countY,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: 'Column spacing'),
                        keyboardType: TextInputType.number,
                        controller: TextEditingController(text: spacingX.toString()),
                        onChanged: (v) => spacingX = double.tryParse(v) ?? spacingX,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: 'Row spacing'),
                        keyboardType: TextInputType.number,
                        controller: TextEditingController(text: spacingY.toString()),
                        onChanged: (v) => spacingY = double.tryParse(v) ?? spacingY,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop((
                  countX: countX,
                  countY: countY,
                  spacingX: spacingX,
                  spacingY: spacingY,
                )),
                child: const Text('Place'),
              ),
            ],
          );
        },
      );
    },
  );
}
