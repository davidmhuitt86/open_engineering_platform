/// Mirrors `oep_exchange`'s `PublisherDto` wire shape (`GET /publishers`,
/// `GET /publishers/{id}`, `packages/api-contracts/src/publisher.ts`) —
/// field names are the wire format's own `camelCase` names, read
/// directly, matching `OfficialSource`'s own one-for-one mirroring of
/// EAM's wire shape.
class Publisher {
  const Publisher({
    required this.id,
    required this.namespace,
    required this.publisherType,
    required this.displayName,
    required this.legalName,
    required this.description,
    required this.website,
    required this.contactEmail,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String namespace;
  final String publisherType;
  final String displayName;
  final String legalName;
  final String description;
  final String website;
  final String contactEmail;
  final String status;
  final String createdAt;
  final String updatedAt;

  factory Publisher.fromJson(Map<String, Object?> json) => Publisher(
        id: json['id'] as String? ?? '',
        namespace: json['namespace'] as String? ?? '',
        publisherType: json['publisherType'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        legalName: json['legalName'] as String? ?? '',
        description: json['description'] as String? ?? '',
        website: json['website'] as String? ?? '',
        contactEmail: json['contactEmail'] as String? ?? '',
        status: json['status'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
        updatedAt: json['updatedAt'] as String? ?? '',
      );
}
