/// Mirrors `oep_acquisition`'s `registry::OfficialSource` JSON shape
/// (`GET /sources`, `GET /sources/{id}`, `POST /sources`) — field names
/// are the wire format's own `snake_case` names, read directly rather
/// than remapped, matching how `foundation_bridge.dart`'s types mirror
/// the C API's own field names one-for-one.
class OfficialSource {
  const OfficialSource({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.category,
    required this.country,
    required this.trustLevel,
    required this.status,
    required this.authenticationType,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String baseUrl;
  final String category;
  final String country;
  final int trustLevel;
  final String status;
  final String authenticationType;
  final String createdAt;
  final String updatedAt;

  factory OfficialSource.fromJson(Map<String, Object?> json) => OfficialSource(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        baseUrl: json['base_url'] as String? ?? '',
        category: json['category'] as String? ?? '',
        country: json['country'] as String? ?? '',
        trustLevel: json['trust_level'] as int? ?? 0,
        status: json['status'] as String? ?? '',
        authenticationType: json['authentication_type'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
        updatedAt: json['updated_at'] as String? ?? '',
      );
}
