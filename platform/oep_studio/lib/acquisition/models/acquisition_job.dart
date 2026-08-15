/// Mirrors `oep_acquisition`'s `acquisition::AcquisitionJob` JSON shape
/// (`GET /jobs`, `GET /jobs/{id}`, `POST /jobs`).
class AcquisitionJob {
  const AcquisitionJob({
    required this.id,
    required this.sourceId,
    required this.name,
    required this.priority,
    required this.status,
    required this.requestedBy,
    this.startedAt,
    this.completedAt,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String sourceId;
  final String name;
  final int priority;
  final String status;
  final String requestedBy;
  final String? startedAt;
  final String? completedAt;
  final String? errorMessage;
  final String createdAt;
  final String updatedAt;

  factory AcquisitionJob.fromJson(Map<String, Object?> json) => AcquisitionJob(
        id: json['id'] as String? ?? '',
        sourceId: json['source_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        priority: json['priority'] as int? ?? 0,
        status: json['status'] as String? ?? '',
        requestedBy: json['requested_by'] as String? ?? '',
        startedAt: json['started_at'] as String?,
        completedAt: json['completed_at'] as String?,
        errorMessage: json['error_message'] as String?,
        createdAt: json['created_at'] as String? ?? '',
        updatedAt: json['updated_at'] as String? ?? '',
      );
}
