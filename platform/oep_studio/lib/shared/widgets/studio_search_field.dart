import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';

/// AP-OEP-STUDIO-DESIGN-UNIFY-001 — factors out the
/// `SizedBox(height: 34, child: TextField(...))` filter-box pattern
/// Repository and Objects previously each hand-rolled, char-for-char
/// identically, independently.
class StudioSearchField extends StatelessWidget {
  const StudioSearchField({
    this.controller,
    required this.onChanged,
    required this.hintText,
    super.key,
  });

  final TextEditingController? controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search, size: 16),
          hintText: hintText,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }
}
