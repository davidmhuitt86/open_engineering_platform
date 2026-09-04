import { NotFoundError } from '@oep-exchange/core';
import type { Queryable } from '../pool.js';
import type { NewPublisherProfile, PublisherProfile } from '../types.js';

export interface PublisherProfileRepository {
  upsertForPublisher(publisherId: string, input: NewPublisherProfile): Promise<PublisherProfile>;
  findByPublisherId(publisherId: string): Promise<PublisherProfile | null>;
  getByPublisherIdOrThrow(publisherId: string): Promise<PublisherProfile>;
}

interface PublisherProfileRow {
  id: string;
  publisher_id: string;
  organization_name: string;
  description: string;
  website: string;
  support_contact: string;
  documentation_url: string;
  logo_url: string;
  banner_url: string;
  engineering_disciplines: string[];
  country: string;
  languages: string[];
  social_links: Record<string, string>;
  verified_badges: string[];
  row_version: number;
  created_at: Date;
  updated_at: Date;
}

const SELECT_COLUMNS = `
  id, publisher_id, organization_name, description, website, support_contact,
  documentation_url, logo_url, banner_url, engineering_disciplines, country,
  languages, social_links, verified_badges, row_version, created_at, updated_at
`;

function mapRow(row: PublisherProfileRow): PublisherProfile {
  return {
    id: row.id,
    publisherId: row.publisher_id,
    organizationName: row.organization_name,
    description: row.description,
    website: row.website,
    supportContact: row.support_contact,
    documentationUrl: row.documentation_url,
    logoUrl: row.logo_url,
    bannerUrl: row.banner_url,
    engineeringDisciplines: row.engineering_disciplines,
    country: row.country,
    languages: row.languages,
    socialLinks: row.social_links,
    verifiedBadges: row.verified_badges,
    rowVersion: row.row_version,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

/** PostgreSQL-backed `PublisherProfileRepository` — the only place `publisher_profiles` is queried (OWNERSHIP.md). */
export class PostgresPublisherProfileRepository implements PublisherProfileRepository {
  constructor(private readonly db: Queryable) {}

  async upsertForPublisher(
    publisherId: string,
    input: NewPublisherProfile,
  ): Promise<PublisherProfile> {
    const result = await this.db.query<PublisherProfileRow>(
      `INSERT INTO publisher_profiles
         (publisher_id, organization_name, description, website, support_contact,
          documentation_url, logo_url, banner_url, engineering_disciplines, country,
          languages, social_links, verified_badges)
       SELECT p.id, $2, $3, $4, $5, $6, $7, $8, $9::jsonb, $10, $11::jsonb, $12::jsonb, $13::jsonb
       FROM publishers p WHERE p.id = $1 AND p.deleted_at IS NULL
       ON CONFLICT (publisher_id) WHERE deleted_at IS NULL DO UPDATE SET
         organization_name = EXCLUDED.organization_name,
         description = EXCLUDED.description,
         website = EXCLUDED.website,
         support_contact = EXCLUDED.support_contact,
         documentation_url = EXCLUDED.documentation_url,
         logo_url = EXCLUDED.logo_url,
         banner_url = EXCLUDED.banner_url,
         engineering_disciplines = EXCLUDED.engineering_disciplines,
         country = EXCLUDED.country,
         languages = EXCLUDED.languages,
         social_links = EXCLUDED.social_links,
         verified_badges = EXCLUDED.verified_badges,
         row_version = publisher_profiles.row_version + 1,
         updated_at = now()
       RETURNING ${SELECT_COLUMNS}`,
      [
        publisherId,
        input.organizationName ?? '',
        input.description ?? '',
        input.website ?? '',
        input.supportContact ?? '',
        input.documentationUrl ?? '',
        input.logoUrl ?? '',
        input.bannerUrl ?? '',
        JSON.stringify(input.engineeringDisciplines ?? []),
        input.country ?? '',
        JSON.stringify(input.languages ?? []),
        JSON.stringify(input.socialLinks ?? {}),
        JSON.stringify(input.verifiedBadges ?? []),
      ],
    );

    if (!result.rows[0]) {
      throw new NotFoundError('Publisher', publisherId);
    }
    return mapRow(result.rows[0]);
  }

  async findByPublisherId(publisherId: string): Promise<PublisherProfile | null> {
    const result = await this.db.query<PublisherProfileRow>(
      `SELECT ${SELECT_COLUMNS} FROM publisher_profiles
       WHERE publisher_id = $1 AND deleted_at IS NULL`,
      [publisherId],
    );
    return result.rows[0] ? mapRow(result.rows[0]) : null;
  }

  async getByPublisherIdOrThrow(publisherId: string): Promise<PublisherProfile> {
    const profile = await this.findByPublisherId(publisherId);
    if (!profile) {
      throw new NotFoundError('PublisherProfile', publisherId);
    }
    return profile;
  }
}
