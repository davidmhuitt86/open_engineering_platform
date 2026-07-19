import { ConflictError, NotFoundError } from '@oep-exchange/core';
import type { Queryable } from '../pool.js';
import type { NewPackageCategory, PackageCategory } from '../types.js';

export interface CategoryRepository {
  create(input: NewPackageCategory): Promise<PackageCategory>;
  findById(id: string): Promise<PackageCategory | null>;
  findBySlug(slug: string): Promise<PackageCategory | null>;
  list(): Promise<PackageCategory[]>;
  getByIdOrThrow(id: string): Promise<PackageCategory>;
}

interface PackageCategoryRow {
  id: string;
  slug: string;
  name: string;
  description: string;
  parent_id: string | null;
  row_version: number;
  created_at: Date;
  updated_at: Date;
}

const SELECT_COLUMNS = `id, slug, name, description, parent_id, row_version, created_at, updated_at`;

function mapRow(row: PackageCategoryRow): PackageCategory {
  return {
    id: row.id,
    slug: row.slug,
    name: row.name,
    description: row.description,
    parentId: row.parent_id,
    rowVersion: row.row_version,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

/** PostgreSQL-backed `CategoryRepository` (docs/tasks/WP-EXC-002.md §6) — the only place `package_categories` is queried (OWNERSHIP.md). */
export class PostgresCategoryRepository implements CategoryRepository {
  constructor(private readonly db: Queryable) {}

  async create(input: NewPackageCategory): Promise<PackageCategory> {
    const existing = await this.findBySlug(input.slug);
    if (existing) {
      throw new ConflictError(`Category slug "${input.slug}" already exists.`, {
        slug: input.slug,
      });
    }

    const result = await this.db.query<PackageCategoryRow>(
      `INSERT INTO package_categories (slug, name, description, parent_id)
       VALUES ($1, $2, $3, $4)
       RETURNING ${SELECT_COLUMNS}`,
      [input.slug, input.name, input.description ?? '', input.parentId ?? null],
    );
    return mapRow(result.rows[0]!);
  }

  async findById(id: string): Promise<PackageCategory | null> {
    const result = await this.db.query<PackageCategoryRow>(
      `SELECT ${SELECT_COLUMNS} FROM package_categories WHERE id = $1 AND deleted_at IS NULL`,
      [id],
    );
    return result.rows[0] ? mapRow(result.rows[0]) : null;
  }

  async findBySlug(slug: string): Promise<PackageCategory | null> {
    const result = await this.db.query<PackageCategoryRow>(
      `SELECT ${SELECT_COLUMNS} FROM package_categories WHERE slug = $1 AND deleted_at IS NULL`,
      [slug],
    );
    return result.rows[0] ? mapRow(result.rows[0]) : null;
  }

  async list(): Promise<PackageCategory[]> {
    const result = await this.db.query<PackageCategoryRow>(
      `SELECT ${SELECT_COLUMNS} FROM package_categories WHERE deleted_at IS NULL ORDER BY name ASC`,
    );
    return result.rows.map(mapRow);
  }

  async getByIdOrThrow(id: string): Promise<PackageCategory> {
    const category = await this.findById(id);
    if (!category) {
      throw new NotFoundError('PackageCategory', id);
    }
    return category;
  }
}
