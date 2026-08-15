/// Engineering Chain of Custody, as collected by the Acquisition Wizard's
/// Step 3 -- "This ensures every Engineering Object can always be traced
/// back to its original source."
///
/// **Disclosed limitation**: `oep_acquisition` (the EAM backend) has no
/// schema field for any of this today -- `AcquisitionJob` carries only
/// `name`/`source_id`/`priority`/`requested_by`, and `OfficialSource` has
/// no publisher/license/language fields either. Per this work's own
/// constraint ("Do NOT modify the backend architecture"), this record is
/// therefore persisted locally in Studio only (`ChainOfCustodyStorage`),
/// keyed by the Vault Entry id it ends up attached to -- real, working,
/// and honestly local, not silently dropped, but not yet the permanent
/// server-side provenance record the architecture ultimately calls for.
/// A future backend work package adding real columns for this is the
/// natural point to migrate this from local storage to the API.
class ChainOfCustodyRecord {
  const ChainOfCustodyRecord({
    required this.knowledgeType,
    required this.originalUrl,
    required this.publisher,
    required this.publicationDate,
    required this.revision,
    required this.license,
    required this.language,
    required this.acquisitionMethod,
    required this.engineer,
    required this.scopeDescription,
    required this.recordedAt,
  });

  final String knowledgeType;
  final String originalUrl;
  final String publisher;
  final String publicationDate;
  final String revision;
  final String license;
  final String language;
  final String acquisitionMethod;
  final String engineer;
  final String scopeDescription;
  final String recordedAt;

  Map<String, Object?> toJson() => {
        'knowledgeType': knowledgeType,
        'originalUrl': originalUrl,
        'publisher': publisher,
        'publicationDate': publicationDate,
        'revision': revision,
        'license': license,
        'language': language,
        'acquisitionMethod': acquisitionMethod,
        'engineer': engineer,
        'scopeDescription': scopeDescription,
        'recordedAt': recordedAt,
      };

  factory ChainOfCustodyRecord.fromJson(Map<String, Object?> json) => ChainOfCustodyRecord(
        knowledgeType: json['knowledgeType'] as String? ?? '',
        originalUrl: json['originalUrl'] as String? ?? '',
        publisher: json['publisher'] as String? ?? '',
        publicationDate: json['publicationDate'] as String? ?? '',
        revision: json['revision'] as String? ?? '',
        license: json['license'] as String? ?? '',
        language: json['language'] as String? ?? '',
        acquisitionMethod: json['acquisitionMethod'] as String? ?? '',
        engineer: json['engineer'] as String? ?? '',
        scopeDescription: json['scopeDescription'] as String? ?? '',
        recordedAt: json['recordedAt'] as String? ?? '',
      );
}
