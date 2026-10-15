# Evidence index

Index of every historical record in `docs/evidence/` plus `docs/DESIGN.md`. Those files are history and
are never edited; corrections are in [ERRATA.md](ERRATA.md). For each record: its date, what it claims,
what it actually proves, and a status.

Status values:

- **CURRENT**: still describes the repository or is an accurate historical record of what was done.
- **SUPERSEDED**: a later record replaced its conclusion or mechanism (the record remains accurate as
  history of what was believed or done at the time).
- **CORRECTED**: the record, or part of it, contains a statement shown to be wrong or too strong; the
  correction is in the errata (or in a later record) and the record is left unedited.

Two caveats apply to everything below. First, all runtime evidence is from the **pre-template**
compose file and images `0.2.0-rc2` to `0.2.0-rc6` on one host; **no container has been run from the
current template**. Second, evidence docs contain internal addresses and host details that predate the
public-repository rules in this documentation set (audit findings F3 and F4); they are preserved, not
reproduced elsewhere.

## Summary

| Record | Date | Status |
|---|---|---|
| [WO-MT5GW-0001-inventory.md](evidence/WO-MT5GW-0001-inventory.md) | not stated | CURRENT |
| [WO-MT5GW-0002.md](evidence/WO-MT5GW-0002.md) | 2026-09-26 | CORRECTED (R12 hypothesis SUPERSEDED) |
| [WO-MT5GW-0003.md](evidence/WO-MT5GW-0003.md) | not stated (after 0002) | SUPERSEDED in part |
| [WO-MT5GW-0004.md](evidence/WO-MT5GW-0004.md) | not stated | CURRENT (negative result) |
| [WO-MT5GW-0005.md](evidence/WO-MT5GW-0005.md) | not stated | SUPERSEDED (conclusion) |
| [WO-MT5GW-0006.md](evidence/WO-MT5GW-0006.md) | 2026-09-26 | CURRENT, with CORRECTED aspects |
| [WO-MT5GW-0007.md](evidence/WO-MT5GW-0007.md) | not stated | SUPERSEDED by 0008 |
| [WO-MT5GW-0008.md](evidence/WO-MT5GW-0008.md) | not stated | CURRENT |
| [WO-MT5GW-0010.md](evidence/WO-MT5GW-0010.md) | 2026-09-27 (decision record) | CORRECTED (section 4) |
| [r2d2_audit_verdict.md](evidence/r2d2_audit_verdict.md) | 2026-05-13 | CURRENT as history, scope-limited |
| [h3_long_wait_probe_log_t30.txt](evidence/h3_long_wait_probe_log_t30.txt) | 2026-05-14 | SUPERSEDED (context) |
| [t3_d12_probe_result.json](evidence/t3_d12_probe_result.json) | 2026-05-14 | SUPERSEDED (context) |
| [w1_warmed_state_metadata_20260514T131500Z.json](evidence/w1_warmed_state_metadata_20260514T131500Z.json) | 2026-05-14 | CURRENT as history |
| [DESIGN.md](DESIGN.md) | 2026-05-13 | historical export; CORRECTED (E5), many statements SUPERSEDED |

Not part of this repository's evidence: the maintainers' GOAL audit record of 2026-10-15 (template
contract, DEMO read-only verification, independent consolidation audit). It is cited here and in the
other documents; those files are not in this repository.

## Detail

### WO-MT5GW-0001-inventory.md (CURRENT)

- Claims: inventory of the 43 files in the original source tree and which were imported, redacted or
  excluded (all PNGs, all legacy test compose files, diagnostics). It corrects its own earlier count from
  33 to 43.
- Proves: what was imported and why. Nothing about runtime behaviour. It also records, correctly, that
  the bridge is an unauthenticated `SlaveService` protected only by network isolation.

### WO-MT5GW-0002.md (CORRECTED; R12 hypothesis SUPERSEDED)

- Claims: PLUTUS freeze (operational record), risk acceptances (root access, `gh` token), T0 build and
  T1 GUI toggle PASS for `0.2.0-rc2`, T2 (`initialize()`) still FAILS with `-10005`, reference image fails
  identically, scope rule for new components only.
- Proves: the `-10005` failure was not specific to this repository's image (a stock reference image
  fails identically on the same terminal build); that the Python-API gate and first-run dialogs were not
  the cause; the build and the toggle.
- Does not prove: the build-6230/R12 explanation it favours. **Superseded**: WO-MT5GW-0006 resolved the
  failure by supplying broker routing data. **Corrected** inside the record: Correction 3 withdraws
  "package version ruled out" (only a one-minor-version bump was tested; current wheels are 64-bit only,
  and this image uses 32-bit Python). Correction 2's "before the repos go private" trigger is itself
  superseded by WO-MT5GW-0010; see also E1.
- Note: the DOCKER-USER firewall proposal it mentions is withdrawn within the same record (scope rule).

### WO-MT5GW-0003.md (SUPERSEDED in part)

- Claims: secrets wiring from `/run/secrets/*` to a tmpfs (kept), VNC authentication via
  `vncpasswd`/VncAuth, three live bugs fixed (secret permissions, tmpfs ownership, password newline),
  first credentialed start fails with `-10005`, "R12 stands", raw RFB port 5901 never binds, "no named
  volume".
- Still true and still relied on: secrets are root:root 0400 and need `sudo`; tmpfs ownership; port 5901
  has no listener (the web UI on 6901 is the only UI).
- **Superseded**: VncAuth (replaced by WO-MT5GW-0008's Basic Auth; WO-0008 shows VncAuth cannot work with
  the bundled web client), "R12 stands" (WO-MT5GW-0006), "every start is a fresh install" (persistent
  volume from WO-MT5GW-0006). Its credentialed `-10005` was a real result at the time.

### WO-MT5GW-0004.md (CURRENT, negative result)

- Claims: Wine-session-identity hypothesis tested on throwaway containers; Test A (reference image, same
  user) fails with `-10005`; Test B (different Wine session) fails differently (`-10003`); Test C (this
  image) fails like A.
- Proves: session identity is not the cause of `-10005`, and a genuine session mismatch produces
  `-10003`, a distinct signature. It does not explain `-10005`. It proposes a "Config-diff" experiment as
  the next step; no record of that experiment exists in this repository.

### WO-MT5GW-0005.md (SUPERSEDED conclusion)

- Claims: the production reference image, replayed fresh, fails identically (same Wine, same terminal
  build 6230, same `-10005`); concludes that production "works because of accumulated runtime state".
- Proves: image vintage is not the explanation; terminal build converges to the current build
  regardless of image age. **Superseded**: the "accumulated runtime state" conclusion was answered by
  WO-MT5GW-0006 (missing broker directory), though that attribution is itself not isolated (see E4).

### WO-MT5GW-0006.md (CURRENT, with CORRECTED aspects)

- Claims: shared broker-directory seed (`servers.dat`) built and installed outside the repository,
  seeded on first boot only; a persistent named volume added; stale X lock fix; real test on one DEMO
  instance: established external sockets, `initialize()` `True`, `trade_mode` `"0"` (DEMO), terminal
  build 6230, unchanged after a genuine `docker restart`; "first genuine, verified-live" success;
  deploy keys added; PRs opened.
- Proves: with a seeded `servers.dat`, real DEMO credentials and a persistent volume, the terminal
  connected and `initialize()` succeeded on that deployment, twice, across a restart, with the seed not
  re-applied. This is the only credentialed success in the repository's evidence.
- Does not prove: an authenticated-login read, tick flow, account state, trading capability, or that the
  seed alone was the cause of the earlier failures.
- Status notes: **CORRECTED** by WO-MT5GW-0010 (the line-3 "no identifiers" claim and the redaction of two
  broker server addresses) and by errata E2 (the addresses remain in history at `b5170ff`, blob
  `d271672`, redacted at `fbcd433`); E4 (the "first verified-live" wording is slightly strong). Its
  compose details (`VNC_BIND`, fixed paths) are superseded by the parametrised template.

### WO-MT5GW-0007.md (SUPERSEDED by WO-MT5GW-0008)

- Claims: browser login failed because KasmVNC Basic Auth was never provisioned; fix was
  `-disableBasicAuth` and reliance on VncAuth (image `0.2.0-rc5`); the effective password is the first 8
  characters.
- Proves: the diagnosis of an unprovisioned Basic Auth layer (401 behaviour) was correct. Its fix
  disabled the only layer the browser actually uses and is **superseded**: VncAuth does not work with
  the bundled web client (WO-MT5GW-0008), and the 8-character DES limit no longer applies. The record
  also states the length of a real secret; that detail is history, not guidance.

### WO-MT5GW-0008.md (CURRENT)

- Claims: the bundled client cannot do classic VncAuth; Basic Auth is provisioned from
  `vnc_password` with `kasmvncpasswd` for the fixed user `matt`, RFB security `None` behind it
  (image `0.2.0-rc6`).
- Proves: against the deployment at that time, unauthenticated GET gave 401 with a Basic challenge, the
  right credential gave 200, a wrong one 401; `Xvnc` arguments confirmed. The matching `start.sh`
  is what the `rc6` image contains (E3).
- Does not prove: an interactive browser login (handed to the owner; no result is recorded here), TLS
  (none: cleartext HTTP, accepted for DEMO/LAN/paper only), or behaviour of the current template. It
  mentions the no-credential branch only as "unchanged"; the fail-open consequence (no secret means no
  authentication) is not called out as a hazard there.

### WO-MT5GW-0010.md (CORRECTED)

- Claims: redaction of two broker server addresses (section 1), removal of the unused `bridge_token`
  secret from the compose template and the bridge recorded as unauthenticated (section 2), removal of a
  non-existent Fabric citation (section 3), and a visibility record saying the repository is private
  (section 4).
- Proves: sections 1 to 3 describe real changes to the tip. **Section 4 is wrong**: the repository is
  public and has been since 2026-09-26 (E1). Section 1's "no other non-private IPv4 address" is true of
  the tip only; the addresses remain in history (E2). No `WO-MT5GW-0009` exists. The `gh` token
  acceptance is extended to "until live broker credentials are introduced".

### r2d2_audit_verdict.md (CURRENT as history, scope-limited)

- Claims: a design audit of the May 2026 self-build design accepted it and authorised the first test
  phases; production cutover was blocked pending a separate work order.
- Proves: that a design review took place and what it authorised. It is **not** an audit of this
  repository's code, the Debian/KasmVNC build, or any later work.

### h3_long_wait_probe_log_t30.txt and t3_d12_probe_result.json (SUPERSEDED context)

- Claims/proves: May 2026 probe output from the earlier self-build variants (a 60-second wait and a
  credentialed read-only probe) showing `initialize()` false with `-10005`. They corroborate the
  history of the failure; they say nothing about the current image. `t3_d12_probe_result.json` records a
  secret length and `account_info: null`; no value is present.

### w1_warmed_state_metadata_20260514T131500Z.json (CURRENT as history)

- Claims/proves: a snapshot of file names, sizes and hashes of a terminal's `Config/` directory on a
  warmed volume, flagging `accounts.dat` as sensitive (no content). Used as input to the abandoned
  Config-diff idea. Hashes only.

### DESIGN.md (historical export; CORRECTED by E5)

A design export from May 2026, kept as provenance. It states it is not the current specification.
Statements that no longer match the build:

| Design statement | Current build |
|---|---|
| Ubuntu 24.04 base | `debian:12-slim` |
| TigerVNC standalone | KasmVNC `Xvnc` 1.4.0 with a built-in web client |
| `mt5.ini` bind-mounted into `MQL5/Files` | rendered from secrets into a tmpfs at start |
| one secrets source file | three Compose file secrets |
| Wine Python installer `amd64`, `PrependPath=1` | 32-bit Python 3.9.13, `PrependPath=0` |
| `healthcheck` with `nc -z` on 18812 | `pgrep` for the terminal and bridge processes only |
| xdotool Ctrl+E fallback | not present in `start.sh` |
| JSON-file log rotation in compose | not set in the template |
| "redaction enforced" for `Password=` lines | a `sed` mask on the credentialed launch pipe only (E5) |
| build reproducibility (digest pins, recorded installer hashes, two identical builds) | not done; build is not hermetic |

## Where the evidence is thin

- Credentialed connection: one deployment, on 2026-09-26 or shortly after, via a pre-template compose file.
- Interactive browser login after WO-MT5GW-0008: no record.
- Tick freshness, order lifecycle, restart under load, two instances side by side, and the image
  built from `main`: no evidence.
- The maintainers' read-only host-side verification (GOAL audit record, 2026-10-15) adds: the terminal
  journals show DEMO authorisation, the container ran healthy for about 19 days with no restarts, only the
  UI port was published (to a LAN interface address, not loopback), the bridge port had no host
  publication, secrets modes were correct. It made no broker call and does not prove the stored password
  is a trading password or who owns the account.
