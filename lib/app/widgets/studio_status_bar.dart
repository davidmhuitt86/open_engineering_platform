import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/operations/operation_manager.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/services/foundation_runtime_state.dart';
import '../../core/theme/studio_colors.dart';
import '../../shared/widgets/output_panel.dart';

/// The bottom Status Bar (SDD-003/SDD-004, overridden by Work Package 002:
/// displays Runtime, Repository, Theme, and Studio Version — Foundation
/// Version moved to the Dashboard). Work Package 003 adds Selected Object.
///
/// WP-STUDIO-030 Engineering Operations Framework adds a conditional
/// "N Operations Running" segment, sourced from [OperationManager] —
/// this is why this widget is a [ConsumerStatefulWidget] rather than
/// [ConsumerWidget] as before: it needs to subscribe to
/// [OperationManager.changes] (not a Riverpod provider, since
/// `OperationManager` is a plain Platform singleton, not Studio state)
/// and call [State.setState] when it fires.
class StudioStatusBar extends ConsumerStatefulWidget {
  const StudioStatusBar({OperationManager? operationManager, super.key}) : _operationManager = operationManager;

  /// Defaults to [OperationManager.instance]; only ever overridden in
  /// tests.
  final OperationManager? _operationManager;

  @override
  ConsumerState<StudioStatusBar> createState() => _StudioStatusBarState();
}

class _StudioStatusBarState extends ConsumerState<StudioStatusBar> {
  StreamSubscription<void>? _operationsSubscription;

  OperationManager get _operationManager => widget._operationManager ?? OperationManager.instance;

  @override
  void initState() {
    super.initState();
    _operationsSubscription = _operationManager.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _operationsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final connected = foundation.phase == FoundationConnectionPhase.connected;
    final repositoryLabel = foundation.isRepositoryOpen
        ? 'Repository: ${foundation.repositoryStatus?.repositoryName ?? "Open"}'
        : 'Repository: None Open';
    final selectedObjectLabel = 'Selected Object: ${foundation.selectedObject?.name ?? "None"}';
    final activeOperations = _operationManager.activeOperations;

    return Container(
      height: 28,
      decoration: const BoxDecoration(
        color: StudioColors.surface,
        border: Border(top: BorderSide(color: StudioColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _StatusDot(color: connected ? StudioColors.success : StudioColors.warning),
          const SizedBox(width: 6),
          Flexible(
            // Weighted higher than the right-hand group and the Spacer:
            // this side's content (Ready/Repository/Runtime/Selected
            // Object) is both longer and more important than the
            // Theme/Version group, so it should keep more of the
            // available width before either side starts clipping at
            // the window's minimum size (1000px, win32_window.cpp).
            flex: 3,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const _StatusText('Ready'),
                  const _StatusSeparator(),
                  _StatusText(repositoryLabel),
                  const _StatusSeparator(),
                  _StatusText(
                    connected ? 'Runtime: Connected' : 'Runtime: Disconnected',
                    color: connected ? StudioColors.success : StudioColors.warning,
                  ),
                  const _StatusSeparator(),
                  _StatusText(selectedObjectLabel),
                  if (activeOperations.isNotEmpty) ...[
                    const _StatusSeparator(),
                    _StatusText(
                      '${activeOperations.length} Operation${activeOperations.length == 1 ? '' : 's'} Running',
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Spacer(),
          // The Output Panel's only toggle -- it deliberately has no
          // permanently-docked header of its own (see `OutputPanel`).
          _OutputPanelToggle(
            visible: ref.watch(outputPanelVisibleProvider),
            onToggle: () => ref.read(outputPanelVisibleProvider.notifier).state =
                !ref.read(outputPanelVisibleProvider),
          ),
          const _StatusSeparator(),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true, // if clipped, keep the trailing (version) text visible rather than "Theme:"
              child: const Row(
                children: [
                  _StatusText('Theme: Dark'),
                  _StatusSeparator(),
                  _StatusText('OEP Studio 0.1.0-alpha'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutputPanelToggle extends StatelessWidget {
  const _OutputPanelToggle({required this.visible, required this.onToggle});

  final bool visible;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: visible ? 'Hide Output Panel' : 'Show Output Panel',
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.terminal_outlined,
                  size: 13, color: visible ? StudioColors.selection : StudioColors.textSecondary),
              const SizedBox(width: 5),
              Text('Output',
                  style: TextStyle(
                      fontSize: 11, color: visible ? StudioColors.selection : StudioColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: color ?? StudioColors.textSecondary, fontSize: 11),
    );
  }
}

class _StatusSeparator extends StatelessWidget {
  const _StatusSeparator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: StudioColors.border,
    );
  }
}
