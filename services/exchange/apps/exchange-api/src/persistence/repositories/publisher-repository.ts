import { ConflictError, NotFoundError } from '@oep-exchange/core';
import type { Queryable } from '../pool.js';
import type { NewPublisher, Publisher, PublisherUpdate } from '../types.js';

export interface PublisherRepository {
  create(input: NewPublisher): Promise<Publisher>;
  findById(id: string): Promise<Publisher | null>;
  findByNamespace(namespace: string): Promise<Publisher | null>;
  findByName(name: string): Promise<Publisher | null>;
  findByContactEmail(contactEmail: string): Promise<Publisher | null>;
  list(): Promise<Publisher[]>;
  getByIdOrThrow(id: string): Promise<Publisher>;
  update(id: string, changes: PublisherUpdate): Promise<Publisher>;
  softDelete(id: string): Promise<void>;
}

interface PublisherRow {
  id: string;
  name: string;
  display_name: string;
  namespace: string;
  publisher_type: string;
  verification_status: string;
  trust_status: string;
  status: string;
  contact_email: string;
  row_version: number;
  created_at: Date;
  updated_at: Date;
}

const SELECT_COLUMNS = `
  id, name, display_name, namespace, publisher_type, verification_status,
  trust_status, status, contact_email, row_version, created_at, updated_at
`;

function mapRow(row: PublisherRow): Publisher {
  return {
    id: row.id,
    name: row.name,
    displayName: row.display_name,
    namespace: row.namespace,
    publisherType: row.publisher_type as Publisher['publisherType'],
    verificationStatus: row.verification_status as Publisher['verificationStatus'],
    trustStatus: row.trust_status as Publisher['trustStatus'],
    status: row.status as Publisher['status'],
    contactEmail: row.contact_email,
    rowVersion: row.row_version,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

/** PostgreSQL-backed `PublisherRepository` — the only place `publishers` is queried (OWNERSHIP.md). */
export class PostgresPublisherRepository implements PublisherRepository {
  constructor(private readonly db: Queryable) {}

  async create(input: NewPublisher): Promise<Publisher> {
    const existingNamespace = await this.findByNamespace(input.namespace);
    if (existingNamespace) {
      throw new ConflictError(`Namespace "${input.namespace}" is already owned by a Publisher.`, {
        namespace: input.namespace,
      });
    }

    const existingName = await this.findByName(input.name);
    if (existingName) {
      throw new ConflictError(`Publisher name "${input.name}" is already in use.`, {
        name: input.name,
      });
    }

    if (input.contactEmail) {
      const existingEmail = await this.findByContactEmail(input.contactEmail);
      if (existingEmail) {
        throw new ConflictError(`Contact email "${input.contactEmail}" is already in use.`, {
          contactEmail: input.contactEmail,
        });
      }
    }

    const result = await this.db.query<PublisherRow>(
      `INSERT INTO publishers
         (name, display_name, namespace, publisher_type, verification_status, trust_status, contact_email)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING ${SELECT_COLUMNS}`,
      [
        input.name,
        input.displayName,
        input.namespace,
        input.publisherType,
        input.verificationStatus ?? 'unverified',
        input.trustStatus ?? 'standard',
        input.contactEmail ?? '',
      ],
    );
    return mapRow(result.rows[0]!);
  }

  async findById(id: string): Promise<Publisher | null> {
    const result = await this.db.query<PublisherRow>(
      `SELECT ${SELECT_COLUMNS} FROM publishers WHERE id = $1 AND deleted_at IS NULL`,
      [id],
    );
    return result.rows[0] ? mapRow(result.rows[0]) : null;
  }

  async findByNamespace(namespace: string): Promise<Publisher | null> {
    const result = await this.db.query<PublisherRow>(
      `SELECT ${SELECT_COLUMNS} FROM publishers WHERE namespace = $1 AND deleted_at IS NULL`,
      [namespace],
    );
    return result.rows[0] ? mapRow(result.rows[0]) : null;
  }

  async findByName(name: string): Promise<Publisher | null> {
    const result = await this.db.query<PublisherRow>(
      `SELECT ${SELECT_COLUMNS} FROM publishers WHERE name = $1 AND deleted_at IS NULL`,
      [name],
    );
    return result.rows[0] ? mapRow(result.rows[0]) : null;
  }

  async findByContactEmail(contactEmail: string): Promise<Publisher | null> {
    const result = await this.db.query<PublisherRow>(
      `SELECT ${SELECT_COLUMNS} FROM publishers
       WHERE lower(contact_email) = lower($1) AND contact_email <> '' AND deleted_at IS NULL`,
      [contactEmail],
    );
    return result.rows[0] ? mapRow(result.rows[0]) : null;
  }

  async list(): Promise<Publisher[]> {
    const result = await this.db.query<PublisherRow>(
      `SELECT ${SELECT_COLUMNS} FROM publishers WHERE deleted_at IS NULL ORDER BY created_at ASC`,
    );
    return result.rows.map(mapRow);
  }

  async getByIdOrThrow(id: string): Promise<Publisher> {
    const publisher = await this.findById(id);
    if (!publisher) {
      throw new NotFoundError('Publisher', id);
    }
    return publisher;
  }

  async update(id: string, changes: PublisherUpdate): Promise<Publisher> {
    if (changes.contactEmail) {
      const existingEmail = await this.findByContactEmail(changes.contactEmail);
      if (existingEmail && existingEmail.id !== id) {
        throw new ConflictError(`Contact email "${changes.contactEmail}" is already in use.`, {
          contactEmail: changes.contactEmail,
        });
      }
    }

    const result = await this.db.query<PublisherRow>(
      `UPDATE publishers
       SET display_name = COALESCE($2, display_name),
           contact_email = COALESCE($3, contact_email),
           status = COALESCE($4, status),
           row_version = row_version + 1,
           updated_at = now()
       WHERE id = $1 AND deleted_at IS NULL
       RETURNING ${SELECT_COLUMNS}`,
      [id, changes.displayName ?? null, changes.contactEmail ?? null, changes.status ?? null],
    );
    if (!result.rows[0]) {
      throw new NotFoundError('Publisher', id);
    }
    return mapRow(result.rows[0]);
  }

  async softDelete(id: string): Promise<void> {
    const result = await this.db.query(
      `UPDATE publishers SET deleted_at = now(), updated_at = now()
       WHERE id = $1 AND deleted_at IS NULL`,
      [id],
    );
    if (result.rowCount === 0) {
      throw new NotFoundError('Publisher', id);
    }
  }
}
