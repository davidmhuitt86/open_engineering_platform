import 'oep_api_types.dart';

/// A Foundation failure translated for display in Studio.
///
/// Per Work Package 002's error handling rules, Studio never shows a raw
/// native error string, a stack trace, or an internal Foundation path to
/// the user. [message] is a curated, generic, user-facing description;
/// the native `error_message` is preserved on [technicalDetail] for
/// logging only and must not be shown in UI.
class FoundationBridgeException implements Exception {
  FoundationBridgeException({
    required this.code,
    required this.category,
    required this.message,
    required this.technicalDetail,
  });

  /// Builds a [FoundationBridgeException] from a failed `oep_result_t`,
  /// translating (code, category) into a curated [message]. This is the
  /// single place that decides what an error "means" to a Studio user.
  factory FoundationBridgeException.fromResult({
    required FoundationErrorCode code,
    required FoundationErrorCategory category,
    required String technicalDetail,
  }) {
    return FoundationBridgeException(
      code: code,
      category: category,
      message: _translate(code, category),
      technicalDetail: technicalDetail,
    );
  }

  final FoundationErrorCode code;
  final FoundationErrorCategory category;
  final String message;
  final String technicalDetail;

  static String _translate(FoundationErrorCode code, FoundationErrorCategory category) {
    switch (category) {
      case FoundationErrorCategory.validation:
        return 'That value isn\'t valid. Check what you entered and try again.';
      case FoundationErrorCategory.state:
        return 'Studio isn\'t ready to do that right now.';
      case FoundationErrorCategory.io:
        return switch (code) {
          // Generic on purpose — this fires for both "not a valid
          // repository folder" (Dashboard) and "no object with that ID"
          // (Object Explorer) failures. Call sites supply the specific
          // context via their dialog title (e.g. "Couldn't Open
          // Repository"); this message stays accurate for either.
          FoundationErrorCode.notFound => 'The requested item couldn\'t be found.',
          _ => 'The repository couldn\'t be accessed. It may be missing, moved, or in use by another program.',
        };
      case FoundationErrorCategory.internalError:
      case FoundationErrorCategory.none:
        return 'Something went wrong while talking to OEP Foundation. Please try again.';
    }
  }

  @override
  String toString() => 'FoundationBridgeException($code, $category): $message';
}
