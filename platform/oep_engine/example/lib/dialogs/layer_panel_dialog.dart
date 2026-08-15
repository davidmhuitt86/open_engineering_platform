import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// Layer Panel (WORK_PACKAGE_023, ENGINE-TASK-000101/000106): create,
/// rename, delete, and toggle visibility/lock/print-visibility for
/// Diagram Layout layers, plus assign the current selection to a layer.
Future<void> showLayerPanelDialog(
  BuildContext context, {
  required EngineeringEngine engine,
  required EditingSession Function() session,
  required GraphSelection Function() selection,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final layers = session().layout.layers.values.toList()
            ..sort((a, b) => a.order.compareTo(b.order));

          return AlertDialog(
            title: const Text('Layers'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (layers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No layers yet.'),
                    )
                  else
                    ...layers.map((layer) => ListTile(
                          dense: true,
                          title: Text(layer.name),
                          leading: IconButton(
                            icon: Icon(layer.visible ? Icons.visibility : Icons.visibility_off),
                            tooltip: 'Toggle visibility',
                            onPressed: () {
                              engine.editing.execute(
                                UpdateLayerCommand(layer.id, visible: !layer.visible),
                              );
                              setState(() {});
                            },
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(layer.locked ? Icons.lock : Icons.lock_open),
                                tooltip: 'Toggle lock',
                                onPressed: () {
                                  engine.editing.execute(
                                    UpdateLayerCommand(layer.id, locked: !layer.locked),
                                  );
                                  setState(() {});
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  layer.printVisible ? Icons.print : Icons.print_disabled,
                                ),
                                tooltip: 'Toggle print visibility',
                                onPressed: () {
                                  engine.editing.execute(
                                    UpdateLayerCommand(layer.id, printVisible: !layer.printVisible),
                                  );
                                  setState(() {});
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.label_important_outline),
                                tooltip: 'Assign selection to this layer',
                                onPressed: selection().nodeIds.isEmpty &&
                                        selection().annotationIds.isEmpty
                                    ? null
                                    : () {
                                        for (final id in selection().nodeIds) {
                                          engine.editing
                                              .execute(AssignLayerCommand(id, layer.id));
                                        }
                                        for (final id in selection().annotationIds) {
                                          engine.editing
                                              .execute(AssignLayerCommand(id, layer.id));
                                        }
                                        setState(() {});
                                      },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Delete layer',
                                onPressed: () {
                                  engine.editing.execute(DeleteLayerCommand(layer.id));
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        )),
                  const Divider(),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Create layer'),
                    onPressed: () async {
                      final name = await _promptForName(context);
                      if (name == null || name.trim().isEmpty) return;
                      engine.editing.execute(CreateLayerCommand(DiagramLayer(
                        id: engine.graph.generateId('layer'),
                        name: name.trim(),
                        order: layers.length,
                      )));
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            actions: [
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
      title: const Text('Layer name'),
      content: TextField(controller: controller, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Create'),
        ),
      ],
    ),
  );
}
