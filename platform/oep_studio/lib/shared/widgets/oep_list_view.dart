import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';

/// A selectable list body -- empty state, otherwise a divided list of
/// [itemBuilder]-rendered rows (ODS-C009/ODS-C010 gap note below).
///
/// Phase 4 (Shared Tree/Table Primitives): survey of every current
/// list/tree implementation found no genuine common *row* shape to
/// extract (Acquisition Job rows carry conditional trailing actions,
/// Reference Vault/Source rows are plain two-line `ListTile`s, Exchange
/// rows carry a version badge, Diagram Annotation/Recent-Commands rows
/// differ again) -- forcing them into one configurable row widget would
/// be exactly the "large abstraction framework" this phase's own
/// instructions warn against. What genuinely repeats, identically,
/// across seven consumers (`AcquisitionJobsPanel`,
/// `AcquisitionVaultPanel`, `AcquisitionSourcesPanel`,
/// `ExchangeMyLibraryPanel`, `ExchangeSearchPanel`,
/// `DiagramAnnotationPanel`, `DiagramRecentCommandsPanel`) is the
/// **scaffolding** around those rows: an empty-state `Center(Text(...))`
/// when there's nothing to show, else a `ListView.separated` with a
/// hairline `Divider`. This widget is exactly that scaffolding and
/// nothing else -- callers keep full control of row content.
///
/// **Design-system gap**: ODS-C009 (Table/Data Grid) and ODS-C010 (Tree
/// View) are both "Architecture Draft" status -- bulleted feature
/// wishlists (multi-selection modes, drag-and-drop, inline rename,
/// virtualization) with no concrete API, type signatures, or default
/// behavior specified anywhere. There is nothing implementable to
/// extract a `OEPTreeView`/`OEPDataGrid` primitive *against* yet; doing
/// so now would mean inventing an API the design system doesn't
/// actually define. This widget deliberately stays scoped to the one
/// pattern that both genuinely repeats today and needs no such spec:
/// list scaffolding. See `docs/ui_refactor/PHASE_4_NOTES.md`.
class OEPListView<T> extends StatelessWidget {
  const OEPListView({
    required this.items,
    required this.itemBuilder,
    required this.emptyMessage,
    super.key,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(emptyMessage, style: const TextStyle(color: StudioColors.textSecondary)),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => itemBuilder(context, items[index]),
    );
  }
}
