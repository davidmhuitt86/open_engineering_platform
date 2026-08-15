import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';

/// Shared row/section widgets for the eleven Settings pages (Work
/// Package 017 STUDIO-TASK-000052), so each page composes rows instead
/// of re-implementing label/control layout eleven times.
class SettingsSection extends StatelessWidget {
  const SettingsSection({required this.title, required this.children, this.description, super.key});

  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: StudioColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(description!, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _RowShell extends StatelessWidget {
  const _RowShell({required this.label, required this.control, this.helper, this.disabled = false});

  final String label;
  final Widget control;
  final String? helper;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: disabled ? StudioColors.textDisabled : StudioColors.textPrimary,
                    fontSize: 12.5,
                  ),
                ),
                if (helper != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(helper!, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
                  ),
              ],
            ),
          ),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: control)),
        ],
      ),
    );
  }
}

class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      label: label,
      helper: helper,
      control: Switch(value: value, onChanged: onChanged, activeThumbColor: StudioColors.selection),
    );
  }
}

class SettingsDropdownRow<T> extends StatelessWidget {
  const SettingsDropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.helper,
    super.key,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      label: label,
      helper: helper,
      control: SizedBox(
        width: 180,
        height: 34,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            dropdownColor: StudioColors.surfaceRaised,
            style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class SettingsSliderRow extends StatelessWidget {
  const SettingsSliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.helper,
    this.divisions,
    super.key,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      label: label,
      helper: helper,
      control: SizedBox(
        width: 180,
        child: Row(
          children: [
            Expanded(
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                activeColor: StudioColors.selection,
                onChanged: onChanged,
              ),
            ),
            SizedBox(width: 40, child: Text(value.toStringAsFixed(2), style: const TextStyle(fontSize: 11, color: StudioColors.textSecondary))),
          ],
        ),
      ),
    );
  }
}

class SettingsTextRow extends StatefulWidget {
  const SettingsTextRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
    this.hintText,
    super.key,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? helper;
  final String? hintText;

  @override
  State<SettingsTextRow> createState() => _SettingsTextRowState();
}

class _SettingsTextRowState extends State<SettingsTextRow> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant SettingsTextRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text && widget.value != oldWidget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      label: widget.label,
      helper: widget.helper,
      control: SizedBox(
        width: 200,
        height: 34,
        child: TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hintText,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ),
    );
  }
}

class SettingsInfoRow extends StatelessWidget {
  const SettingsInfoRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      label: label,
      control: Text(
        value,
        textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 12, color: StudioColors.textSecondary),
      ),
    );
  }
}

/// A control not yet wired to real behavior (Work Package 017:
/// "Pages may initially contain placeholder controls where
/// functionality is not yet implemented.") — disabled, with a
/// "Not yet implemented" helper, so it reads as an honest placeholder
/// rather than a broken control.
class SettingsPlaceholderRow extends StatelessWidget {
  const SettingsPlaceholderRow({required this.label, this.helper = 'Not yet implemented.', super.key});

  final String label;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      label: label,
      helper: helper,
      disabled: true,
      control: const Icon(Icons.lock_outline, size: 16, color: StudioColors.textDisabled),
    );
  }
}
