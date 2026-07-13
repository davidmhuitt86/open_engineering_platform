import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// Save/Load/Delete/Reset named layouts (WORK_PACKAGE_022,
/// ENGINE-TASK-000089/000097).
Future<void> showNamedLayoutsDialog(
  BuildContext context, {
  required LayoutProvider layoutProvider,
  required String graphId,
  required DiagramLayoutState Function() currentLayout,
  required void Function(DiagramLayoutState layout) onLoad,
  required VoidCallback onReset,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final names = layoutProvider.listNamedLayouts(graphId);
          return AlertDialog(
            title: const Text('Named Layouts'),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (names.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No saved layouts yet.'),
                    )
                  else
                    ...names.map((name) => ListTile(
                          dense: true,
                          title: Text(name),
                          onTap: () {
                            final layout = layoutProvider.loadNamedLayout(graphId, name);
                            if (layout != null) onLoad(layout);
                            Navigator.of(context).pop();
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await layoutProvider.deleteNamedLayout(graphId, name);
                              setState(() {});
                            },
                          ),
                        )),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('Save current as...'),
                          onPressed: () async {
                            final name = await _promptForName(context);
                            if (name == null || name.trim().isEmpty) return;
                            await layoutProvider.saveNamedLayout(graphId, name.trim(), currentLayout());
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  onReset();
                  Navigator.of(context).pop();
                },
                child: const Text('Reset Layout'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<String?> _promptForName(BuildContext context) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Layout name'),
      content: TextField(controller: controller, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
