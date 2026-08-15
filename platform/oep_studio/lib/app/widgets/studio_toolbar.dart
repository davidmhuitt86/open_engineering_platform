import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/input/platform_input_service.dart';
import '../../core/routing/studio_destination.dart';
import '../../core/theme/studio_colors.dart';
import 'command_palette_dialog.dart';

/// The Top Toolbar (SDD-004 Workspace Layout).
///
/// Actions here are placeholders in Work Package 001 — they are wired
/// to the Command System (SDD-010) in a later work package, not to
/// Foundation. The Command Palette entry point (WP-STUDIO-024) is the
/// second exception: the field that was always reserved for it is now
/// live. "Validate" (WP-STUDIO-027) is the third: it runs
/// `diagram.revalidate` through [PlatformInputService] whenever Diagram
/// Studio is the active destination — the one existing toolbar action
/// found safe to route this way (a pure, side-effect-free state
/// recompute); Open/Import/Export and Diagram Studio's own document-bar
/// Save remain placeholders, since their real implementations carry
/// dirty-check confirmation, native file pickers, and workspace-state
/// persistence that a generic Command executor was never designed to
/// reproduce — see `docs/tasks/WP-STUDIO-027 Platform Interaction
/// Layer.md` for the full reasoning.
class StudioToolbar extends ConsumerWidget implements PreferredSizeWidget {
  const StudioToolbar({required this.selected, super.key});

  final StudioDestination selected;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canValidate = selected == StudioDestination.diagram;
    return Container(
      height: preferredSize.height,
      decoration: const BoxDecoration(
        color: StudioColors.surface,
        border: Border(bottom: BorderSide(color: StudioColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(selected.selectedIcon, size: 18, color: StudioColors.textSecondary),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              selected.label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: StudioColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const _ToolbarAction(icon: Icons.folder_open_outlined, label: 'Open'),
                  const _ToolbarAction(icon: Icons.save_outlined, label: 'Save'),
                  const _ToolbarDivider(),
                  const _ToolbarAction(icon: Icons.file_upload_outlined, label: 'Import'),
                  const _ToolbarAction(icon: Icons.file_download_outlined, label: 'Export'),
                  const _ToolbarDivider(),
                  _ToolbarAction(
                    icon: Icons.fact_check_outlined,
                    label: 'Validate',
                    onPressed: canValidate
                        ? () => PlatformInputService.defaultService.runCommand(ref, 'diagram.revalidate')
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: SizedBox(
                height: 34,
                // A read-only field that behaves like a button (WP-STUDIO-024):
                // still looks and sits exactly where the "Search (Ctrl+K)"
                // placeholder always has, but now opens the Command Palette
                // on tap. `IgnorePointer` keeps the disabled-look `TextField`
                // itself from absorbing the tap meant for the `InkWell`
                // beneath it. No keyboard shortcut is registered here —
                // "(Ctrl+K)" in the hint would overpromise one, so the hint
                // no longer mentions it.
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => showCommandPaletteDialog(context),
                    child: IgnorePointer(
                      child: TextField(
                        enabled: false,
                        style: const TextStyle(fontSize: 12, color: StudioColors.textSecondary),
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: const Icon(Icons.search, size: 16),
                          hintText: 'Commands',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.settings_outlined, size: 18, color: StudioColors.textSecondary),
        ],
      ),
    );
  }
}

class _ToolbarAction extends StatelessWidget {
  const _ToolbarAction({required this.icon, required this.label, this.onPressed});

  final IconData icon;
  final String label;

  /// Null keeps this action exactly as inert as every `StudioToolbar`
  /// action has been since Work Package 001 — only "Validate"
  /// (WP-STUDIO-027) currently ever passes a real callback.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: IconButton(
          onPressed: onPressed,
          disabledColor: StudioColors.textSecondary,
          icon: Icon(icon, size: 18),
          splashRadius: 18,
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: StudioColors.border,
    );
  }
}
