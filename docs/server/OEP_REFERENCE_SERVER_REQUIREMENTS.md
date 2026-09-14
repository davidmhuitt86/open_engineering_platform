# OEP Reference Server
## Hardware, Software, Installation & Configuration Requirements

**Project:** Open Engineering Platform (OEP)  
**Organization:** Divad Technology Group, LLC  
**Document Type:** Infrastructure Planning / Build Tracking  
**Status:** PLANNING  
**Environment:** Development / Integration / Test  
**Server Role:** OEP Reference Server / Distributed Platform Testbed  

---

# 1. PURPOSE

The OEP Reference Server is intended to provide a real remote-server environment for development and integration testing of the Open Engineering Platform.

The server is not initially intended to be production infrastructure.

Its purpose is to allow OEP development workstations and devices to communicate with real OEP services over a network and validate the complete distributed architecture.

The server should eventually support testing of:

- Engineering Acquisition Manager (EAM)
- Knowledge Engine
- Engineering Object Repository
- Engineering Knowledge persistence
- Provenance
- Engineering Exchange
- Remote search
- Remote object retrieval
- Remote package retrieval
- Synchronization
- Authentication
- Future Studio services
- Future engineering collaboration services

The server should be designed so that it can evolve toward the eventual OEP server architecture without making the OEP client platform dependent upon the testbed's infrastructure.

---

# 2. ARCHITECTURAL INTENT

The initial architecture is:

    OEP DEVELOPMENT WORKSTATIONS
    ├── Windows
    ├── Android
    └── future Linux / macOS clients
                 |
                 | HTTPS / OEP API
                 |
                 v
    +---------------------------------------+
    |          OEP REFERENCE SERVER        |
    |                                       |
    |  Reverse Proxy / TLS                  |
    |                                       |
    |  OEP Services                         |
    |  ├── EAM Acquisition                  |
    |  ├── Knowledge Services               |
    |  ├── Engineering Object Repository    |
    |  ├── Vault                            |
    |  ├── Engineering Exchange             |
    |  └── Future Services                  |
    |                                       |
    |  PostgreSQL                           |
    |                                       |
    |  Persistent Object / Vault Storage    |
    |                                       |
    |  Logs / Backups / Test Data           |
    +------------------+--------------------+
                       |
             +---------+---------+
             |                   |
             v                   v
       PostgreSQL          Object Storage
       / Database          / Vault


The reference server must NOT become a second implementation of OEP.

It should run the actual OEP services and APIs wherever practical.

---

# 3. CLIENT / SERVER DEPLOYMENT MODEL

OEP should eventually support both local and remote operation.

## 3.1 Standalone / Offline

    OEP Client
       |
       +-- Local Repository
       +-- Local Knowledge
       +-- Local Services


## 3.2 Remote

    OEP Client
       |
       | HTTPS
       v
    OEP Server
       |
       +-- Repository
       +-- Knowledge
       +-- EAM
       +-- Exchange


## 3.3 Future Hybrid

    OEP Client
       |
       +-- Local/offline data
       |
       +-- Remote OEP Server
       |
       +-- Synchronization


The server architecture must not eliminate offline/local operation.

---

# 4. INITIAL HARDWARE REQUIREMENTS

## 4.1 Minimum Recommended Test Server

| Component | Requirement |
|---|---|
| CPU | 4 physical cores minimum |
| RAM | 16 GB |
| OS Storage | 256 GB SSD/NVMe |
| Data Storage | 1 TB SSD/NVMe |
| Network | Gigabit Ethernet |
| GPU | Not required |
| UPS | Strongly recommended |

## 4.2 Preferred Development Server

| Component | Recommended |
|---|---|
| CPU | 6–8 cores |
| RAM | 32 GB |
| OS Storage | 500 GB NVMe |
| Data Storage | 2 TB NVMe/SSD |
| Network | 1 GbE minimum |
| Network Upgrade | 2.5 GbE preferred |
| UPS | Recommended |
| ECC RAM | Preferred if practical |

## 4.3 Hardware Notes

The initial server does not require:

- high-end GPU
- Xeon-class CPU
- enterprise RAID
- redundant power supplies
- enterprise networking
- large compute cluster

The initial bottlenecks are expected to be:

1. RAM
2. Database I/O
3. Storage capacity
4. Network reliability

---

# 5. SERVER OPERATING SYSTEM

## 5.1 Recommended OS

**Ubuntu Server 24.04 LTS**

Architecture:

    x86-64 / amd64

The initial server should use the Server edition rather than Ubuntu Desktop.

## 5.2 Initial Server Hostname

Recommended:

    oep-reference-01

Future DNS name may become something such as:

    reference.oep.divadtechnology.com

Actual production naming is deferred.

---

# 6. BASE OPERATING SYSTEM SOFTWARE

Install the following baseline tools:

- OpenSSH Server
- Git
- curl
- wget
- ca-certificates
- unzip
- jq
- htop
- vim or nano
- UFW
- fail2ban

Recommended additional utilities:

- tree
- net-tools
- dnsutils
- lsof
- rsync
- nc / netcat

---

# 7. CONTAINER RUNTIME

## 7.1 Docker

Install:

- Docker Engine
- Docker Compose Plugin

Docker is infrastructure for the reference testbed.

It is NOT an OEP architectural dependency.

Conceptually:

    Docker
    |
    +-- PostgreSQL
    |
    +-- EAM
    |
    +-- Knowledge Services
    |
    +-- Repository
    |
    +-- Future Services


The OEP product must remain capable of native deployment independent of Docker.

## 7.2 Why Docker Is Appropriate Here

Docker provides:

- service isolation
- reproducible test environments
- easy service restart
- controlled dependency versions
- easier environment reset
- easier integration testing
- easier migration to future server infrastructure

---

# 8. DATABASE

## 8.1 PostgreSQL

Target:

    PostgreSQL 18

The development environment already uses PostgreSQL 18.

The server should use the same major version unless architecture review determines otherwise.

## 8.2 Database Separation

Potential logical databases:

    oep_eam
    oep_knowledge
    oep_repository
    oep_exchange

IMPORTANT:

Do NOT create separate databases solely because they appear in this document.

The final database boundary must be determined by the OEP/EAM/Knowledge Engine architecture.

Schemas may be preferable to separate databases.

This is an architectural decision and must be verified before implementation.

---

# 9. PERSISTENT STORAGE ARCHITECTURE

A fundamental distinction must be maintained between:

## 9.1 Structured Database Data

Examples:

- Engineering Objects
- Relationships
- Object metadata
- Acquisition Records
- Provenance
- Object state
- Lifecycle state
- Search indexes
- References
- Service configuration

Likely stored in PostgreSQL.

---

## 9.2 Immutable / Artifact Storage

Examples:

- PDF documents
- technical manuals
- wiring diagrams
- images
- SVG files
- DOCX files
- source engineering documents
- .oerp packages
- future knowledge packages
- other acquired artifacts

Likely stored in a filesystem/object-storage layer.

---

# 10. PROPOSED SERVER STORAGE

Initial conceptual structure:

    /srv/oep/

        vault/
            objects/
            manifests/
            metadata/

        repository/
            objects/
            packages/

        knowledge/
            source/
            derived/
            indexes/

        backups/

        logs/


IMPORTANT:

This is a conceptual structure only.

The authoritative storage model must be established by the EAM + Knowledge Engine architecture audit.

Do not create duplicate storage systems unnecessarily.

---

# 11. REVERSE PROXY / TLS

## 11.1 Recommended Software

Caddy

Conceptual flow:

    Internet / LAN
           |
           v
       HTTPS :443
           |
           v
         Caddy
           |
           +-- /api/eam
           |
           +-- /api/knowledge
           |
           +-- /api/repository
           |
           +-- /api/exchange
           |
           +-- future services


## 11.2 TLS

Development:

- internal HTTPS
- development certificates as necessary

Future:

- publicly trusted TLS certificates
- real DNS
- production certificate management

Never disable TLS verification merely to simplify development.

---

# 12. NETWORKING

## 12.1 Initial Network

The initial server should remain LAN-accessible.

    Development PC
          |
          |
       Ethernet
          |
          v
    OEP Reference Server


Do not expose the server directly to the public Internet during the initial build.

---

# 13. FIREWALL

Initial conceptual firewall policy:

| Port | Purpose | Exposure |
|---:|---|---|
| 22 | SSH | Restricted |
| 80 | HTTP → HTTPS | LAN/public only when required |
| 443 | OEP HTTPS API | LAN initially |
| 5432 | PostgreSQL | NEVER public |
| 9411 | OIP, if required | Determine later |

PostgreSQL should never be exposed directly to the Internet.

---

# 14. DNS

## Initial

Use local hostname resolution:

    oep-reference-01.local

or equivalent internal DNS.

## Future

Potential public hostname:

    api.oep.divadtechnology.com

Actual domain structure is deferred.

---

# 15. SERVER SERVICES

The reference server is expected to eventually contain the following logical services.

## Core

- API gateway / reverse proxy
- Engineering Object Repository
- Persistence
- Knowledge services
- EAM

## Platform

- Engineering Exchange
- Search
- Package services
- Provenance
- Synchronization

## Future

- Identity
- Authentication
- Authorization
- Collaboration
- Notifications
- telemetry/monitoring

Not all services need to exist in the first server build.

---

# 16. EAM SERVER ROLE

The server must eventually allow EAM to operate remotely.

Expected conceptual pipeline:

    Source Document
          |
          v
    Acquisition
          |
          v
    Integrity Verification
          |
          v
    Metadata Extraction
          |
          v
    Immutable Vault
          |
          v
    Knowledge Extraction
          |
          v
    Engineering Objects
          |
          v
    Relationships
          |
          v
    Provenance
          |
          v
    Persistent Repository


The complete pipeline must be proven end-to-end.

---

# 17. KNOWLEDGE ENGINE SERVER ROLE

The Knowledge Engine must eventually be capable of consuming persistent engineering knowledge.

Expected conceptual flow:

    EAM
     |
     v
    Engineering Objects
     |
     v
    Relationships
     |
     v
    Provenance
     |
     v
    Persistent Knowledge
     |
     v
    Knowledge Engine
     |
     v
    OEP Applications


The exact Knowledge Engine/server API must be determined by the Knowledge Engine architecture audit.

---

# 18. ENGINEERING OBJECT PERSISTENCE

The server must eventually prove that Engineering Objects survive:

- service restart
- server restart
- client restart
- network disconnect
- acquisition process termination
- Knowledge Engine restart

The object must not exist solely in memory.

---

# 19. PROVENANCE

Every Engineering Object generated from an acquired source should eventually be traceable back through:

    Engineering Object
          |
          v
    Relationship / Knowledge Record
          |
          v
    Acquisition Record
          |
          v
    Acquisition Job
          |
          v
    Execution
          |
          v
    Download
          |
          v
    Verification
          |
          v
    Source Artifact
          |
          v
    Original Source


The actual implemented provenance model must be verified against the EAM architecture.

---

# 20. REMOTE RETRIEVAL

The reference server must eventually support:

    OEP Client
        |
        | HTTPS
        v
    Remote API
        |
        v
    Repository
        |
        v
    Engineering Object


The client should be able to:

- retrieve an object
- inspect object metadata
- retrieve relationships
- follow provenance
- retrieve source references
- search for objects
- retrieve knowledge
- determine object state

---

# 21. REMOTE EAM TEST

The server should eventually support:

    OEP Client
       |
       v
    Remote EAM
       |
       v
    Acquire Source
       |
       v
    Persist Artifact
       |
       v
    Extract Data
       |
       v
    Create Objects
       |
       v
    Persist Objects
       |
       v
    Client Retrieves Objects


The complete operation must work without the client and server sharing
the same local filesystem.

This is an important architectural acceptance criterion.

---

# 22. END-TO-END TEST DOCUMENT

At least one real engineering document should be used for the complete
vertical test.

Required sequence:

1. Acquire document.
2. Verify integrity.
3. Persist immutable source.
4. Extract metadata.
5. Create Acquisition Record.
6. Extract engineering information.
7. Create Engineering Objects.
8. Create Relationships.
9. Preserve provenance.
10. Persist all permanent state.
11. Restart services.
12. Retrieve objects remotely.
13. Retrieve knowledge through Knowledge Engine.
14. Verify relationships.
15. Verify provenance.
16. Locate original source artifact.
17. Verify hashes/identifiers where applicable.
18. Verify no required data existed only in RAM.

---

# 23. FAILURE TESTING

The reference server must eventually test:

## Acquisition failure

What happens if acquisition fails halfway through?

## Extraction failure

What happens if document extraction fails?

## Partial extraction

What happens when only part of a document is successfully processed?

## Duplicate acquisition

What happens when the same document is acquired twice?

## Revision

What happens when an updated document is acquired?

## Object correction

What happens when an Engineering Object is later corrected?

## Service failure

What happens if EAM stops during acquisition?

## Database failure

What happens if PostgreSQL becomes unavailable?

## Network failure

What happens if the client disconnects during an operation?

## Storage failure

What happens if artifact storage becomes unavailable?

---

# 24. AUTHENTICATION

Authentication should NOT be the first server implementation unless the
architecture audit identifies it as an immediate requirement.

The server should, however, be designed so authentication can be added
without redesigning the service architecture.

Future conceptual architecture:

    OEP Client
        |
        | Credential / Token
        v
    API Gateway
        |
        +-- EAM
        +-- Knowledge
        +-- Repository
        +-- Exchange


Development mode may initially use a controlled local configuration.

Production authentication must be addressed before Internet deployment.

---

# 25. AUTHORIZATION

Eventually distinguish:

- anonymous access
- authenticated user
- engineer
- publisher
- administrator
- service account
- system process

Authorization is deferred until the service boundary is established.

---

# 26. LOGGING

Minimum server logging:

- service startup
- service shutdown
- errors
- warnings
- acquisition execution
- artifact verification
- object creation
- repository operations
- API errors
- authentication events once authentication exists

Avoid logging:

- passwords
- private keys
- authentication tokens
- sensitive credentials

---

# 27. HEALTH CHECKS

Every service should eventually expose a health endpoint.

Example:

    GET /health

Possible future:

    GET /ready
    GET /live


Health states should distinguish:

- process alive
- service ready
- database available
- storage available
- dependent services available

---

# 28. BACKUPS

Backups must exist before the server becomes a repository for
important engineering data.

Minimum:

## PostgreSQL

Scheduled database backup.

## Vault / Object Storage

Scheduled artifact backup.

## Configuration

Backup:

- service configuration
- deployment configuration
- certificates where appropriate
- server configuration
- migration state

---

# 29. BACKUP ARCHITECTURE

Initial conceptual design:

    OEP Reference Server
          |
          +-- PostgreSQL
          |
          +-- Vault
          |
          +-- Configuration
                    |
                    v
               Backup Storage


Do not allow the reference server to become the only copy of important
engineering artifacts.

---

# 30. MONITORING

Initial monitoring should remain lightweight.

Required:

- CPU
- RAM
- disk usage
- disk health where available
- network connectivity
- PostgreSQL status
- service status
- API health
- logs

Potential future tools:

- Prometheus
- Grafana

These are NOT required for the first build.

---

# 31. SOFTWARE NOT REQUIRED INITIALLY

Do not install these merely because they might eventually be useful:

- Kubernetes
- Redis
- Kafka
- Elasticsearch
- RabbitMQ
- MinIO
- Keycloak
- Terraform
- Ansible
- Prometheus
- Grafana

Each should be introduced only when the OEP architecture demonstrates a
real requirement.

---

# 32. SERVER SOFTWARE CHECKLIST

## Operating System

- [ ] Ubuntu Server 24.04 LTS
- [ ] Hostname configured
- [ ] Static/reserved IP configured
- [ ] Time synchronization verified
- [ ] System updated

## Remote Administration

- [ ] OpenSSH installed
- [ ] SSH key authentication configured
- [ ] Password SSH disabled when appropriate
- [ ] SSH access restricted

## Base Tools

- [ ] Git
- [ ] curl
- [ ] wget
- [ ] jq
- [ ] unzip
- [ ] htop
- [ ] vim/nano
- [ ] tree
- [ ] rsync
- [ ] dnsutils
- [ ] net-tools

## Security

- [ ] UFW
- [ ] fail2ban
- [ ] Firewall rules
- [ ] SSH restrictions
- [ ] Automatic security updates evaluated
- [ ] No public PostgreSQL access

## Container Runtime

- [ ] Docker Engine
- [ ] Docker Compose
- [ ] Docker daemon verified
- [ ] Container networking verified
- [ ] Persistent volumes verified

## Database

- [ ] PostgreSQL version selected
- [ ] PostgreSQL installed/deployed
- [ ] Database architecture approved
- [ ] Roles created
- [ ] Permissions configured
- [ ] Migrations tested
- [ ] Backup tested

## Reverse Proxy

- [ ] Caddy installed
- [ ] HTTP routing tested
- [ ] HTTPS configured
- [ ] Certificate handling verified
- [ ] Service routing verified

## Storage

- [ ] OS storage
- [ ] Persistent data storage
- [ ] Vault storage
- [ ] Repository storage
- [ ] Backup storage
- [ ] Storage permissions
- [ ] Storage monitoring

## OEP

- [ ] OEP server architecture approved
- [ ] EAM deployed
- [ ] Knowledge services deployed
- [ ] Repository deployed
- [ ] Exchange deployed if required
- [ ] APIs reachable
- [ ] Health endpoints verified

---

# 33. SERVER CONFIGURATION CHECKLIST

## Identity

- [ ] Hostname
- [ ] DNS
- [ ] Static/reserved IP
- [ ] Timezone
- [ ] NTP/time synchronization

## Network

- [ ] LAN IP
- [ ] Gateway
- [ ] DNS
- [ ] Firewall
- [ ] HTTPS
- [ ] Internal hostname

## Storage

- [ ] Mount points
- [ ] Ownership
- [ ] Permissions
- [ ] Capacity monitoring
- [ ] Backup target

## Database

- [ ] PostgreSQL
- [ ] Database
- [ ] Roles
- [ ] Permissions
- [ ] Migrations
- [ ] Backup

## Services

- [ ] Service configuration
- [ ] Environment variables
- [ ] Persistent volumes
- [ ] Health checks
- [ ] Restart policies

---

# 34. DEVELOPMENT / TESTING MODES

The server should eventually support clearly separated environments.

## Development

    oep-reference-dev

## Integration

    oep-reference-int

## Test

    oep-reference-test

The first physical server may host these as isolated environments if
resources permit.

Do not allow test data to accidentally become authoritative production
data.

---

# 35. DATA RESET

A major requirement for the testbed is the ability to reset it.

We should eventually be able to:

    RESET TEST ENVIRONMENT

and reliably:

- remove test database state
- remove test objects
- remove test vault artifacts
- reset test packages
- preserve server configuration
- recreate migrations
- reseed reference data

This will be essential for deterministic end-to-end testing.

---

# 36. SERVER DEPLOYMENT PRINCIPLES

1. OEP services should remain independently deployable.

2. Docker is infrastructure, not an OEP architectural dependency.

3. PostgreSQL is a persistence dependency where the architecture
   requires it.

4. Artifact storage must be separated conceptually from relational
   database state.

5. Persistent engineering information must not depend on process memory.

6. Provenance must survive service restart.

7. Remote clients must not require access to the server's local
   filesystem.

8. APIs must be the boundary between clients and server services.

9. Security restrictions must be enforced rather than documented only.

10. Local/offline OEP operation must remain possible.

---

# 37. FUTURE PRODUCTION EVOLUTION

The reference server should be capable of evolving toward:

    Internet
       |
    Firewall
       |
    TLS
       |
    Load Balancer / Reverse Proxy
       |
    +----------------------------+
    | OEP Service Layer          |
    |                            |
    | EAM                        |
    | Knowledge                  |
    | Repository                 |
    | Exchange                   |
    | Search                     |
    | Synchronization            |
    +----------------------------+
       |
    +----------------------------+
    | Persistence                |
    |                            |
    | PostgreSQL                 |
    | Object Storage             |
    | Backup                     |
    +----------------------------+


Future production infrastructure may introduce:

- multiple application servers
- managed PostgreSQL
- object storage
- centralized authentication
- monitoring
- load balancing
- redundancy
- disaster recovery
- automated deployment
- geographic redundancy

None of these are required for the initial reference server.

---

# 38. CURRENT INSTALLATION ORDER

Recommended installation order:

### Phase 1 — Hardware

1. [ ] Prepare physical machine
2. [ ] Verify RAM
3. [ ] Verify storage
4. [ ] Verify Ethernet
5. [ ] Connect UPS

### Phase 2 — Operating System

6. [ ] Install Ubuntu Server 24.04 LTS
7. [ ] Configure hostname
8. [ ] Configure network
9. [ ] Configure SSH
10. [ ] Update OS

### Phase 3 — Base Security

11. [ ] Configure UFW
12. [ ] Restrict SSH
13. [ ] Configure fail2ban
14. [ ] Verify exposed ports

### Phase 4 — Base Software

15. [ ] Git
16. [ ] curl
17. [ ] wget
18. [ ] jq
19. [ ] unzip
20. [ ] diagnostic utilities

### Phase 5 — Container Infrastructure

21. [ ] Install Docker Engine
22. [ ] Install Docker Compose
23. [ ] Verify container execution
24. [ ] Verify persistent volumes

### Phase 6 — Architecture Review

25. [ ] Complete EAM architecture audit
26. [ ] Complete Knowledge Engine audit
27. [ ] Define object persistence
28. [ ] Define artifact storage
29. [ ] Define service boundaries
30. [ ] Define API boundaries

### Phase 7 — Data Infrastructure

31. [ ] Deploy PostgreSQL
32. [ ] Configure database
33. [ ] Apply migrations
34. [ ] Deploy persistent storage
35. [ ] Test backup

### Phase 8 — Networking

36. [ ] Install Caddy
37. [ ] Configure internal HTTPS
38. [ ] Configure service routing
39. [ ] Verify remote client access

### Phase 9 — OEP

40. [ ] Deploy EAM
41. [ ] Deploy Knowledge services
42. [ ] Deploy Repository
43. [ ] Deploy Exchange where required
44. [ ] Verify health endpoints

### Phase 10 — End-to-End

45. [ ] Acquire real engineering document
46. [ ] Verify artifact
47. [ ] Extract metadata
48. [ ] Create Acquisition Record
49. [ ] Extract engineering information
50. [ ] Create Engineering Objects
51. [ ] Create Relationships
52. [ ] Verify provenance
53. [ ] Restart services
54. [ ] Retrieve objects remotely
55. [ ] Verify Knowledge Engine access
56. [ ] Verify source artifact
57. [ ] Verify persistence

---

# 39. INITIAL SOFTWARE INVENTORY

| Software | Purpose | Priority | Status |
|---|---|---:|---|
| Ubuntu Server 24.04 LTS | Operating system | P0 | NOT INSTALLED |
| OpenSSH | Remote administration | P0 | NOT INSTALLED |
| Git | Deployment/configuration | P0 | NOT INSTALLED |
| curl | HTTP diagnostics | P0 | NOT INSTALLED |
| wget | Download/diagnostics | P1 | NOT INSTALLED |
| jq | JSON diagnostics | P1 | NOT INSTALLED |
| unzip | Artifact handling | P1 | NOT INSTALLED |
| htop | System diagnostics | P1 | NOT INSTALLED |
| UFW | Firewall | P0 | NOT INSTALLED |
| fail2ban | SSH/service protection | P1 | NOT INSTALLED |
| Docker Engine | Testbed runtime | P0 | NOT INSTALLED |
| Docker Compose | Multi-service orchestration | P0 | NOT INSTALLED |
| PostgreSQL 18 | Structured persistence | P0 | ARCHITECTURE PENDING |
| Caddy | Reverse proxy/TLS | P1 | ARCHITECTURE PENDING |
| Prometheus | Monitoring | P2 | DEFERRED |
| Grafana | Monitoring UI | P2 | DEFERRED |
| Kubernetes | Orchestration | P3 | NOT REQUIRED |
| Redis | Cache | P3 | NOT REQUIRED |
| Kafka | Messaging | P3 | NOT REQUIRED |
| Elasticsearch | Search | P3 | NOT REQUIRED |
| RabbitMQ | Messaging | P3 | NOT REQUIRED |
| Keycloak | Identity | P3 | FUTURE |

---

# 40. OPEN ARCHITECTURAL QUESTIONS

These must be answered before the reference server is considered
architecturally complete.

- [ ] What is the authoritative OEP server API?
- [ ] What is the authoritative Engineering Object persistence model?
- [ ] What is the authoritative Knowledge Engine server interface?
- [ ] Where does extracted engineering knowledge live?
- [ ] Where does the immutable source artifact live?
- [ ] How is provenance represented?
- [ ] How are object revisions represented?
- [ ] How are duplicate sources handled?
- [ ] How are updated sources handled?
- [ ] How does Knowledge Engine consume EAM output?
- [ ] Which services require remote access?
- [ ] Which services can remain local?
- [ ] What requires authentication?
- [ ] What requires authorization?
- [ ] What APIs are public?
- [ ] What APIs are internal?
- [ ] What data is cacheable?
- [ ] What data is immutable?
- [ ] What data can be regenerated?
- [ ] What data must be backed up?
- [ ] What is the synchronization model?
- [ ] What is the offline model?

---

# 41. REFERENCE SERVER ACCEPTANCE CRITERIA

The OEP Reference Server should eventually be considered operational
when all of the following are demonstrated:

### Infrastructure

- [ ] Server boots reliably
- [ ] Services restart automatically
- [ ] Persistent storage survives reboot
- [ ] Database survives reboot
- [ ] Firewall is verified
- [ ] HTTPS works

### Remote Access

- [ ] Windows Studio connects remotely
- [ ] Android client connects remotely
- [ ] API health endpoint works
- [ ] Client does not require server filesystem access

### EAM

- [ ] Remote acquisition works
- [ ] Source artifact persists
- [ ] Integrity verification works
- [ ] Metadata persists
- [ ] Acquisition Record persists
- [ ] Provenance persists

### Knowledge

- [ ] Extracted engineering data persists
- [ ] Engineering Objects persist
- [ ] Relationships persist
- [ ] Knowledge Engine can access persisted data
- [ ] Knowledge survives service restart

### Repository

- [ ] Objects can be retrieved remotely
- [ ] Relationships can be followed
- [ ] Provenance can be followed
- [ ] Source artifact can be located

### Recovery

- [ ] Services can be restarted
- [ ] Database can be restored
- [ ] Artifact storage can be restored
- [ ] Test environment can be reset

### End-to-End

- [ ] Real engineering document acquired
- [ ] Data extracted
- [ ] Engineering Objects created
- [ ] Relationships created
- [ ] Provenance preserved
- [ ] Data persisted
- [ ] Server restarted
- [ ] Client reconnects
- [ ] Objects retrieved
- [ ] Knowledge Engine retrieves/uses data

---

# 42. IMPORTANT ARCHITECTURAL PRINCIPLE

The Reference Server is not merely an EAM server.

It is the first practical test environment for the distributed OEP
platform.

The long-term model is:

    OEP CLIENTS
       |
       | OEP APIs / Protocols
       v
    OEP SERVER PLATFORM
       |
       +-- Engineering Knowledge
       +-- Engineering Objects
       +-- EAM
       +-- Repository
       +-- Exchange
       +-- Search
       +-- Provenance
       +-- Synchronization
       |
       v
    PERMANENT ENGINEERING DATA


The server therefore needs to be designed around the OEP platform
architecture rather than around one application.

---

# 43. BUILD LOG

## Hardware

Date:
Machine:
CPU:
RAM:
OS Disk:
Data Disk:
Network:
UPS:

## Operating System

Installation Date:
Ubuntu Version:
Hostname:
IP Address:

## Software

Docker:
Docker Compose:
PostgreSQL:
Caddy:

## OEP Services

EAM:
Knowledge:
Repository:
Exchange:

## Validation

Local API:
Remote API:
Database:
Vault:
EAM:
Knowledge:
Repository:
End-to-End:

## Notes

---

# 44. CHANGE LOG

| Date | Change | Author |
|---|---|---|
| 2026-09-13 | Initial Reference Server requirements document | Divad Technology Group |

---

# 45. DOCUMENT STATUS

Current status:

**PLANNING / PRE-BUILD**

This document is a living infrastructure planning document.

The actual OEP server architecture must be reconciled against:

- OEP Constitution
- EAM architecture
- Knowledge Engine architecture
- Engineering Object Model
- Repository architecture
- Engineering Exchange architecture
- applicable ADRs
- security architecture
- deployment architecture

No server implementation should override those architectural authorities.