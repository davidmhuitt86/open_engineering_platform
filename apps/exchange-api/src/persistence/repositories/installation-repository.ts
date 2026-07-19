import { NotFoundError } from '@oep-exchange/core';
import type { Queryable } from '../pool.js';
import type { Installation, NewInstallation } from '../types.js';

export interface InstallationRepository {
  create(input: NewInstallation): Promise<Installation>;
  findById(id: string): Promise<Installation | null>;
  getByIdOrThrow(id: string): Promise<Installation>;
  complete(id: string, repositoryPackageId: string | null): Promise<Installation>;
  fail(id: string, errorMessage: string): Promise<Installation>;
}

interface InstallationRow {
  id: string;
  package_id: string;
  package_version_id: string;
  status: string;
  repository_package_id: string | null;
  error_message: string | null;
  requested_at: Date;
  completed_at: Date | null;
  row_version: number;
  created_at: Date;
  updated_at: Date;
}

const SELECT_COLUMNS = `
  id, package_id, package_version_id, status, repository_package_id, error_message,
  requested_at, completed_at, row_version, created_at, updated_at
`;

function mapRow(row: InstallationRow): Installation {
  return {
    id: row.id,
    packageId: row.package_id,
    packageVersionId: row.package_version_id,
    status: row.status as Installation['status'],
    repositoryPackageId: row.repository_package_id,
    errorMessage: row.error_message,
    requestedAt: row.requested_at,
    completedAt: row.completed_at,
    rowVersion: row.row_version,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

/**
 * PostgreSQL-backed `InstallationRepository` — the only place
 * `installations` is queried (OWNERSHIP.md). Rows are created once
 * (`status = 'pending'`) and transitioned exactly once more, to a
 * terminal state, via `complete()`/`fail()`.
 */
export class PostgresInstallationRepository implements InstallationRepository {
  constructor(private readonly db: Queryable) {}

  async create(input: NewInstallation): Promise<Installation> {
    const result = await this.db.query<InstallationRow>(
      `INSERT INTO installations (package_id, package_version_id)
       VALUES ($1, $2)
       RETURNING ${SELECT_COLUMNS}`,
      [input.packageId, input.packageVersionId],
    );
    return mapRow(result.rows[0]!);
  }

  async findById(id: string): Promise<Installation | null> {
    const result = await this.db.query<InstallationRow>(
      `SELECT ${SELECT_COLUMNS} FROM installations WHERE id = $1`,
      [id],
    );
    return result.rows[0] ? mapRow(result.rows[0]) : null;
  }

  async getByIdOrThrow(id: string): Promise<Installation> {
    const installation = await this.findById(id);
    if (!installation) {
      throw new NotFoundError('Installation', id);
    }
    return installation;
  }

  async complete(id: string, repositoryPackageId: string | null): Promise<Installation> {
    const result = await this.db.query<InstallationRow>(
      `UPDATE installations
       SET status = 'completed', repository_package_id = $2, completed_at = now(),
           row_version = row_version + 1, updated_at = now()
       WHERE id = $1
       RETURNING ${SELECT_COLUMNS}`,
      [id, repositoryPackageId],
    );
    if (!result.rows[0]) {
      throw new NotFoundError('Installation', id);
    }
    return mapRow(result.rows[0]);
  }

  async fail(id: string, errorMessage: string): Promise<Installation> {
    const result = await this.db.query<InstallationRow>(
      `UPDATE installations
       SET status = 'failed', error_message = $2, completed_at = now(),
           row_version = row_version + 1, updated_at = now()
       WHERE id = $1
       RETURNING ${SELECT_COLUMNS}`,
      [id, errorMessage],
    );
    if (!result.rows[0]) {
      throw new NotFoundError('Installation', id);
    }
    return mapRow(result.rows[0]);
  }
}
