import type { SearchResultItemDto } from '@oep-exchange/api-contracts';

export interface CategorySummary {
  id: string;
  name: string;
  packageCount: number;
}

/**
 * No dedicated "list categories" endpoint exists (only `GET /search`),
 * so the Marketplace Home/Categories pages derive the categories worth
 * showing from a broad search result rather than inventing a mock list
 * (WP-EXC-009.md §7 "The frontend shall not contain mock data") — a
 * category with no matching packages in the sample isn't shown, which is
 * the right behavior for a marketplace "browse by category" surface
 * anyway.
 */
export function deriveCategories(items: SearchResultItemDto[]): CategorySummary[] {
  const byId = new Map<string, CategorySummary>();
  for (const item of items) {
    if (!item.categoryId || !item.categoryName) {
      continue;
    }
    const existing = byId.get(item.categoryId);
    if (existing) {
      existing.packageCount += 1;
    } else {
      byId.set(item.categoryId, { id: item.categoryId, name: item.categoryName, packageCount: 1 });
    }
  }
  return [...byId.values()].sort((a, b) => a.name.localeCompare(b.name));
}
