import '../../clipboard/clipboard_extraction.dart';
import '../../selection/graph_selection.dart';
import '../../views/diagram/diagram_geometry.dart';
import '../editing_command.dart';
import '../editing_session.dart';
import 'paste_command.dart';

/// Duplicates the current selection in place (ENGINE-TASK-000083:
/// "Duplicate", "Clone") — extracts a [ClipboardEntry] from the live
/// session (no clipboard round-trip) and delegates to the same
/// id-remapping logic [PasteCommand] uses.
class DuplicateSelectionCommand implements EditingCommand {
  final GraphSelection selection;
  final Point2D offset;

  late final PasteCommand _paste;

  DuplicateSelectionCommand(this.selection, {this.offset = const Point2D(24, 24)});

  List<String> get duplicatedNodeIds => _paste.pastedNodeIds;

  @override
  String get description => 'Duplicate';

  @override
  EditingSession apply(EditingSession session) {
    final entry = ClipboardExtraction.extract(session, selection);
    _paste = PasteCommand(entry, offset: offset);
    return _paste.apply(session);
  }

  @override
  EditingSession revert(EditingSession session) => _paste.revert(session);
}
