/**
 * Repository Installation Integration wire contracts (TASK-EXC-0008,
 * docs/tasks/WP-EXC-008.md §4/§6/§8).
 */
export type InstallationStatus = 'pending' | 'completed' | 'failed';

export interface InstallationDto {
  id: string;
  packageId: string;
  version: string;
  status: InstallationStatus;
  repositoryPackageId: string | null;
  errorMessage: string | null;
  requestedAt: string;
  completedAt: string | null;
}

/** `POST /packages/{id}/install` body — `version` is optional; the Package's current version is installed when omitted. */
export interface InstallRequest {
  version?: string;
}
