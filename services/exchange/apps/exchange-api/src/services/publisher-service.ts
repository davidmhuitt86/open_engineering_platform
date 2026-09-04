import type {
  CreatePublisherRequest,
  PublisherDto,
  UpdatePublisherRequest,
} from '@oep-exchange/api-contracts';
import type {
  AuditRepository,
  Publisher,
  PublisherProfileRepository,
  PublisherRepository,
} from '../persistence/index.js';
import {
  validateCreatePublisherRequest,
  validatePublisherId,
  validateStatusTransition,
  validateUpdatePublisherRequest,
} from './publisher-validation.js';

/**
 * The Publisher Registry's business logic (docs/tasks/WP-EXC-003.md §3:
 * "REST API -> Publisher Service -> Publisher Repository -> PostgreSQL.
 * Business logic shall remain inside the Publisher Service."). Routes
 * (`routes/publishers.ts`) call this and shape the response; they never
 * issue SQL or apply validation themselves (CONTRIBUTING_ARCHITECTURE.md
 * rule 8). Merges each Publisher's `publisher_profiles` row (built in
 * TASK-EXC-0002) into the API-facing `description`/`website` fields, and
 * records an `audit_log` entry for every mutation (WP-EXC-001 §4 "All
 * transactions are audited").
 */
export class PublisherService {
  constructor(
    private readonly publishers: PublisherRepository,
    private readonly profiles: PublisherProfileRepository,
    private readonly audit: AuditRepository,
  ) {}

  async list(): Promise<PublisherDto[]> {
    const all = await this.publishers.list();
    return Promise.all(all.map((publisher) => this.toDto(publisher)));
  }

  async getById(id: string): Promise<PublisherDto> {
    validatePublisherId(id);
    const publisher = await this.publishers.getByIdOrThrow(id);
    return this.toDto(publisher);
  }

  async create(input: CreatePublisherRequest): Promise<PublisherDto> {
    validateCreatePublisherRequest(input);

    const created = await this.publishers.create({
      name: input.legalName,
      displayName: input.displayName,
      namespace: input.namespace,
      publisherType: input.publisherType,
      contactEmail: input.contactEmail,
    });

    if (input.description !== undefined || input.website !== undefined) {
      await this.profiles.upsertForPublisher(created.id, {
        publisherId: created.id,
        ...(input.description !== undefined ? { description: input.description } : {}),
        ...(input.website !== undefined ? { website: input.website } : {}),
      });
    }

    await this.audit.record({
      entityType: 'publisher',
      entityId: created.id,
      action: 'PublisherCreated',
      metadata: { namespace: created.namespace },
    });

    return this.toDto(created);
  }

  async update(id: string, input: UpdatePublisherRequest): Promise<PublisherDto> {
    validatePublisherId(id);
    validateUpdatePublisherRequest(input);

    const current = await this.publishers.getByIdOrThrow(id);

    if (input.status !== undefined) {
      validateStatusTransition(current.status, input.status);
    }

    const updated = await this.publishers.update(id, {
      ...(input.displayName !== undefined ? { displayName: input.displayName } : {}),
      ...(input.contactEmail !== undefined ? { contactEmail: input.contactEmail } : {}),
      ...(input.status !== undefined ? { status: input.status } : {}),
    });

    if (input.description !== undefined || input.website !== undefined) {
      const existingProfile = await this.profiles.findByPublisherId(id);
      const description = input.description ?? existingProfile?.description;
      const website = input.website ?? existingProfile?.website;
      await this.profiles.upsertForPublisher(id, {
        publisherId: id,
        ...(description !== undefined ? { description } : {}),
        ...(website !== undefined ? { website } : {}),
      });
    }

    await this.audit.record({
      entityType: 'publisher',
      entityId: id,
      action: this.describeUpdateAction(current.status, input.status),
      metadata: { changes: input },
    });

    return this.toDto(updated);
  }

  async remove(id: string): Promise<void> {
    validatePublisherId(id);
    await this.publishers.getByIdOrThrow(id);
    await this.publishers.softDelete(id);

    await this.audit.record({
      entityType: 'publisher',
      entityId: id,
      action: 'PublisherDeleted',
    });
  }

  private describeUpdateAction(previousStatus: string, requestedStatus?: string): string {
    if (requestedStatus !== undefined && requestedStatus !== previousStatus) {
      return requestedStatus === 'suspended' ? 'PublisherSuspended' : 'PublisherReactivated';
    }
    return 'PublisherUpdated';
  }

  private async toDto(publisher: Publisher): Promise<PublisherDto> {
    const profile = await this.profiles.findByPublisherId(publisher.id);
    return {
      id: publisher.id,
      namespace: publisher.namespace,
      publisherType: publisher.publisherType,
      displayName: publisher.displayName,
      legalName: publisher.name,
      description: profile?.description ?? '',
      website: profile?.website ?? '',
      contactEmail: publisher.contactEmail,
      status: publisher.status,
      createdAt: publisher.createdAt.toISOString(),
      updatedAt: publisher.updatedAt.toISOString(),
    };
  }
}
