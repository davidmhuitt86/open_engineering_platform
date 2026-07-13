import 'editing_session.dart';

/// An undoable Engineering Graph/Layout edit (WORK_PACKAGE_021: "All
/// editing operations shall be implemented using an undoable command
/// architecture. No editing operation may bypass the command system.").
///
/// Pure and side-effect-free, mirroring the existing immutable
/// [EngineeringGraph] copy-on-write style — `apply`/`revert` return a new
/// [EditingSession] rather than mutating anything.
abstract class EditingCommand {
  String get description;

  EditingSession apply(EditingSession session);

  EditingSession revert(EditingSession session);
}
