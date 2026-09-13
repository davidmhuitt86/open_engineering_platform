/** The result of a successful package upload (TASK-EXC-0005, WP-EXC-005.md §5 "Return upload result"). */
export interface UploadResultDto {
  packageId: string;
  packageVersionId: string;
  packageFileId: string;
  version: string;
  fileName: string;
  sizeBytes: number;
  sha256: string;
  uploadedAt: string;
}
