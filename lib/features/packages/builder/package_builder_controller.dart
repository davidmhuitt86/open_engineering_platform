import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/engineering_object_summary.dart';

/// Orchestrates the Package Builder wizard's local, in-memory state
/// only -- Object Selection and Metadata/Version are the only steps
/// with anywhere real to hold state, since `foundation_bridge.dart` has
/// no `createPackage`/`buildPackage`/`signPackage`/`publishPackage`
/// entry point (confirmed by inspection before this wizard was built --
/// see `package_builder_page.dart`'s own doc comment). This controller
/// deliberately does NOT attempt to orchestrate a real multi-step
/// backend chain the way `AcquisitionWizardController` does for
/// Acquisition, because Package Builder is a UI shell around mostly
/// not-yet-implemented backend capability -- reflecting that honestly,
/// not fabricating a chain that doesn't exist.
class PackageBuilderController extends ChangeNotifier {
  int _stepIndex = 0;
  int get stepIndex => _stepIndex;

  final Set<String> selectedObjectIds = {};

  String packageName = '';
  String packageVersion = '';
  String packageAuthor = '';
  String packageDescription = '';

  void goToStep(int index) {
    _stepIndex = index;
    notifyListeners();
  }

  void next() {
    if (_stepIndex < stepCount - 1) _stepIndex++;
    notifyListeners();
  }

  void back() {
    if (_stepIndex > 0) _stepIndex--;
    notifyListeners();
  }

  void toggleObject(EngineeringObjectSummary object) {
    if (!selectedObjectIds.add(object.objectId)) selectedObjectIds.remove(object.objectId);
    notifyListeners();
  }

  void setMetadata({String? name, String? version, String? author, String? description}) {
    if (name != null) packageName = name;
    if (version != null) packageVersion = version;
    if (author != null) packageAuthor = author;
    if (description != null) packageDescription = description;
    notifyListeners();
  }

  static const stepCount = 5;
}

final packageBuilderControllerProvider =
    ChangeNotifierProvider.autoDispose<PackageBuilderController>((ref) => PackageBuilderController());
