import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';

/// A placeholder Primary Workspace (SDD-004) for a navigation destination
/// that has not been implemented yet.
///
/// No engineering functionality or Foundation integration lives here —
/// this is presentation scaffolding only, per Work Package 001.
class PlaceholderWorkspace extends StatelessWidget {
  const PlaceholderWorkspace({
    required this.title,
    required this.icon,
    required this.description,
    super.key,
  });

  final String title;
  final IconData icon;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: StudioColors.textDisabled),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: StudioColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(color: StudioColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
