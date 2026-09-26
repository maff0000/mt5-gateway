# WO-MT5GW-0005 — Replay Production's Exact gmag11 Image, Fresh

All work on dell-debian except step 1 (trinity, explicitly read-only — image metadata + a package query, no container access, no Wine calls, no credentials, no restarts). No identifiers below.

## Step 1 — Production image facts (trinity, read-only)

```
docker inspect -f '{{.Config.Image}} {{.Image}} {{.Created}}' MT5_FTMO_Practice
-> gmag11/metatrader5_vnc sha256:f7e6bc30869a036066f0650fbeca4226bd7e224cbcd7d88f5606731b2b74117c 2026-04-20T17:47:12Z

docker exec MT5_FTMO_Practice dpkg-query -W -f='${Package} ${Version}\n' 'winehq*' 'wine-stable*'
-> wine-stable 10.0.0.0~bookworm-1
   wine-stable-amd64 10.0.0.0~bookworm-1
   wine-stable-i386 10.0.0.0~bookworm-1
   winehq-stable 10.0.0.0~bookworm-1
```

Wine version is **identical** to every other image tested throughout this whole investigation — the "older Wine" element of the hypothesis doesn't hold on this evidence. The image itself, however, is a pull from **2026-04-20** — roughly 5 months old relative to today, distinct from every "fresh gmag11" pull used in WO-MT5GW-0002/0004 (which grabbed today's `latest`).

## Steps 2-3 — Replay, fresh, no credentials

- `docker save` on trinity (read-only on the image) → checksum-verified copy to dell-debian → `docker load` → temporary tarball (4.9GB) deleted on **both** hosts, confirmed gone.
- **Side note:** loading this image locally on dell-debian overwrote the previously-pulled `gmag11/metatrader5_vnc:latest` tag reference there (from WO-MT5GW-0002/0004's testing) — cosmetic only, the container itself was run by explicit image ID (`sha256:f7e6bc30...`), not by tag, so no ambiguity in this test. Worth knowing if anyone later wonders why dell-debian's local `gmag11/metatrader5_vnc:latest` now resolves to a 5-month-old image.
- Fresh container from that exact image ID, throwaway volume, isolated network, no host-published ports, no credentials. Let its own init run to completion (no manual exec beyond what Test A's methodology already established was necessary — see WO-MT5GW-0004: nothing auto-starts a bridge in this image family).

**Wine version confirmed inside the running container:** `wine-stable 10.0.0.0~bookworm-1` — matches step 1 exactly, as expected (this is the same image).

**Terminal build: 6230.** Same as every other test in this whole investigation, including today's fresh `gmag11:latest` pull (WO-MT5GW-0002 Task 3b) and this repo's own image. **This is itself an important, somewhat surprising fact: a fresh container from production's 5-month-old image still auto-updates the terminal to today's current build on first launch.** The "terminal build" was never actually pinned by which image vintage you start from — it converges to whatever MetaQuotes currently serves, every time, regardless. This strongly implies production's own long-running containers are very likely also on build 6230 by now (or whatever build MetaQuotes serves today), not whatever build they originally launched with.

Package versions as shipped by this image (unpinned, same as every stock gmag11 pull): `numpy==2.0.2` (breaks the MT5 import, same fix as before), `mt5linux==1.1.1` (same Python-3.12-only f-string bug as WO-MT5GW-0004), `rpyc==6.0.2`, `MetaTrader5==5.0.36`. Fixed `numpy<2` and `rpyc==5.2.3` to make the test runnable — the same two fixes already established as necessary and harmless in every prior differential test in this investigation, applied identically here for a fair comparison.

## Step 4 — Production-path test

Separate client container, `mt5linux==1.0.3` (matching trinity's own system-wide pin, the version that actually imports cleanly — see WO-MT5GW-0004), `initialize()` with no arguments:

```
initialize() -> False
last_error   -> [-10005, "IPC timeout"]
terminal_info().build -> None (unreadable, initialize() failed)
```

## Step 5 — FAIL

**Production's own exact image, replayed fresh with a throwaway volume, fails identically to everything else tested in this entire investigation — same Wine, same terminal build, same `-10005`.**

This decisively rules out "the fix is in the image's contents" as an explanation. Production's live containers work — that much is not in question — but not because of anything baked into the image. Whatever makes them work is **runtime state accumulated over their actual lifetime**: a genuine human-driven login session, months of uptime, or something the fresh-boot path structurally cannot replicate. This is exactly the branch point the WO anticipated for a FAIL result.

**No side-by-side table or minimal-change proposal produced** — that was specified only for the PASS branch, which this isn't.

## Next: the Config-diff experiment

Per the WO's FAIL branch and Matt's original proposal: checksum/list the terminal's `Config` directory on a genuinely fresh volume, have Matt log in **once**, manually, via VNC (real keystrokes, credentials never touch Helm), then checksum/list `Config` again. Whatever changed besides the known credential file (`accounts.dat`) is the candidate for what injection is missing. This requires the VNC port fix (committed to `wo/WO-MT5GW-0003`, `5901`→`6901`) to actually be usable, and requires a human step I cannot perform myself (typing credentials is handling them, which I don't do) — prepared but not yet run; see the accompanying report for what's ready and what's needed from Matt.

## Cleanup

All test resources removed and confirmed gone: `MT5_0005_PRODREPLAY`, `MT5_0005_CLIENT` containers; `helm_mt5gw_0005_prodreplay_config` volume; `mt5gw-0005-net` network. Both copies of the 4.9GB image tarball deleted (trinity and dell-debian).
