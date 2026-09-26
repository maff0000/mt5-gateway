# WO-MT5GW-0002 — Evidence

All work in this document executed on **dell-debian** (`192.168.11.10`), per the WO-MT5GW-0001A relocation. No account identifiers appear anywhere below.

## Task 0a — PLUTUS freeze

PLUTUS (`mt5_plutus` + `mt5_plutus_web`, `/srv/mt5_plutus` on dell-debian) was still running when this WO opened. Per Matt's explicit instruction: set `restart: "no"` on both services, then `docker compose down` — images and volumes preserved, shared database untouched.

**Before:**

| Container | Status |
|---|---|
| `mt5_plutus_web` | Up 5 weeks (healthy) |
| `mt5_plutus` | Up 5 weeks (healthy) |
| `proteus-mariadb-dev` (shared DB, not part of PLUTUS's own compose) | Up 4 weeks (healthy) |

**Action:**
- `docker-compose.yml`: both services' `restart: unless-stopped` → `restart: "no"` (working-tree edit only, not committed — this is an operational change, not a code change; PLUTUS has its own git history and owner).
- `docker compose down` (no `-v`) run from `/srv/mt5_plutus`.

**After:**

| Container | Status |
|---|---|
| `mt5_plutus_web` | removed (was stopped first, clean shutdown) |
| `mt5_plutus` | removed (was stopped first, clean shutdown) |
| `proteus-mariadb-dev` | Up 4 weeks (healthy) — **unchanged, untouched** |

**Preserved (confirmed, not deleted):**
- Images: `mt5-plutus-web:1.0`, `mt5-plutus-web:0.4`, `mt5-plutus-web:0.3`, `mt5-plutus:0.4`, `mt5-plutus:0.2`, `mt5-plutus:0.1` — all present.
- Volumes: none named specifically to PLUTUS were found bound to these containers at removal time (their state lives in `env_file` + the shared MariaDB, not a dedicated named volume) — no volume deletion occurred either way.
- PLUTUS database: not touched — no migration run, no query executed, no user/schema change.

**Proposed, not executed** (per instruction — propose only):
- Lock MariaDB users `plutus_rw` / `plutus_ro`: `ALTER USER 'plutus_rw'@'%' ACCOUNT LOCK;` and `ALTER USER 'plutus_ro'@'%' ACCOUNT LOCK;` (exact host/`@` clause to be confirmed against the real grant table before running — proposal only, not verified against current grants).
- Close ports `18813` (mt5_plutus RPyC) and `3013` (mt5_plutus_web) — since both containers are now down these ports are already unbound at the docker-proxy level, but a DOCKER-USER `DROP` rule would make the closure durable against any future accidental `docker compose up` on this host. Not applied.

## Risk acceptance (recorded per Matt's instruction, 2026-09-26)

Helm operates as **root** on dell-debian via a **root SSH key originating from trinity** (`/root/.ssh/id_ed25519`, per CLAUDE.md's documented `ssh root@192.168.11.10` access). This is broader access than a dedicated service account would need.

**Accepted by Matt** for **PAPER accounts only**. Conditions:
- No live/real-money credentials may be placed on dell-debian until a dedicated non-root user (scoped to this work) replaces the root-key access model.
- Matt fills all secrets himself; Helm creates directories/permissions only, never reads or handles credential values.
- Matt gives an explicit go before every credentialed container start (T3-equivalent and beyond) — no autonomous credentialed logins.

## Task 0 — Stop-hook diagnosis (`ECONNREFUSED 192.168.246.77:8765`)

Unrelated to the MT5 work. This is Claude Code's own **voice output** feature: `/root/.claude/settings.json` on trinity has `"voice": {"enabled": true, "mode": "hold"}` plus a user-level `Stop` hook posting to `http://192.168.246.77:8765/speak` on every turn end, for text-to-speech.

`192.168.246.77` answers ARP/ICMP on the LAN (host is up), but nothing listens on TCP 8765 (connection actively refused, not a timeout) — most likely a companion voice-output app on that device isn't currently running. No fix applied or needed on trinity's or dell-debian's service stack; this sits outside both.
