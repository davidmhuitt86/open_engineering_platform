# SERVER-BRINGUP-001 — OEP Reference Server Environment Audit — 2026-09-13

Read-only environment audit of the newly provisioned OEP Reference Server VM (VirtualBox guest, reachable at the time of audit via `oep@127.0.0.1:2222` through a NAT port-forward on the host). Companion to [`ADR-0001-OEP-REFERENCE-SERVER-BOUNDARY-AND-ARTIFACT-CONTRACT.md`](../../architecture/decisions/ADR-0001-OEP-REFERENCE-SERVER-BOUNDARY-AND-ARTIFACT-CONTRACT.md) and [`2026-09-13-OEP-REFERENCE-SERVER-READINESS-AUDIT.md`](2026-09-13-OEP-REFERENCE-SERVER-READINESS-AUDIT.md) (WP-SRV-001), which assessed the *repository's* readiness to support a reference server; this report assesses the *actual VM host's* current state instead.

**No package was installed or removed. No configuration file was modified. No database, user, or firewall rule was created or changed. No service was started or stopped. The OEP repository (not present on this host) was not touched. `docs/server/OEP_REFERENCE_SERVER_REQUIREMENTS.md` was not read as part of forming this report's conclusions and was not modified.** All findings below were gathered via read-only shell commands over SSH (key-based auth as the unprivileged `oep` user); commands requiring `sudo` that would have needed an interactively-typed password were either skipped or run by the VM owner themselves and the output relayed back.

---

## 1. Operating System

- Distribution: Ubuntu 26.04.1 LTS "Resolute Raccoon" (`/etc/os-release`)
- Kernel: `7.0.0-31-generic #31-Ubuntu SMP PREEMPT_DYNAMIC Sat Aug 1 04:26:38 UTC 2026 x86_64`
- Hostname: `oepstudioserver`

## 2. Hardware

- vCPUs: 4 (`nproc`)
- Memory: 7.4 GiB total, 504 MiB used, 6.9 GiB available; 0 swap configured
- This is a VirtualBox guest (confirmed via the running `vboxadd-service.service` and a `vboxsf`-mounted shared folder — see Section 9)

## 3. Network

- Single interface `enp0s3`, MAC `08:00:27:3e:63:76`
- IPv4: `10.0.2.15/24` (dynamic, VirtualBox NAT DHCP), gateway `10.0.2.2`
- IPv6: a `fd17:...` ULA and a link-local address, both dynamic
- DNS: `systemd-resolved`, stub listeners on `127.0.0.53:53` and `127.0.0.54:53`
- No bridged/LAN-routable address exists at present — this VM is only reachable from its own host via the NAT layer and an explicit port-forward (host `2222` → guest `22`), not from the wider network. This is a materially different topology from a bridged, LAN-addressable reference server and would need to change before any other machine could reach it.

## 4. Firewall

- `ufw status verbose` → **inactive** (checked interactively by the VM owner; no rules of any kind are currently enforced by ufw)
- Only two TCP listeners exist system-wide: `sshd` on `0.0.0.0:22`/`[::]:22`, and the local-only DNS stub resolver. There is currently no *application* port exposed to firewall off — but there is also no firewall actively protecting the host if one were added later.

## 5. SSH

- `ssh.service` active, OpenSSH server
- Effective config (`sshd -T`, confirmed by the VM owner): `passwordauthentication yes`, `pubkeyauthentication yes`, `kbdinteractiveauthentication no`, `usepam yes`
- `authorizedkeysfile` at its default (`.ssh/authorized_keys .ssh/authorized_keys2`)
- `PerSourcePenalties` is enabled with defaults (`authfail:5`, `refuseconnection:10`, etc.) — a newer OpenSSH per-source-IP throttling feature; worth knowing about if a legitimate client is ever locked out after repeated failed attempts (a service restart, performed by the owner, clears it — not done as part of this read-only audit)
- `fail2ban.service` is active (jail-level detail requires root and was not read)
- `~oep/.ssh` is `700`, `authorized_keys` is `600`, both owned `oep:oep` — structurally correct
- No indication root login is disabled or enabled was captured explicitly (`PermitRootLogin` not seen in the portion of `sshd -T` reviewed) — **flag for follow-up**, not confirmed either way

## 6. Docker

- **Not installed.** `docker` is not on `PATH`, and no `docker`-related package appears in `dpkg -l`.

## 7. PostgreSQL

- **Not installed.** No `psql` client on `PATH`; no `postgresql` systemd unit exists; no `postgres`-related package appears in `dpkg -l`.

## 8. Development Toolchain

Present: `git`, `gcc`, `g++`, `python3`.
**Absent**: `cmake`, `node`/`npm`, `dart`/`flutter`. None of the OEP build toolchain beyond a bare C/C++ compiler and git exists on this host yet.

## 9. Reverse Proxy

- **Not installed.** No `nginx`, `caddy`, or `traefik` binary and no matching package.

## 10. OEP Repository State

- **No copy of the repository exists on this host.** Searched `/home`, `/opt`, `/srv` (3 levels deep) for any directory named like `open_engineering_platform` or a `.git` directory — none found.
- Consequently, the expected-HEAD check (`a93192d88b75c7564ad6f465ec6d6bc7ad8db115`) is **not applicable** — there is nothing to check it against yet.

## 11. Existing OEP Services

- **None.** `systemctl list-units --type=service --state=running` shows only stock Ubuntu/VirtualBox-guest services (chrony, cron, dbus, fail2ban, fwupd, getty, ModemManager, multipathd, networkd-dispatcher, polkit, rsyslog, snapd, ssh, systemd-*, udisks2, unattended-upgrades, upower, vboxadd-service). No EAM, Exchange, Foundation-server, or any other OEP-named unit exists.
- No listening TCP port beyond SSH (22) and the local DNS stub — confirming no OEP service (e.g. EAM's default `8080`) is bound anywhere on this host.

## 12. Storage

- Root filesystem `/dev/sda2`: 103G total, 3.9G used, 94G available (4% used) — ample headroom.
- `/boot/efi`: 1.1G, 6.4M used — normal.
- A VirtualBox shared folder, `D_DRIVE`, is mounted at `/media/sf_D_DRIVE` via `vboxsf`: 1.7T total, 1.3T used, 430G available. This is host-shared storage, not guest-local disk, and is unrelated to any OEP data path today — flagged only for completeness, since a shared folder mount is an unusual thing to find on a "reference server" and its intended purpose (if any, for OEP) is unknown and not something this read-only audit can determine.

## 13. Security/Secrets (Non-Destructive Check)

- `/etc/shadow`: `640`, owned `root:shadow` — correct, standard.
- `/etc/passwd`: `644`, owned `root:root` — correct, standard.
- `oep` user is a member of `sudo` (plus `adm`, `cdrom`, `dip`, `plugdev`, `users`, `lxd`, `vboxsf`) — has administrative privilege via `sudo`, but `sudo` itself required an interactively-typed password during this audit (no passwordless/`NOPASSWD` sudoers entry observed for this user; `/etc/sudoers.d/README` was not readable without root, and no other drop-in was inspected).
- AppArmor is loaded (`aa-status` reports the module loaded; profile-level detail requires root and was not read).
- No plaintext credential file, `.env`, or secret material was found or searched for beyond what standard commands surfaced incidentally (none appeared in listed service units, `sshd` config, or home-directory listings reviewed). This is not an exhaustive secrets sweep — a full one would require root-level filesystem traversal, which was out of scope for this read-only, unprivileged-user audit.

## 14. Time/Locale

- `timedatectl`: local/UTC time `2026-09-14 03:54:18`, timezone `Etc/UTC`, **`System clock synchronized: yes`**, NTP service (`chrony`) active.
- The VM owner had earlier observed the on-screen VM clock looking wrong during initial bring-up (before `chrony` had synchronized); by the time of this audit, the clock is confirmed synced and correct. No further action needed on this point.
- Locale: `en_US.UTF-8` consistently set across all `LC_*` categories — clean, no `POSIX`/`C` fallback contamination.

## 15. Overall Readiness Classification

**NOT READY FOR OEP DEPLOYMENT.**

This is a clean, minimal, freshly-provisioned Ubuntu 26.04 LTS base image with a working SSH front door and nothing else OEP-specific yet:
- No OEP repository present at all.
- None of Docker, PostgreSQL, a reverse proxy, or the full dev toolchain (cmake/node/dart-flutter) are installed.
- No firewall is active (not a blocker for readiness per se, but relevant to note before opening the host up further).
- Network topology (NAT + single port-forward) does not currently allow any host other than its own hypervisor's Windows host to reach it.

None of this is a defect — it is the expected state of a base OS image before any OEP-specific provisioning work has begun. It simply means WP-SRV-002 (or an equivalent bring-up work package) has a full, from-scratch provisioning job ahead of it, not an incremental one.

## 16. WP-SRV-002 Preconditions

Before WP-SRV-002 (or any actual OEP deployment work) can proceed on this host, the following need to happen — none of which this audit performed, per its read-only mandate:

1. Clone the OEP repository onto the host and confirm it lands at (or can be fast-forwarded to) the expected commit.
2. Install Docker (or whichever container runtime the deployment design calls for).
3. Install PostgreSQL, matching whatever version the acquisition/EAM services require.
4. Install the remaining dev toolchain: `cmake`, Node/npm, Dart/Flutter (only the subset actually needed for the services intended to run *on this host*, not necessarily the full Studio client toolchain).
5. Decide on and install a reverse proxy if the deployment design (per ADR-0001) calls for one in front of EAM/Exchange.
6. Decide on and enable a firewall policy (`ufw` or otherwise) appropriate to whatever ports get opened once services are running.
7. Decide on the intended network topology — the current NAT+port-forward setup only permits access from the VM's own hypervisor host; a bridged or otherwise LAN-reachable configuration is a separate decision with its own tradeoffs, not something this audit recommends one way or the other.
8. Confirm `PermitRootLogin` and general SSH hardening posture explicitly (this audit could not confirm the current value) before the host is exposed beyond a single trusted developer's own machine.

## 17. Validation Performed

- All commands were run as the unprivileged `oep` user over key-based SSH; no destructive or mutating command was issued.
- Every `sudo`-requiring check either failed cleanly (reported here as "not observed" rather than guessed at) or was run directly by the VM's owner in their own interactive session, with output relayed back verbatim.
- No file on this Windows repository host or the VM was created, edited, or deleted as part of gathering these findings, other than a new, dedicated, passphrase-less SSH key pair (`~/.ssh/oep_vm_audit`) generated purely to authenticate this audit's own read-only commands — this key is unrelated to any OEP artifact or configuration and is not part of this report's subject matter.
- `docs/server/OEP_REFERENCE_SERVER_REQUIREMENTS.md` was not opened, read, or modified in the course of this audit.
