import type { Queryable } from '../pool.js';
import type { Download, NewDownload } from '../types.js';

export interface DownloadRepository {
  record(input: NewDownload): Promise<Download>;
  countByVersion(packageVersionId: string): Promise<number>;
  listByVersion(packageVersionId: string): Promise<Download[]>;
}

interface DownloadRow {
  id: string;
  package_version_id: string;
  downloaded_at: Date;
  client_ip: string | null;
  user_agent: string | null;
}

const SELECT_COLUMNS = `id, package_version_id, downloaded_at, client_ip, user_agent`;

function mapRow(row: DownloadRow): Download {
  return {
    id: row.id,
    packageVersionId: row.package_version_id,
    downloadedAt: row.downloaded_at,
    clientIp: row.client_ip,
    userAgent: row.user_agent,
  };
}

/**
 * PostgreSQL-backed `DownloadRepository` — the only place `downloads` is
 * queried (OWNERSHIP.md). `downloads` is an append-only event log (see
 * `V1__initial_exchange_schema.sql`), so this repository has no
 * update/delete.
 */
export class PostgresDownloadRepository implements DownloadRepository {
  constructor(private readonly db: Queryable) {}

  async record(input: NewDownload): Promise<Download> {
    const result = await this.db.query<DownloadRow>(
      `INSERT INTO downloads (package_version_id, client_ip, user_agent)
       VALUES ($1, $2, $3)
       RETURNING ${SELECT_COLUMNS}`,
      [input.packageVersionId, input.clientIp ?? null, input.userAgent ?? null],
    );
    return mapRow(result.rows[0]!);
  }

  async countByVersion(packageVersionId: string): Promise<number> {
    const result = await this.db.query<{ count: string }>(
      `SELECT COUNT(*) AS count FROM downloads WHERE package_version_id = $1`,
      [packageVersionId],
    );
    return Number(result.rows[0]!.count);
  }

  async listByVersion(packageVersionId: string): Promise<Download[]> {
    const result = await this.db.query<DownloadRow>(
      `SELECT ${SELECT_COLUMNS} FROM downloads
       WHERE package_version_id = $1
       ORDER BY downloaded_at ASC`,
      [packageVersionId],
    );
    return result.rows.map(mapRow);
  }
}
