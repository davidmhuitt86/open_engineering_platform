import type { Queryable } from '../pool.js';
import type { AuditLogEntry, NewAuditLogEntry } from '../types.js';

export interface AuditRepository {
  record(input: NewAuditLogEntry): Promise<AuditLogEntry>;
  listByEntity(entityType: string, entityId: string): Promise<AuditLogEntry[]>;
}

interface AuditLogRow {
  id: string;
  entity_type: string;
  entity_id: string;
  action: string;
  actor: string | null;
  metadata: Record<string, unknown>;
  occurred_at: Date;
}

const SELECT_COLUMNS = `id, entity_type, entity_id, action, actor, metadata, occurred_at`;

function mapRow(row: AuditLogRow): AuditLogEntry {
  return {
    id: row.id,
    entityType: row.entity_type,
    entityId: row.entity_id,
    action: row.action,
    actor: row.actor,
    metadata: row.metadata,
    occurredAt: row.occurred_at,
  };
}

/**
 * PostgreSQL-backed `AuditRepository` (docs/tasks/WP-EXC-002.md §4/§6) —
 * the only place `audit_log` is queried (OWNERSHIP.md). `audit_log` is
 * an append-only event log (see `V1__initial_exchange_schema.sql`), so
 * this repository has no update/delete.
 */
export class PostgresAuditRepository implements AuditRepository {
  constructor(private readonly db: Queryable) {}

  async record(input: NewAuditLogEntry): Promise<AuditLogEntry> {
    const result = await this.db.query<AuditLogRow>(
      `INSERT INTO audit_log (entity_type, entity_id, action, actor, metadata)
       VALUES ($1, $2, $3, $4, $5::jsonb)
       RETURNING ${SELECT_COLUMNS}`,
      [
        input.entityType,
        input.entityId,
        input.action,
        input.actor ?? null,
        JSON.stringify(input.metadata ?? {}),
      ],
    );
    return mapRow(result.rows[0]!);
  }

  async listByEntity(entityType: string, entityId: string): Promise<AuditLogEntry[]> {
    const result = await this.db.query<AuditLogRow>(
      `SELECT ${SELECT_COLUMNS} FROM audit_log
       WHERE entity_type = $1 AND entity_id = $2
       ORDER BY occurred_at ASC`,
      [entityType, entityId],
    );
    return result.rows.map(mapRow);
  }
}
