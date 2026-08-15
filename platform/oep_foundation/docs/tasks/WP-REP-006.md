# WORK PACKAGE

**ID:** WP-REP-006

**Title:** Foundation Repository Runtime Service

**Component:** platform/oep_foundation

**Priority:** Critical

**Status:** Ready

---

# Objective

Implement the Repository Runtime Service (RRS).

The Runtime Service becomes the authoritative execution boundary
for every Repository operation.

Clients no longer manipulate Foundation Runtime objects directly.

Instead they submit Repository Requests.

The Runtime Service coordinates:

• validation

• authorization (future)

• trust

• dependency resolution

• transactions

• registry

• notifications

This establishes the permanent execution architecture of OEP.

---

# Architectural Principles

The Runtime Service MUST NOT implement business logic.

Business logic remains inside existing components:

Trust Engine

Dependency Engine

Transaction Engine

Registry

The Runtime Service orchestrates them.

---

# Architecture

```
Studio

CLI

Acquisition

Exchange

↓

Repository Runtime Service

↓

Trust

↓

Dependency Resolution

↓

Transaction Engine

↓

Repository Registry

↓

Object Store
```

---

# Repository Requests

Create immutable request objects.

Examples

```
InstallPackageRequest

RemovePackageRequest

ResolveDependenciesRequest

VerifyTrustRequest

RepositoryStatusRequest

SearchRequest
```

---

# Repository Responses

Create immutable responses.

```
RepositoryResponse

InstallResponse

DependencyResponse

TrustResponse

StatusResponse
```

Responses include

success

diagnostics

execution time

request id

timestamp

---

# Runtime Context

Introduce RuntimeContext.

Contains

Repository

Trust Store

Transaction Manager

Dependency Resolver

Registry

Configuration

Future extensions

Policy Engine

Permissions

Audit

Telemetry

---

# Request Dispatcher

Single dispatcher

```
dispatch(request)
```

Routes request to correct subsystem.

No client performs orchestration itself.

---

# Pipeline

Install Package

↓

Verify Trust

↓

Resolve Dependencies

↓

Begin Transaction

↓

Install Objects

↓

Update Registry

↓

Commit

↓

Notify

---

# Notifications

Introduce Repository Events

```
PackageInstalled

PackageRemoved

TransactionCommitted

TransactionRolledBack

RepositoryChanged
```

No subscribers yet.

Infrastructure only.

---

# Runtime Status

Provide

Repository health

Trust status

Transaction status

Registry statistics

Installed packages

Repository size

Pending operations

---

# Public Runtime API

Replace direct entry points with service requests.

Keep legacy APIs operational.

Mark deprecated.

---

# C API

Expose Runtime Service.

Increment API version.

Maintain ABI compatibility.

---

# CLI

New command

```
oep runtime status

oep runtime health

oep runtime install

oep runtime remove

oep runtime verify

oep runtime dispatch
```

Existing commands continue working.

---

# Studio

Foundation Bridge updated.

All Repository operations route through Runtime Service.

No direct FoundationRuntime calls.

---

# Tests

Dispatcher

Pipeline

Events

Status

Integration

CLI

Studio

Regression

---

# Documentation

Repository Runtime README

API README

CLI README

Architecture diagrams

TASK.md

CURRENT_SPRINT.md

PROJECT_STATUS.md

---

# Deliverables

Runtime Service

Dispatcher

Request objects

Response objects

Runtime Context

Event framework

Status API

CLI

Studio integration

Tests

Documentation

---

# Exit Criteria

✓ Runtime Service operational

✓ Dispatcher complete

✓ Requests immutable

✓ Responses immutable

✓ Context implemented

✓ Event infrastructure

✓ Status API

✓ CLI updated

✓ Studio migrated

✓ Tests passing

✓ Documentation complete