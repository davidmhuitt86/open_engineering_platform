import 'package:flutter/material.dart';

/// Lays out dashboard cards in a fixed number of columns above
/// [wideBreakpoint], collapsing toward a single column as the window
/// narrows — satisfies "Responsive resizing" for STUDIO-TASK-000001
/// without introducing a grid package.
class ResponsiveCardGrid extends StatelessWidget {
  const ResponsiveCardGrid({
    required this.children,
    this.columns = 3,
    this.spacing = 16,
    this.wideBreakpoint = 900,
    this.mediumBreakpoint = 600,
    super.key,
  });

  final List<Widget> children;
  final int columns;
  final double spacing;
  final double wideBreakpoint;
  final double mediumBreakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveColumns = constraints.maxWidth >= wideBreakpoint
            ? columns
            : constraints.maxWidth >= mediumBreakpoint
                ? (columns > 1 ? columns - 1 : 1)
                : 1;

        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += effectiveColumns) {
          final rowItems = children.skip(i).take(effectiveColumns).toList();
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var j = 0; j < rowItems.length; j++) ...[
                  if (j > 0) SizedBox(width: spacing),
                  Expanded(child: rowItems[j]),
                ],
                if (rowItems.length < effectiveColumns)
                  for (var k = rowItems.length; k < effectiveColumns; k++) ...[
                    SizedBox(width: spacing),
                    const Expanded(child: SizedBox.shrink()),
                  ],
              ],
            ),
          );
        }

        return Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: spacing),
              rows[i],
            ],
          ],
        );
      },
    );
  }
}
