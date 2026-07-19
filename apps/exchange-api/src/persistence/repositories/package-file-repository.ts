import { NotFoundError } from '@oep-exchange/core';
import type { Queryable } from '../pool.js';
import type { NewPackageFile, PackageFile } from '../types.js';

export interface PackageFileRepository {
  create(input: NewPackageFile): Promise<PackageFile>;
  findById(id: string): Promise<PackageFile | null>;
  listByVersion(packageVersionId: string): Promise<PackageFile[]>;
  getByIdOrThrow(id: string): Promise<PackageFile>;
}

interface PackageFileRow {
  id: string;
  package_version_id: string;
  file_name: string;
  mime_type: string;
  size_bytes: string;
  storage_path: string;
  sha256: string;
  blake3: string | null;
  signature_algorithm: string | null;
  row_version: number;
  created_at: Date;
  updated_at: Date;
}

const SELECT_COLUMNS = `
  id, package_version_id, file_name, mime_type, size_bytes, storage_path, sha256,
  blake3, signature_algorithm, row_version, created_at, updated_at
`;

function mapRow(row: PackageFileRow): PackageFile {
  return {
    id: row.id,
    packageVersionId: row.package_version_id,
    fileName: row.file_name,
    mimeType: row.mime_type,
    sizeBytes: Number(row.size_bytes),
    storagePath: row.storage_path,
    sha256: row.sha256,
    blake3: row.blake3,
    signatureAlgorithm: row.signature_algorithm,
    rowVersion: row.row_version,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

/** PostgreSQL-backed `PackageFileRepository` — the only place `package_files` is queried (OWNERSHIP.md). */
export class PostgresPackageFileRepository implements PackageFileRepository {
  constructor(private readonly db: Queryable) {}

  async create(input: NewPackageFile): Promise<PackageFile> {
    const result = await this.db.query<PackageFileRow>(
      `INSERT INTO package_files
         (package_version_id, file_name, mime_type, size_bytes, storage_path, sha256, blake3, signature_algorithm)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING ${SELECT_COLUMNS}`,
      [
        input.packageVersionId,
        input.fileName,
        input.mimeType ?? 'application/vnd.oep.package',
        input.sizeBytes,
        input.storagePath,
        input.sha256,
        input.blake3 ?? null,
        input.signatureAlgorithm ?? null,
      ],
    );
    return mapRow(result.rows[0]!);
  }

  async findById(id: string): Promise<PackageFile | null> {
    const result = await this.db.query<PackageFileRow>(
      `SELECT ${SELECT_COLUMNS} FROM package_files WHERE id = $1 AND deleted_at IS NULL`,
      [id],
    );
    return result.rows[0] ? mapRow(result.rows[0]) : null;
  }

  async listByVersion(packageVersionId: string): Promise<PackageFile[]> {
    const result = await this.db.query<PackageFileRow>(
      `SELECT ${SELECT_COLUMNS} FROM package_files
       WHERE package_version_id = $1 AND deleted_at IS NULL
       ORDER BY created_at ASC`,
      [packageVersionId],
    );
    return result.rows.map(mapRow);
  }

  async getByIdOrThrow(id: string): Promise<PackageFile> {
    const file = await this.findById(id);
    if (!file) {
      throw new NotFoundError('PackageFile', id);
    }
    return file;
  }
}
