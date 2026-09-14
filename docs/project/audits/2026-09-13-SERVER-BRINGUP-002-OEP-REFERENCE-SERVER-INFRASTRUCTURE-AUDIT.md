# SERVER-BRINGUP-002 — OEP Reference Server Infrastructure Bring-Up Audit — 2026-09-13

Infrastructure evidence for WP-SRV-001A. Companion to [`2026-09-13-SERVER-BRINGUP-001-OEP-REFERENCE-SERVER-ENVIRONMENT-AUDIT.md`](2026-09-13-SERVER-BRINGUP-001-OEP-REFERENCE-SERVER-ENVIRONMENT-AUDIT.md) (the pre-change, read-only environment audit) and [`ADR-0001-OEP-REFERENCE-SERVER-BOUNDARY-AND-ARTIFACT-CONTRACT.md`](../../architecture/decisions/ADR-0001-OEP-REFERENCE-SERVER-BOUNDARY-AND-ARTIFACT-CONTRACT.md).

**This WP performed infrastructure preparation only. No OEP application service was implemented or deployed. No EAM change was made. `GET /vault/{id}/artifact` was not implemented. No OEP application source code was modified. `docs/server/OEP_REFERENCE_SERVER_REQUIREMENTS.md` was not modified.**

---

## 1. Scope

Prepare the previously-provisioned Ubuntu VM (classified NOT READY FOR OEP DEPLOYMENT by SERVER-BRINGUP-001) as controlled development/test infrastructure: network review, SSH hardening, firewall baseline, Docker, PostgreSQL, development toolchain, reverse-proxy decision, repository clone, directory layout, and a non-destructive security review — all infrastructure, none of it application deployment.

## 2. Baseline

As recorded by SERVER-BRINGUP-001 (2026-09-13): Ubuntu 26.04.1 LTS VirtualBox guest, 4 vCPU, ~7.4 GiB RAM, ~94 GiB free root filesystem, NAT-only networking (VM `10.0.2.15`, host SSH forward `2222`→`22`), UFW inactive, SSH password+pubkey auth enabled, fail2ban active, PerSourcePenalties active, Docker/PostgreSQL absent, only `git`/`gcc`/`g++`/`python3` present, no reverse proxy, no OEP repository, no OEP services running.

A Phase 0 snapshot matching this baseline was captured before any change was made (hostname, OS/kernel/arch, CPU/RAM/disk, network interfaces/routes/DNS, listening ports, firewall, SSH effective config, Docker/PostgreSQL absence, toolchain versions, time sync) — no secrets were captured or printed.

## 3. Changes Performed

1. **SSH policy hardened**: added `/etc/ssh/sshd_config.d/99-oep-hardening.conf` setting `PermitRootLogin no` and `PasswordAuthentication no`. Validated with `sshd -t` before reload, reloaded (`systemctl reload ssh`, not restarted), and key-based login was independently re-verified — both the administrator's own personal key and a dedicated automation key — *before* and *after* the change, at every step. Password authentication was only disabled after both key-based paths were confirmed working post-reload.
2. **Firewall enabled**: `ufw` default-deny-incoming / default-allow-outgoing, with an explicit allow rule for `22/tcp` (IPv4 and IPv6) added *before* enabling, then enabled. SSH connectivity was verified immediately after enabling.
3. **Removed a corrupt, pre-existing file**: `/etc/apt/sources.list.d/docker.sources` contained garbled, invalid APT source syntax (leftover from an earlier terminal session, not something this WP or its predecessor created) and was blocking all `apt` operations, not just Docker's. It was removed and `apt-get update` confirmed clean immediately after.
4. **Docker installed** via Docker's official convenience script (`get.docker.com`, contents inspected before execution) — Docker Engine, CLI, Buildx, and the Compose plugin. The existing `oep` user was added to the `docker` group (no new user created). Daemon left on its default Unix-socket-only configuration (no `daemon.json` created, no TCP listener).
5. **PostgreSQL installed** via the standard Ubuntu `postgresql`/`postgresql-contrib` packages. No database, role, or schema was created beyond the package's own defaults (`postgres`/`template0`/`template1`, `postgres` superuser role). Left on its default `listen_addresses = localhost` configuration.
6. **Toolchain installed**: `cmake`, `ninja-build`, `python3-pip` via `apt`. Node.js 20.x installed via the official NodeSource setup script (contents inspected before execution) — justified by `services/exchange/package.json`, which defines a Fastify/TypeScript service with `build`/`start`/`test` npm scripts and an explicit `"engines": {"node": ">=20"}` constraint. Dart/Flutter were deliberately **not** installed — no `services/` component references them; they are exclusively part of the Studio client, which is out of scope for a reference server.
7. **No reverse proxy installed** — `ADR-0001` was searched for any mention of a reverse proxy/TLS/nginx/caddy/traefik requirement at this stage and none was found. Posture left as direct development HTTP endpoint, per the WP's own stated preference in the absence of an explicit requirement.
8. **Repository cloned** to `/opt/oep/open_engineering_platform` (owned `oep:oep`), `main` branch, confirmed clean.
9. **Directory layout created** under `/opt/oep/`: `config/`, `logs/`, `data/`, `artifacts/`, `backups/` (each `750`, `oep:oep`), alongside the repository clone. All created empty — no Vault, Reference Library, or Exchange data was copied or fabricated into any of them.
10. **Sudoers change** (performed by the VM owner, at my request, in their own session — not by me): `/etc/sudoers.d/oep-nopasswd` granting the `oep` user passwordless `sudo`, to allow the many infrastructure commands in this WP to run non-interactively. Validated with `visudo -c` before use.

## 4. Final OS State

Ubuntu 26.04.1 LTS, kernel `7.0.0-31-generic`, `x86_64`, hostname `oepstudioserver` — unchanged from baseline.

## 5. Hardware

4 vCPU (Intel Core i7-7700HQ), 7.4 GiB RAM, 0 swap — unchanged from baseline.

## 6. Network

Still single-NIC, NAT-only: `enp0s3` at `10.0.2.15/24`, gateway `10.0.2.2`. **A second, LAN-accessible NIC was not added** — this VirtualBox guest currently has only one virtual adapter, and adding a second requires changing the VM's own settings in the VirtualBox Manager (host-side), which is outside what a guest-OS SSH session can do. Per this WP's own instruction ("if adding/configuring a second adapter requires action outside the guest OS that Claude cannot safely perform, report the condition instead of attempting to bypass it"), this is reported as an open condition, not worked around. DNS resolution and outbound internet access were both confirmed working (`github.com` resolved and reachable over HTTPS).

## 7. Firewall

`ufw` is now **active**. Default policy: deny incoming, allow outgoing, deny routed. Only rule: `22/tcp` (IPv4 and IPv6) allowed from anywhere. No PostgreSQL, Docker, or any other port is opened. SSH connectivity was verified working immediately after enabling the firewall.

## 8. SSH

Effective config now: `permitrootlogin no`, `pubkeyauthentication yes`, `passwordauthentication no`. Both the administrator's personal key and a dedicated automation key (`oep-audit-automation`, generated solely to allow this WP's own commands to run non-interactively without ever handling the VM's password) are present in `/home/oep/.ssh/authorized_keys`, correctly permissioned (`700`/`600`), with clean Unix line endings. Key-based access was independently verified for both keys, before and after every SSH-affecting change. Password authentication is now cleanly rejected. `fail2ban` is active but currently has **zero jails configured** — it is running but not actually protecting anything yet; enabling an actual jail policy (e.g. the `sshd` jail) was not done, since this WP did not ask for a specific jail configuration and inventing one would be a policy decision beyond its scope. Flagged as a condition.

## 9. Docker

Docker Engine 29.8.0, Docker Compose v5.5.1, `docker.service` active. Daemon socket is Unix-only (`ListenStream=/run/docker.sock`); no `daemon.json` override and no TCP listener exist — the daemon is not reachable over the network at all. `oep` is in the `docker` group (group membership takes effect on `oep`'s next login/session). No container was created or run.

## 10. PostgreSQL

PostgreSQL 18.6, `postgresql.service` active, cluster `main` online on port `5432`. `listen_addresses = localhost` — confirmed bound only to `127.0.0.1`, not reachable from the VM's own network interface, let alone the LAN (and the firewall would block it regardless, as a second layer). Only the default `postgres`/`template0`/`template1` databases and the default `postgres` superuser role exist — no OEP database, role, or schema was created. No password was created, changed, or printed by this WP.

## 11. Toolchain

`git 2.53.0`, `gcc`/`g++` 15.2.0, `python3 3.14.4`/`pip 25.1.1`, `cmake 4.2.3`, `ninja 1.13.2`, `make 4.4.1` (pre-existing), `node v20.20.2`, `npm 10.8.2`. Dart/Flutter: **not installed — not required for the Reference Server** (verified by searching `services/` for any Dart/Flutter dependency; none exists — that toolchain belongs exclusively to the Studio client).

## 12. Reverse Proxy

Not installed. ADR-0001 does not require one at this stage; the development posture is a direct HTTP endpoint, to be revisited once an actual external API boundary is established (a future WP's decision, not invented here).

## 13. OEP Repository

Cloned to `/opt/oep/open_engineering_platform`, owned `oep:oep`. Branch `main`. **HEAD = `a93192d88b75c7564ad6f465ec6d6bc7ad8db115` — matches the authoritative baseline exactly.** Working tree clean (`git status --porcelain` empty). Remote `origin` confirmed as `https://github.com/davidmhuitt86/open_engineering_platform.git`.

## 14. Storage

Root filesystem unchanged in shape from baseline (103G total, still ample headroom after all installs). New directory layout under `/opt/oep/`: `open_engineering_platform/` (repo clone), `config/`, `logs/`, `data/`, `artifacts/`, `backups/` — each empty, `750`, `oep:oep`, clearly separated by purpose. No Vault, Reference Library, or Exchange data exists anywhere on this host.

## 15. Security Posture

Firewall active (deny-by-default, SSH-only allow rule). SSH hardened (no root login, no password auth, key-only). PostgreSQL and Docker both confirmed not exposed beyond localhost/Unix-socket. `fail2ban` running but unconfigured (zero jails — a condition, not a blocker). No credential, `.env`, or secret-like file was found in the cloned repository (searched non-destructively, no content printed). No password was ever created, typed by this agent, or printed in any output.

## 16. Listening Ports

Only `22/tcp` (SSH, both `0.0.0.0` and `[::]`) and `5432/tcp` bound strictly to `127.0.0.1` (PostgreSQL, additionally firewalled). Plus the stock `systemd-resolved` DNS stub listeners (`127.0.0.53`/`127.0.0.54`, loopback-only) and a DHCP client socket. No public-facing application port exists — nothing OEP-related is listening anywhere.

## 17. Validation Results

All Phase 11 checks passed: OS/network operational, DNS and outbound internet operational, SSH administrative access operational (key-based, verified independently for two separate keys), firewall operational (verified non-disruptive), Docker operational (`docker info`, `docker compose version`), PostgreSQL operational locally (`SELECT version()` via the trusted local Unix-socket path), development toolchain operational (all versions captured above), Git operational, repository present with the correct HEAD and a clean working tree, and no unintended OEP service or unintended public listening port exists.

## 18. Remaining Blockers

- No second, LAN-accessible network adapter exists — this must be added at the VirtualBox host level (outside guest-OS reach) before this VM can be reached from anything other than its own hypervisor host.
- `fail2ban` has no jails configured — running but not actually enforcing anything.
- `PermitRootLogin`/`PasswordAuthentication` posture is now hardened, but the credential-exposure and EAM-API-authentication items tracked in `OEP_PROJECT_STATUS.md` Section 16 remain entirely unrelated, unresolved project-level gaps — this infrastructure bring-up does not touch them.

## 19. Conditions

- The passwordless-sudo grant (`/etc/sudoers.d/oep-nopasswd`) that enabled this WP to run efficiently is still in place. It was necessary to complete this WP's many privileged steps without repeatedly handling the VM's password; whether to keep, narrow, or remove it going forward is the VM owner's own call, not decided here.
- The `docker` group membership added for `oep` takes effect on next login/new session, not the currently-open one.
- Node.js was installed specifically because `services/exchange` requires it; if that service is later dropped from the reference server's scope, this dependency should be reconsidered rather than assumed still-necessary.

## 20. WP-SRV-002 Readiness

**READY WITH CONDITIONS.**

Assessed specifically against hosting the current EAM service and implementing `GET /vault/{id}/artifact`:

- **Repository availability**: present, correct HEAD, clean — ready.
- **Build toolchain**: `cmake`/`ninja`/`gcc`/`g++` present and sufficient for EAM's CMake-based C++ build — ready.
- **PostgreSQL availability**: installed, running, localhost-bound — ready (no OEP database/role exists yet; creating one is WP-SRV-002's own job, not this WP's).
- **Filesystem/storage**: dedicated, clearly-separated directory layout exists (`config/`, `logs/`, `data/`, `artifacts/`, `backups/`) with ample free disk — ready.
- **Network path**: **condition** — only reachable via the VM's own hypervisor host through a NAT port-forward; no LAN-reachable path exists. This does not block *building and testing on the VM itself*, but it does block anything expecting the reference server to be reachable from another machine.
- **Firewall**: active and currently SSH-only; a future EAM port would need an explicit, deliberate firewall rule added when that service is actually stood up — not pre-opened speculatively here.
- **Process/service management**: standard systemd is available; no OEP-specific service unit exists yet (correctly, since none was authorized to be created by this WP).
- **Security posture**: hardened SSH, active firewall, no exposed database/Docker socket — solid baseline; the one open item is `fail2ban`'s unconfigured jails.

No blocker prevents WP-SRV-002 from beginning; the network-topology condition is the one item worth a deliberate decision (bridged adapter vs. continuing NAT-only) before any reachability-from-elsewhere requirement is assumed met.
