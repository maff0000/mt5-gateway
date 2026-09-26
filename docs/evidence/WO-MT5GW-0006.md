# WO-MT5GW-0006 — Shared Broker Directory Template + Retest

All work on dell-debian except the deploy-key exception below (GitHub settings, explicitly authorized). No identifiers appear anywhere in this document.

## One-off exception — deploy keys added via `gh` (2026-09-26)

Matt authorized a **one-off exception** to risk acceptance 2 (the broad `gh` token is otherwise scoped to PR operations only on `maff0000/mt5-gateway` and `maff0000/tron`): used it to add the two repo-scoped deploy keys already generated on dell-debian (WO-MT5GW-0001A), via exactly:

```
gh repo deploy-key add /root/.ssh/deploy_mt5-gateway_ed25519.pub --repo maff0000/mt5-gateway --allow-write --title dell-debian
gh repo deploy-key add /root/.ssh/deploy_tron_ed25519.pub --repo maff0000/tron --allow-write --title dell-debian
```

No other settings, repos, or admin actions touched. Both keys verified via `ssh -T git@github.com` using each repo's dedicated key — both authenticated successfully; scoping itself was verified by an actual push, not just the SSH greeting (see below). All previously-stacked `mt5-gateway` branches (`WO-0002` through `WO-0005`) pushed successfully and PRs opened:
- `wo/WO-MT5GW-0002` → `main`: https://github.com/maff0000/mt5-gateway/pull/1
- `wo/WO-MT5GW-0003` → `wo/WO-MT5GW-0002`: https://github.com/maff0000/mt5-gateway/pull/2
- `wo/WO-MT5GW-0004` → `wo/WO-MT5GW-0003`: https://github.com/maff0000/mt5-gateway/pull/3
- `wo/WO-MT5GW-0005` → `wo/WO-MT5GW-0004`: https://github.com/maff0000/mt5-gateway/pull/4

This document (and this branch) covers WO-MT5GW-0006 itself.

## Task 1 — Shared broker-directory seed

Built by merging three sources into one file, on a throwaway test container (no credentials):
- Base: production `MT5_Vantage`'s `servers.dat` (trinity), copied read-only.
- Merged in via the terminal's own live "Find your company" search (which queries MetaQuotes' directory and caches results locally): FTMO (using production `MT5_FTMO_Practice`'s `servers.dat` as the source broker entry) and Oanda (found live, needed no seed at all — see note below).
- Verified all three broker families visible together in the GUI (FTMO Global Markets Ltd, 7 Oanda entities, 5 Vantage entities) before extracting the merged file.

Installed at:
```
/srv/mt5-gateway-instances/_shared/servers.dat
```
- Mode: `0644 root:root`
- Size: **277,588 bytes**
- SHA-256: `998c2b5fa1b788a7ec9b75b663b39ae5890d49a7cc3e8ad77fad41ff45a02893`
- Confirmed outside any git repository (`git rev-parse --is-inside-work-tree` fails there) — cannot be accidentally committed.

**Note on Oanda:** Oanda did not need seeding at all — it's discoverable via the terminal's live "Find your company" search on a completely stock install, unlike Vantage and FTMO (boutique/prop-firm brokers apparently absent from MetaQuotes' default distributed directory, only resolvable once a `servers.dat` entry exists). Included in the shared seed anyway since the live search was already open.

## Task 2 — Template changes (`wo/WO-MT5GW-0006`, stacked on 0005)

- `start.sh`: `seed_servers_dat_if_missing()` copies `/seed/servers.dat` into the terminal's `Config/` directory **on first boot only** — gated on a plain existence check of the target file, never overwrites. Verified: first boot logs `"Seeded broker directory (servers.dat) from shared seed (first start only)"`; every subsequent boot (both a full recreate and a genuine `docker restart`) logs `"Broker directory (servers.dat) already present -- not touching it"`.
- Also fixed, found live while testing the restart step: a stale `/tmp/.X1-lock` left over from the previous run (the container's `/tmp` is not cleared by `docker restart`, only the new persistent volume's contents survive) was blocking Xvnc entirely after every restart. Now cleared defensively at the top of Step 1 — safe, since if Xvnc were genuinely still running, `docker restart` already killed it.
- `deploy/compose.instance.yml`:
  - Mounts the shared seed read-only at `/seed/servers.dat` (fixed host path, not instance-relative — same seed for every instance).
  - Adds a persistent named volume, `${INSTANCE_NAME}-data` (→ `mt5-vantage-paper-data` for this instance) mounted at `/home/headless`, so the Wine prefix, MT5 install, and terminal state survive restarts. Previously there was no volume at all — every container recreation was a full fresh MT5 install from scratch.
  - KasmVNC on `6901` (already fixed in WO-MT5GW-0003/0005).
- Rebuilt as `mt5-gateway:0.2.0-rc4` (digest `sha256:c60a2cf9d0cedf59cea2c8f40d77efd1c442cb6dd3cc7498ab348b98b07b6c3f` — second build, after the lock fix; first rc4 build, pre-fix, was superseded before use).
- `gitleaks` clean throughout every commit on this branch.

## Task 3 — Real test on `mt5-vantage-paper`

Matt's Vantage demo secrets already in place from WO-MT5GW-0003.

**3a — Started clean** with the new template (`compose down` then `up -d` against the previous rc3-based instance, which had no persistent volume at all).

**3b — Real broker connection, verified the required way (not title bar, not chart data):**
```
ESTABLISHED  28.179.164.194:443
ESTABLISHED  145.247.117.166:700
```
Both genuinely external addresses, confirmed via `/proc/net/tcp` inside the container. The second (port 700, with neighbouring ports 701-703 seen cycling through TIME_WAIT across this session) matches an MT5 trade-server protocol's typical port cluster pattern.

**3c — `initialize()` via the bridge, from a separate client container on the same compose network:**
```json
{
  "initialize_result": true,
  "initialize_seconds": 0.01,
  "last_error": [1, "Success"],
  "terminal_build": 6230,
  "trade_mode": "0"
}
```
`trade_mode: "0"` = `TRADE_MODE_DEMO`. No login, name, or balance read or reported, per instruction.

**This is the first genuine, verified-live MT5 Python API success anywhere in this entire investigation, from May 2026 through today.** Every previous `-10005 IPC timeout` — on every image, every Wine version, every session configuration, with or without credentials — is now understood not to have been a Wine/IPC defect at all: the terminal was correctly reporting that it had nothing to connect to, because none of those attempts had valid broker routing data (`servers.dat`) for FTMO or Vantage. Once a real, resolvable server plus real credentials were both in place, `initialize()` succeeded immediately.

**Correction for the record:** an earlier "confirmed connected" claim made during today's live troubleshooting (based on title bar text and Market Watch values) was mistaken — those are static/cached display values present even on fully unauthenticated sessions, not evidence of a live connection. The verification method used here (`/proc/net/tcp`, `ESTABLISHED` state, non-local address) is the only one trusted for this report, and for any future one.

**3d — Restarted the container once (genuine `docker restart`, not a recreate) and repeated 3b and 3c:**
- Log confirms the seed was **not** re-applied (`"Broker directory (servers.dat) already present -- not touching it"`), and every install step logged `"already installed"` — the persistent volume carried the full Wine prefix, MT5 install, and packages across the restart.
- The stale-lock bug above was hit and fixed *during* this exact step, on the pre-fix `rc4` build — recreated with the fixed build before re-running 3d for a valid result.
- Post-restart, with the fix in place: same two `ESTABLISHED` connections re-established automatically, and the identical `initialize()` result:
```json
{
  "initialize_result": true,
  "initialize_seconds": 0.01,
  "last_error": [1, "Success"],
  "terminal_build": 6230,
  "trade_mode": "0"
}
```

**Step 3c is `True`, both times. Per instruction, `mt5-vantage-paper` is left RUNNING.**
