import type { Queryable } from '../pool.js';
import type { SearchQuery, SearchResultItem, SearchResults } from '../types.js';

export interface SearchRepository {
  search(query: SearchQuery): Promise<SearchResults>;
}

interface SearchRow {
  id: string;
  package_id: string;
  publisher_id: string;
  publisher_name: string;
  title: string;
  description: string;
  category_id: string | null;
  category_name: string | null;
  current_version: string | null;
  status: string;
  created_at: Date;
  updated_at: Date;
  total_count: string;
}

const SORT_COLUMNS: Record<SearchQuery['sortBy'], string> = {
  name: 'pkg.title',
  createdAt: 'pkg.created_at',
  updatedAt: 'pkg.updated_at',
};

function mapRow(row: SearchRow): SearchResultItem {
  return {
    id: row.id,
    packageId: row.package_id,
    publisherId: row.publisher_id,
    publisherName: row.publisher_name,
    displayName: row.title,
    description: row.description,
    categoryId: row.category_id,
    categoryName: row.category_name,
    currentVersion: row.current_version,
    status: row.status as SearchResultItem['status'],
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

/**
 * PostgreSQL-backed `SearchRepository` (WP-EXC-006.md §3/§9) — the only
 * place `search_index` is queried (OWNERSHIP.md). Keyword matching uses
 * `search_index.search_vector` (maintained by a trigger on `packages`,
 * see `db/migrations/V5__search_index.sql`); filtering/sorting/
 * pagination operate on `packages` and its joined Publisher/Category/
 * current-version fields directly. `COUNT(*) OVER()` returns the total
 * matching row count in the same query rather than a second round trip.
 */
export class PostgresSearchRepository implements SearchRepository {
  constructor(private readonly db: Queryable) {}

  async search(query: SearchQuery): Promise<SearchResults> {
    const conditions: string[] = ['pkg.deleted_at IS NULL'];
    const params: unknown[] = [];

    if (query.keyword) {
      params.push(query.keyword);
      conditions.push(`si.search_vector @@ websearch_to_tsquery('english', $${params.length})`);
    }
    if (query.publisherId) {
      params.push(query.publisherId);
      conditions.push(`pkg.publisher_id = $${params.length}`);
    }
    if (query.categoryId) {
      params.push(query.categoryId);
      conditions.push(`pkg.category_id = $${params.length}`);
    }
    if (query.status) {
      params.push(query.status);
      conditions.push(`pkg.status = $${params.length}`);
    }

    const sortColumn = SORT_COLUMNS[query.sortBy];
    const sortDirection = query.sortDirection === 'asc' ? 'ASC' : 'DESC';

    params.push(query.pageSize);
    const limitParam = params.length;
    params.push((query.page - 1) * query.pageSize);
    const offsetParam = params.length;

    const result = await this.db.query<SearchRow>(
      `SELECT
         pkg.id, pkg.package_id, pkg.publisher_id, pub.name AS publisher_name,
         pkg.title, pkg.description, pkg.category_id, cat.name AS category_name,
         ver.version AS current_version, pkg.status, pkg.created_at, pkg.updated_at,
         COUNT(*) OVER() AS total_count
       FROM packages pkg
       JOIN publishers pub ON pub.id = pkg.publisher_id
       LEFT JOIN package_categories cat ON cat.id = pkg.category_id
       LEFT JOIN package_versions ver ON ver.id = pkg.latest_version_id
       LEFT JOIN search_index si ON si.package_id = pkg.id
       WHERE ${conditions.join(' AND ')}
       ORDER BY ${sortColumn} ${sortDirection}
       LIMIT $${limitParam} OFFSET $${offsetParam}`,
      params,
    );

    return {
      items: result.rows.map(mapRow),
      totalCount: result.rows[0] ? Number(result.rows[0].total_count) : 0,
    };
  }
}
