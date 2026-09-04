import { ConflictError, NotFoundError } from '@oep-exchange/core';
import type { Queryable } from '../pool.js';
import type { NewPackage, Package, PackageUpdate } from '../types.js';

export interface PackageRepository {
  create(input: NewPackage): Promise<Package>;
  findById(id: string): Promise<Package | null>;
  findByPackageId(packageId: string): Promise<Package | null>;
  findByPublisherAndTitle(publisherId: string, title: string): Promise<Package | null>;
  list(): Promise<Package[]>;
  listByPublisher(publisherId: string): Promise<Package[]>;
  getByIdOrThrow(id: string): Promise<Package>;
  setLatestVersion(id: string, versionId: string): Promise<void>;
  update(id: string, changes: PackageUpdate): Promise<Package>;
  softDelete(id: string): Promise<void>;
}

interface PackageRow {
  id: string;
  package_id: string;
  publisher_id: string;
  title: string;
  summary: string;
  description: string;
  category_id: string | null;
  engineering_domains: string[];
  keywords: string[];
  capabilities: string[];
  license: Record<string, unknown>;
  status: string;
  latest_version_id: string | null;
  row_version: number;
  created_at: Date;
  updated_at: Date;
}

const SELECT_COLUMNS = `
  id, package_id, publisher_id, title, summary, description, category_id,
  engineering_domains, keywords, capabilities, license, status, latest_version_id,
  row_version, created_at, updated_at
`;

function mapRow(row: PackageRow): Package {
  return {
    id: row.id,
    packageId: row.package_id,
    publisherId: row.publisher_id,
    title: row.title,
    summary: row.summary,
    description: row.description,
    categoryId: row.category_id,
    engineeringDomains: row.engineering_domains,
    keywords: row.keywords,
    capabilities: row.capabilities,
    license: row.license,
    status: row.status as Package['status'],
    latestVersionId: row.latest_version_id,
    rowVersion: row.row_version,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

/** PostgreSQL-backed `PackageRepository` — the only place `packages` is queried (OWNERSHIP.md). */
export class PostgresPackageRepository implements PackageRepository {
  constructor(private readonly db: Queryable) {}

  async create(input: NewPackage): Promise<Package> {
    const existingPackageId = await this.findByPackageId(input.packageId);
    if (existingPackageId) {
      throw new ConflictError(`Package ID "${input.packageId}" is already in use.`, {
        packageId: input.packageId,
      });
    }

    const existingTitle = await this.findByPublisherAndTitle(input.publisherId, input.title);
    if (existingTitle) {
      throw new ConflictError(`This Publisher already has a package named "${input.title}".`, {
        publisherId: input.publisherId,
        title: input.title,
      });
    }

    const result = await this.db.query<PackageRow>(
      `INSERT INTO packages
         (package_id, publisher_id, title, summary, description, category_id,
          engineering_domains, keywords, capabilities, license, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, $8::jsonb, $9::jsonb, $10::jsonb, $11)
       RETURNING ${SELECT_COLUMNS}`,
      [
        input.packageId,
        input.publisherId,
        input.title,
        input.summary ?? '',
        input.description ?? '',
        input.categoryId ?? null,
        JSON.stringify(input.engineeringDomains ?? []),
        JSON.stringify(input.keywords ?? []),
        JSON.stringify(input.capabilities ?? []),
        JSON.stringify(input.license ?? {}),
        input.status ?? 'draft',
      ],
    );
    return mapRow(result.rows[0]!);
  }

  async findById(id: string): Promise<Package | null> {
    const result = await this.db.query<PackageRow>(
      `SELECT ${SELECT_COLUMNS} FROM packages WHERE id = $1 AND deleted_at IS NULL`,
      [id],
    );
    return result.rows[0] ? mapRow(result.rows[0]) : null;
  }

  async findByPackageId(packageId: string): Promise<Package | null> {
    const result = await this.db.query<PackageRow>(
      `SELECT ${SELECT_COLUMNS} FROM packages WHERE package_id = $1 AND deleted_at IS NULL`,
      [packageId],
    );
    return result.rows[0] ? mapRow(result.rows[0]) : null;
  }

  async findByPublisherAndTitle(publisherId: string, title: string): Promise<Package | null> {
    const result = await this.db.query<PackageRow>(
      `SELECT ${SELECT_COLUMNS} FROM packages
       WHERE publisher_id = $1 AND title = $2 AND deleted_at IS NULL`,
      [publisherId, title],
    );
    return result.rows[0] ? mapRow(result.rows[0]) : null;
  }

  async list(): Promise<Package[]> {
    const result = await this.db.query<PackageRow>(
      `SELECT ${SELECT_COLUMNS} FROM packages WHERE deleted_at IS NULL ORDER BY created_at ASC`,
    );
    return result.rows.map(mapRow);
  }

  async listByPublisher(publisherId: string): Promise<Package[]> {
    const result = await this.db.query<PackageRow>(
      `SELECT ${SELECT_COLUMNS} FROM packages
       WHERE publisher_id = $1 AND deleted_at IS NULL
       ORDER BY created_at ASC`,
      [publisherId],
    );
    return result.rows.map(mapRow);
  }

  async getByIdOrThrow(id: string): Promise<Package> {
    const pkg = await this.findById(id);
    if (!pkg) {
      throw new NotFoundError('Package', id);
    }
    return pkg;
  }

  async setLatestVersion(id: string, versionId: string): Promise<void> {
    const result = await this.db.query(
      `UPDATE packages
       SET latest_version_id = $2, row_version = row_version + 1, updated_at = now()
       WHERE id = $1 AND deleted_at IS NULL`,
      [id, versionId],
    );
    if (result.rowCount === 0) {
      throw new NotFoundError('Package', id);
    }
  }

  async update(id: string, changes: PackageUpdate): Promise<Package> {
    if (changes.title) {
      const current = await this.getByIdOrThrow(id);
      const owner = await this.findByPublisherAndTitle(current.publisherId, changes.title);
      if (owner && owner.id !== id) {
        throw new ConflictError(`This Publisher already has a package named "${changes.title}".`, {
          publisherId: current.publisherId,
          title: changes.title,
        });
      }
    }

    const result = await this.db.query<PackageRow>(
      `UPDATE packages
       SET title = COALESCE($2, title),
           description = COALESCE($3, description),
           category_id = CASE WHEN $4 THEN $5 ELSE category_id END,
           status = COALESCE($6, status),
           row_version = row_version + 1,
           updated_at = now()
       WHERE id = $1 AND deleted_at IS NULL
       RETURNING ${SELECT_COLUMNS}`,
      [
        id,
        changes.title ?? null,
        changes.description ?? null,
        changes.categoryId !== undefined,
        changes.categoryId ?? null,
        changes.status ?? null,
      ],
    );
    if (!result.rows[0]) {
      throw new NotFoundError('Package', id);
    }
    return mapRow(result.rows[0]);
  }

  async softDelete(id: string): Promise<void> {
    const result = await this.db.query(
      `UPDATE packages SET deleted_at = now(), updated_at = now()
       WHERE id = $1 AND deleted_at IS NULL`,
      [id],
    );
    if (result.rowCount === 0) {
      throw new NotFoundError('Package', id);
    }
  }
}
