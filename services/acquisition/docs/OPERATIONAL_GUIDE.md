# Save Location

```text
oep_acquisition/
└── docs/
    └── OPERATIONAL_GUIDE.md
```

---

# Document

# Engineering Acquisition Management (EAM)

## Operational Guide

**Document Status:** Ratified

**Version:** 1.0.0-M1

**Applies To:** `oep_acquisition`

---

# Purpose

This document defines the operational procedures for deploying, configuring, maintaining, monitoring, and troubleshooting the Engineering Acquisition Management (EAM) subsystem.

This guide is intended for system administrators, DevOps engineers, platform operators, and engineering support personnel responsible for operating Engineering Acquisition in production.

It is not intended to describe software architecture or implementation details. Those are documented elsewhere.

---

# Operational Responsibilities

The Engineering Acquisition subsystem is responsible for:

- Managing Official Sources
- Executing Acquisition Jobs
- Downloading engineering artifacts
- Verifying artifact integrity
- Extracting descriptive metadata
- Publishing trusted artifacts into the Engineering Reference Vault

Platform responsibilities such as authentication, authorization, user management, monitoring infrastructure, and backups remain outside the scope of EAM.

---

# Runtime Components

A standard deployment consists of the following components.

```text
                Open Engineering Platform
                         │
                         ▼
                Engineering Acquisition
                         │
         ┌───────────────┼────────────────┐
         │               │                │
         ▼               ▼                ▼
 PostgreSQL       Workspace Storage   Reference Vault
 Database         (Temporary)         (Permanent)
```

---

# Required Services

The following services must be available before Engineering Acquisition starts.

## PostgreSQL

Purpose:

Persistent system database.

Stores:

- Sources
- Jobs
- Download Sessions
- Verifications
- Metadata
- Vault Entries

---

## Workspace Storage

Purpose:

Temporary processing area.

Stores:

- Downloaded artifacts
- Temporary files

Characteristics:

- Writable
- Replaceable
- Non-authoritative

---

## Reference Vault Storage

Purpose:

Permanent engineering archive.

Stores:

Trusted engineering artifacts only.

Characteristics:

- Persistent
- Immutable
- Content-addressable

---

# Startup Sequence

Engineering Acquisition shall initialize components in the following order.

```text
Load Configuration

↓

Initialize Logging

↓

Connect Database

↓

Run Flyway Migrations

↓

Validate Workspace

↓

Validate Reference Vault

↓

Initialize Connectors

↓

Start REST API

↓

Accept Requests
```

If any required component fails initialization, startup shall terminate.

---

# Configuration

Engineering Acquisition is configured using application configuration files and environment-specific settings.

Typical configuration categories include:

```text
Database

Logging

Workspace

Reference Vault

REST Server

Connector Configuration
```

Secrets such as credentials or API keys shall never be committed to source control.

---

# Storage Layout

## Workspace

Example:

```text
workspace/

downloads/

temporary/

processing/
```

Workspace contents are temporary.

Operators may remove obsolete workspace files after confirming successful publication into the Reference Vault.

---

## Reference Vault

Example:

```text
reference_vault/

3f/
    3f8b0d8...

81/
    81a672...

d1/
    d1982...
```

The Reference Vault is authoritative.

Operators shall never rename or reorganize Vault contents manually.

---

# Database Operations

## Migrations

Schema changes shall be applied exclusively through Flyway.

Manual schema modification is prohibited.

Migration order must remain sequential.

---

## Backups

The PostgreSQL database shall be backed up according to organizational policy.

Recommended backup schedule:

- Daily incremental backups
- Weekly full backups

Database backups and Reference Vault backups shall be coordinated to preserve consistency.

---

# Reference Vault Backups

The Reference Vault contains permanent engineering artifacts.

It shall be included in regular backup procedures.

Recommended characteristics:

- Immutable backup storage
- Versioned backups
- Off-site replication
- Periodic restoration testing

Loss of the Reference Vault may result in permanent loss of engineering artifacts.

---

# Logging

Engineering Acquisition shall produce structured logs for:

- Startup
- Shutdown
- Source registration
- Job execution
- Downloads
- Verification
- Metadata extraction
- Vault publication
- Errors

Sensitive information shall never appear in logs.

---

# Monitoring

Operators should monitor:

- Database connectivity
- Disk utilization
- Workspace utilization
- Reference Vault capacity
- REST API availability
- Connector health
- Migration status

Long-term metrics are managed by the platform monitoring infrastructure.

---

# Health Checks

Operational health should verify:

- Database reachable
- Workspace writable
- Vault writable
- REST server operational
- Connector registry initialized

Health checks should complete quickly and avoid expensive operations.

---

# Capacity Planning

Primary storage growth occurs in the Reference Vault.

Operators should monitor:

- Available storage
- Artifact growth rate
- Backup growth
- Database size

Workspace storage requirements are typically much smaller because artifacts are temporary.

---

# Failure Recovery

## Database Failure

Symptoms:

- Startup failure
- REST API unavailable
- Persistence failures

Recovery:

- Restore database service
- Verify migrations
- Restart Engineering Acquisition

---

## Workspace Failure

Symptoms:

- Download failures
- Processing failures

Recovery:

- Restore writable workspace
- Verify permissions
- Retry acquisition

Workspace contents are temporary and may be regenerated.

---

## Reference Vault Failure

Symptoms:

- Publication failures
- Vault unavailable

Recovery:

- Restore storage
- Verify filesystem integrity
- Verify backup consistency
- Resume publication

Published artifacts shall never be manually recreated outside the Engineering Acquisition pipeline.

---

## Connector Failure

Symptoms:

- Download failures
- Authentication failures
- Remote communication errors

Recovery:

- Verify connector configuration
- Verify credentials
- Verify external service availability
- Retry acquisition

---

# Routine Maintenance

Regular operational activities include:

- Apply approved migrations
- Verify backups
- Monitor storage growth
- Remove obsolete workspace files
- Review logs
- Verify connector configuration
- Monitor REST service availability

The Reference Vault requires minimal maintenance beyond storage management and backups.

---

# Security Considerations

Operators shall ensure:

- Database credentials remain protected
- Connector credentials remain protected
- Vault access is restricted
- Workspace permissions are appropriate
- Backup media is secured
- TLS is enabled where applicable

Engineering artifacts may contain proprietary information and shall be protected accordingly.

---

# Operational Boundaries

Operators shall not:

- Modify Verification records
- Modify Metadata records
- Modify Vault Entries
- Rename Vault artifacts
- Edit database tables directly
- Bypass the acquisition pipeline

Operational intervention shall preserve architectural integrity.

---

# Disaster Recovery

Minimum recovery objectives:

1. Restore PostgreSQL database.
2. Restore Reference Vault.
3. Restore configuration.
4. Verify migrations.
5. Start Engineering Acquisition.
6. Execute health checks.
7. Validate acquisition pipeline.

After recovery, perform an end-to-end acquisition test before returning the system to production.

---

# Operational Checklist

## Daily

- Review service health
- Review logs
- Verify backups completed
- Monitor storage utilization

---

## Weekly

- Review connector health
- Review database growth
- Verify backup integrity
- Remove obsolete workspace artifacts

---

## Monthly

- Test restoration procedures
- Validate Reference Vault integrity
- Review operational metrics
- Review configuration changes

---

# Operational Invariants

The following operational rules shall always remain true:

- The Reference Vault is the authoritative source of engineering artifacts.
- Workspace storage is temporary.
- Database changes occur only through Flyway migrations.
- Published artifacts remain immutable.
- Pipeline stages are never bypassed.
- Historical records are preserved.
- Operators do not modify engineering evidence.

---

# Milestone 1 Operational Statement

Engineering Acquisition Version 1.0.0-M1 is designed for deterministic, production-grade operation.

Routine operation consists primarily of monitoring service health, maintaining database and storage infrastructure, protecting the Reference Vault, and ensuring the continued integrity of the acquisition pipeline.

The operational procedures defined by this document establish the baseline practices for all future Engineering Acquisition deployments.