import { ConflictError, NotFoundError } from '@oep-exchange/core';
import type { Queryable } from '../pool.js';
import type { NewPackageVersion, PackageVersion } from '../types.js';

export interface PackageVersionRepository {
  create(input: NewPackageVersion): Promise<PackageVersion>;
  findById(id: string): Promise<PackageVersion | null>;
  findByPackageAndVersion(packageId: string, version: string): Promise<PackageVersion | null>;
  listByPackage(packageId: string): Promise<PackageVersion[]>;
  getByIdOrThrow(id: string): Promise<PackageVersion>;
  publish(id: string): Promise<PackageVersion>;
}

interface PackageVersionRow {
  id: string;
  package_id: string;
  version: string;
  schema_version: string;
  manifest: Record<string, unknown>;
  dependencies: PackageVersion['dependencies'];
  repository_stats: PackageVersion['repositoryStats'];
  statistics: PackageVersion['statistics'];
  signatures: PackageVersion['signatures'];
  build_metadata: PackageVersion['buildMetadata'];
  release_channel: string;
  status: string;
  published_at: Date | null;
  row_version: number;
  created_at: Date;
  updated_at: Date;
}

const SELECT_COLUMNS = `
  id, package_id, version, schema_version, manifest, dependencies, repository_stats,
  statistics, signatures, build_metadata, release_channel, status, published_at,
  row_version, created_at, updated_at
`;

function mapRow(row: PackageVersionRow): PackageVersion {
  return {
    id: row.id,
    packageId: row.package_id,
    version: row.version,
    schemaVersion: row.schema_version,
    manifest: row.manifest,
    dependencies: row.dependencies,
    repositoryStats: row.repository_stats,
    statistics: row.statistics,
    signatures: row.signatures,
    buildMetadata: row.build_metadata,
    releaseChannel: row.release_channel as PackageVersion['releaseChannel'],
    status: row.status as PackageVersion['status'],
    publishedAt: row.published_at,
    rowVersion: row.row_version,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

/** PostgreSQL-backed `PackageVersionRepository` — the only place `package_versions` is queried (OWNERSHIP.md). */
export class PostgresPackageVersionRepository implements PackageVersionRepository {
  constructor(private readonly db: Queryable) {}

  async create(input: NewPackageVersion): Promise<PackageVersion> {
    const existing = await this.findByPackageAndVersion(input.packageId, input.version);
    if (existing) {
      throw new ConflictError(`Version "${input.version}" already exists for this package.`, {
        packageId: input.packageId,
        version: input.version,
      });
    }

    const result = await this.db.query<PackageVersionRow>(
      `INSERT INTO package_versions
         (package_id, version, schema_version, manifest, dependencies, repository_stats,
          statistics, signatures, build_metadata, release_channel)
       VALUES ($1, $2, $3, $4::jsonb, $5::jsonb, $6::jsonb, $7::jsonb, $8::jsonb, $9::jsonb, $10)
       RETURNING ${SELECT_COLUMNS}`,
      [
        input.packageId,
        input.version,
        input.schemaVersion ?? '1.0',
        JSON.stringify(input.manifest),
        JSON.stringify(input.dependencies ?? []),
        JSON.stringify(input.repositoryStats ?? {}),
        JSON.stringify(input.statistics ?? {}),
        JSON.stringify(input.signatures ?? {}),
        JSON.stringify(input.buildMetadata ?? {}),
        input.releaseChannel ?? 'stable',
      ],
    );
    return mapRow(result.rows[0]!);
  }

  async findById(id: string): Promise<PackageVersion | null> {
    const result = await this.db.query<PackageVersionRow>(
      `SELECT ${SELECT_COLUMNS} FROM package_versions WHERE id = $1 AND deleted_at IS NULL`,
      [id],
    );
    return result.rows[0] ? mapRow(result.rows[0]) : null;
  }

  async findByPackageAndVersion(
    packageId: string,
    version: string,
  ): Promise<PackageVersion | null> {
    const result = await this.db.query<PackageVersionRow>(
      `SELECT ${SELECT_COLUMNS} FROM package_versions
       WHERE package_id = $1 AND version = $2 AND deleted_at IS NULL`,
      [packageId, version],
    );
    return result.rows[0] ? mapRow(result.rows[0]) : null;
  }

  async listByPackage(packageId: string): Promise<PackageVersion[]> {
    const result = await this.db.query<PackageVersionRow>(
      `SELECT ${SELECT_COLUMNS} FROM package_versions
       WHERE package_id = $1 AND deleted_at IS NULL
       ORDER BY created_at ASC`,
      [packageId],
    );
    return result.rows.map(mapRow);
  }

  async getByIdOrThrow(id: string): Promise<PackageVersion> {
    const version = await this.findById(id);
    if (!version) {
      throw new NotFoundError('PackageVersion', id);
    }
    return version;
  }

  async publish(id: string): Promise<PackageVersion> {
    const result = await this.db.query<PackageVersionRow>(
      `UPDATE package_versions
       SET status = 'published', published_at = now(), row_version = row_version + 1, updated_at = now()
       WHERE id = $1 AND deleted_at IS NULL
       RETURNING ${SELECT_COLUMNS}`,
      [id],
    );
    if (!result.rows[0]) {
      throw new NotFoundError('PackageVersion', id);
    }
    return mapRow(result.rows[0]);
  }
}
