import 'oip_message_category.dart';

/// OIP-SPEC-001 §6 — the envelope every OEP Instrument Protocol message
/// carries. Deliberately minimal and transport-agnostic (§27: "OIP shall
/// not depend on USB/Bluetooth/Wi-Fi/... Transport adapters perform
/// framing. OIP defines messages only.") — this class is the message,
/// not its wire encoding; a [OipTransport] implementation is responsible
/// for framing/serializing it onto an actual channel.
class OipMessage {
  const OipMessage({
    required this.protocolVersion,
    required this.category,
    required this.type,
    required this.sessionId,
    required this.messageId,
    required this.timestamp,
    this.payload = const {},
    this.metadata,
    this.replyTo,
  });

  final String protocolVersion;
  final OipMessageCategory category;

  /// The specific message type within [category] (e.g. `'measurementResult'`
  /// under [OipMessageCategory.measurement]) — kept as a plain string
  /// rather than one giant enum spanning every category, so a new message
  /// type within an existing category (§26: "New message types shall not
  /// invalidate older protocol versions") never requires touching every
  /// other category's own type set.
  final String type;

  final String sessionId;
  final String messageId;
  final DateTime timestamp;
  final Map<String, Object?> payload;
  final Map<String, Object?>? metadata;

  /// PRODUCT-READINESS-007 — request/response correlation. A response
  /// message sets this to the `messageId` of the request it answers; a
  /// request never sets it (`null`). Additive and optional: an older
  /// sender that never sets `replyTo` still round-trips through
  /// [toJson]/[fromJson] unchanged (§26 "New message types/fields shall
  /// not invalidate older protocol versions"), and a receiver that
  /// doesn't yet check `replyTo` behaves exactly as before. A receiver
  /// that DOES track an outstanding request id should treat a
  /// non-matching (or, for backward compatibility, a missing) `replyTo`
  /// as informative rather than fatal — see
  /// `DigitalMultimeterPlugin.receiveMeasurement`'s own stale-response
  /// rejection for the reference implementation of this rule.
  final String? replyTo;

  Map<String, Object?> toJson() => {
        'protocolVersion': protocolVersion,
        'category': category.name,
        'type': type,
        'sessionId': sessionId,
        'messageId': messageId,
        'timestamp': timestamp.toIso8601String(),
        'payload': payload,
        if (metadata != null) 'metadata': metadata,
        if (replyTo != null) 'replyTo': replyTo,
      };

  factory OipMessage.fromJson(Map<String, Object?> json) => OipMessage(
        protocolVersion: json['protocolVersion'] as String,
        category: OipMessageCategory.values.firstWhere((c) => c.name == json['category']),
        type: json['type'] as String,
        sessionId: json['sessionId'] as String,
        messageId: json['messageId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        payload: Map<String, Object?>.from(json['payload'] as Map? ?? const {}),
        metadata: json['metadata'] == null ? null : Map<String, Object?>.from(json['metadata'] as Map),
        replyTo: json['replyTo'] as String?,
      );
}
