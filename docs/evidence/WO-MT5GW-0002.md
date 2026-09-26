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

## Task 3 — T2 fix, rebuild, retest (dell-debian)

### Fix applied

`start.sh`'s `preseed_experts_and_autoupdate()` (replacing the old `suppress_auto_update()`, which only patched an *existing* `common.ini` and was therefore a no-op on a genuinely fresh volume): creates `Config/common.ini` from scratch when absent, always reasserts `[Common] AutoUpdate=0` and `[Experts] Api=1` / `AllowDllImport=1` (plus `Account=0`/`Profile=0`/`Chart=0` per prior KRONOS/Helm doctrine), called unconditionally right before every launch — not only after a fresh install. Also fixed the Dockerfile's `COPY` paths, which still pointed at the old pre-rename filenames from the source tree (first rc2 build attempt failed at `COPY` for exactly this reason — fixed and rebuilt).

### Rebuild

- `mt5-gateway:0.2.0-rc2`, `--no-cache`, built on dell-debian from this repo's own `Dockerfile`.
- Digest: `sha256:a6dcb387ba9426d78f358e3064f0b3770f679afc173eae2b7370e137703a00d4`
- Wine confirmed: `wine-stable 10.0.0.0~bookworm-1` (same pin as rc1).
- Terminal build installed fresh: **6230** (same as rc1 — MetaQuotes' installer always fetches current; nothing here pins a specific terminal build number, this remains an open risk, previously flagged as R12 in the original design doc).

### T0 — PASS
Build completed clean, no cache. Wine version confirmed as above.

### T1 — PASS
Fresh no-credential container, isolated volume. Journal: `automated trading is enabled` → `disabled` → clean toggle proof, identical to rc1. No identity ever touched.

### T2 — STILL FAILS. Root cause is deeper than the fix addressed; reporting honestly rather than declaring this closed.

Sequence of checks, each on the same fresh no-credential volume:

1. **Gate confirmed correct before any GUI interaction.** Read `common.ini` immediately after boot, before touching anything: `AutoUpdate=0`, `[Experts] AllowDllImport=1 Api=1 Account=0 Profile=0 Chart=0` — all present exactly as the fix intends. The T2 fix works as designed.
2. **First RPyC attempt with the gate correct:** `mt5.initialize()` → `False`, `last_error = [-10005, 'IPC timeout']`. Same failure signature as rc1, despite the gate fix.
3. **Screen check:** same two stacked modal dialogs as rc1 reproduced ("Select a company to open an account with" + "Welcome to LiveUpdate"/Restart prompt) — **`AutoUpdate=0` does not suppress the LiveUpdate popup**, contrary to the original design assumption. Dismissed both via the same click sequence as rc1.
4. **Retest after dismissal, gate still correct:** `mt5.initialize()` → `False`, `last_error = [-10005, 'IPC timeout']` again. Rules out the dialogs as the (sole) cause too.
5. **Differential test (per WO instruction — test only, not merged):** upgraded `MetaTrader5` package from `5.0.36` to the current latest, `5.0.37`, against the *same* installed terminal build (6230). Restarted `rpyc_server.py` to pick up the new package, confirmed `mt5.__version__ == '5.0.37'` on the next connection. Retest: `mt5.initialize()` → `False`, `last_error = [-10005, 'IPC timeout']` — **unchanged**. Package version is not the cause either.

**Net result:** three independent variables were tested and ruled out — the Python-API gate (now fixed and confirmed correct), the first-run modal dialogs (dismissed and confirmed clean), and the `MetaTrader5` package version (differential-tested against current). All three ruled out; the timeout persists identically across every combination. This points toward something structural in this specific terminal build (6230) or its IPC negotiation under Wine 10.0 that none of the previously-documented fixes address — closest match is risk R12 from the original design doc ("build 5836 vs 5833 vs newer MT5 builds — Python API IPC may regress on newer builds"), which was flagged as a risk in May and never actually mitigated (no terminal-build pinning mechanism exists in either `start.sh` variant — the installer always fetches whatever MetaQuotes currently serves).

**Not attempted without Matt's go, per the WO's own package-upgrade caveat and the broader "propose don't run" discipline on anything beyond what was explicitly asked:** pinning/caching a specific known-good terminal build inside the image; deeper Wine-level IPC tracing (`WINEDEBUG` verbose logging around the MT5↔wine-python IPC channel); testing against an older cached terminal installer.

Test containers (`MT5_GW_RC2_T1`, `MT5_GW_RC2_T2`) and their volumes removed after testing — confirmed gone by re-query.

## Corrections (Matt, 2026-09-26)

### Correction 1 — Compose files

Confirmed: compose files are correctly excluded from Task 2's import. The instance compose file will be written fresh later, not carried over from the old test harness.

### Correction 2 — GitHub auth risk acceptance

`gh` was found already authenticated on dell-debian with the same broad personal token used on trinity (`admin:enterprise`, `admin:org`, `admin:repo_hook`, etc. — pre-existing on this host, not something introduced by this WO). **Accepted by Matt** alongside the root-access risk acceptance above, with constraints:
- Usable **only** for PR operations on `maff0000/mt5-gateway` and `maff0000/tron`: `gh pr create` / `gh pr view` / `gh pr list` / `gh repo view`.
- **Never** for admin, org, settings, other repos, or any delete operation.
- Push still goes through the repo-scoped deploy key once Matt adds it — the broad token is not used for `git push`.
- **Revisit trigger:** must be replaced with a scoped fine-grained token before any live broker credentials are used on this host, or before the repos go private at MVP — whichever comes first.

### Correction 3 — Task 3 package differential was not actually established

The Task 3 evidence above states "package version ruled out" after testing `MetaTrader5` `5.0.36` → `5.0.37`. **That conclusion does not hold.** Verified against PyPI directly (`https://pypi.org/pypi/MetaTrader5/json`):

- Current latest is **`5.0.6180`** (not `5.0.37` — `pip index versions` inside the container only listed `5.0.37` because it silently filters to wheels compatible with the running interpreter).
- **Every version from `5.0.5328` onward (and all versions checked back through the list) ships `win_amd64`-only wheels — no 32-bit (`win32`) wheel at all.** This image runs 32-bit Wine Python (`Python39-32`), so a current package **cannot be installed on this image as it stands** — not "wasn't tested," genuinely can't be installed without a 64-bit Python rebuild.
- What was actually tested was a one-minor-version bump (`5.0.36` → `5.0.37`), the last version that still shipped a 32-bit wheel at the time this differential was attempted — not a real test against current. That result (unchanged `-10005` failure) stands as data, but "package version ruled out" as a conclusion is withdrawn. Package version remains an **open variable**, gated behind a 32-bit vs. 64-bit Python architecture decision that hasn't been made.

## Task 3b — Reference differential: gmag11/metatrader5_vnc (dell-debian, no credentials)

Ran a fresh `gmag11/metatrader5_vnc:latest` container on dell-debian, throwaway volume, isolated docker network (`mt5gw-refdiff-net`, no host-published RPyC port — the RPyC test connected from a second throwaway helper container on the same isolated network, never via a host port). Not one of the live containers; nothing live was touched or restarted. All test resources removed afterward and confirmed gone.

### What the stock image actually ships (undocumented before this test)

- The vanilla image does **not** auto-start any RPyC bridge — it only installs Wine, MT5, and a Python 3.9.13 32-bit environment. Whatever exposes port 18812 on the real production `MT5_Vantage`/`MT5_FTMO_Practice`/`MT5_FundedNext` containers was added by the team on top of this base, same as our own build does.
- Its Wine Python environment already has **`mt5linux==1.1.1`** installed (`plumbum==1.7.0`, `rpyc>=6.0.0,<7` as its own dependencies) — this is the real production bridge package (a maintained PyPI project providing a Linux-side `MetaTrader5` proxy), not a hand-rolled script like our `bridge/rpyc_server.py`. This is a genuine, previously-undocumented architecture difference worth carrying into any future production-migration decision.
- Its default (unpinned) `numpy` is **2.0.2** — which breaks the `MetaTrader5` C extension import (`numpy.core.multiarray failed to import`), exactly the failure mode our own build's `numpy<2` pin exists to prevent. This is not something I introduced; it's what a stock `pip install` resolves to today. Fixed to `numpy==1.26.4` (matching our pin) purely to make the test runnable.
- Default `rpyc` is **6.0.2**, protocol-incompatible with our `rpyc==5.2.3` client/server. Downgraded to `5.2.3` purely to make the test runnable (mt5linux's own dependency constraint on rpyc was overridden for this test — mt5linux itself was not used or tested here, only the base Wine/terminal environment plus our own bridge script, to isolate the same variable as rc2's test).

### Recorded facts

| | gmag11 (dell-debian, this test) | rc2 (mt5-gateway, dell-debian) |
|---|---|---|
| Wine | `wine-10.0` (`wine-stable 10.0.0.0~bookworm-1` family) | `wine-10.0` (`wine-stable 10.0.0.0~bookworm-1`) — same |
| Terminal build | **6230** (fresh install, same day) | **6230** (fresh install, same day) — same |
| Python | 3.9.13, 32-bit (`Python39-32`) | 3.9.13, 32-bit (`Python39-32`) — same |
| MetaTrader5 package (as shipped) | 5.0.36 | 5.0.36 — same |
| numpy (as shipped, unpinned) | **2.0.2** (broken; fixed to 1.26.4 to test) | 1.26.4 (pinned `<2` in image build) |
| rpyc (as shipped) | **6.0.2**, via `mt5linux` (downgraded to 5.2.3 to test) | 5.2.3 (pinned in image build) |
| Bridge mechanism | none by default; `mt5linux` package present but not used in this test — our own `rpyc_server.py` copied in instead, for a controlled comparison | `bridge/rpyc_server.py` (same script) |
| [Experts] gate at test time | unset (no fix applied — this is stock gmag11, our T2 fix was never ported to it) | `Api=1`/`AllowDllImport=1` (our T3 fix, confirmed set) |
| First-run dialogs | **identical** stack: "Select a company to open an account with" + "Welcome to LiveUpdate" restart prompt | identical stack (confirmed on rc1 and rc2) |
| `mt5.initialize()` result | **`False`, `last_error = [-10005, 'IPC timeout']`** | `False`, `last_error = [-10005, 'IPC timeout']` |

### Verdict: gmag11 FAILS identically

Once the test environment was made runnable (matching rpyc protocol version, fixing the numpy ABI break neither of us caused but both needed fixed to test at all), **the production-baseline image fails the exact same way, on the exact same terminal build, that our self-build does.** This was confirmed with `terminal_info()` returning `None` and the identical `-10005` error, not just an assumption from the identical dialog screenshot.

**What this does and doesn't establish:**
- Establishes: this is not a defect specific to our `Dockerfile`/`start.sh`/`rpyc_server.py`. The reference baseline the whole self-build was validated against in May reproduces the identical failure today, on today's terminal build.
- Does **not** establish gmag11's own gate state, since our T2 fix was never applied there — gmag11's `common.ini` had no `[Experts]` section at all, same starting point our own build had before the fix. This doesn't weaken the finding (our own rc2 already independently ruled the gate out, with the fix confirmed applied), it just means gmag11 wasn't a second independent test of the gate specifically.
- Dialog-dismissal parity was **not** independently repeated on gmag11 — its stock image has no `xdotool` (confirmed absent), so the click-based dismissal used on rc1/rc2 couldn't be run there. The pre-dismissal failure was confirmed directly on gmag11; the post-dismissal result is inferred from rc2's identical behavior, not independently reproduced here.

**Leading hypothesis, now better supported:** MT5 terminal build **6230** has a Wine-10.0 IPC regression that is independent of image packaging — matches the pre-existing risk R12 from the original design doc, now with cross-image evidence rather than a single data point.

Test resources removed and confirmed gone: `MT5_REFDIFF_GMAG11`, `MT5_REFDIFF_HELPER` containers, `helm_mt5gw_refdiff_gmag11_config` volume, `mt5gw-refdiff-net` network — all re-queried empty after removal.

**Unplanned discovery during cleanup verification:** dell-debian runs its own `MT5_Vantage` container (same image, same port pattern `3010→3000`/`18812→18812`, `Up 5 weeks`) — pre-existing, not created by this or any WO-MT5GW-000x work, untouched throughout. Flagged separately to Matt and recorded in fabric (`helm:finding:dell_debian_has_own_mt5_vantage_container:v1`) since it shares a name/port pattern with the container Matt confirmed backs Agent Smith on trinity — real risk of a future cross-host cleanup targeting the wrong one by name alone.

**No image changes made.** No changes merged to `Dockerfile`/`start.sh` from this task — this was diagnostic only, per instruction.
