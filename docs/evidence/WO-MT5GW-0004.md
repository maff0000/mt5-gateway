# WO-MT5GW-0004 — Wine Session Identity Experiment

All work on dell-debian. No live or existing containers touched — throwaway test containers/volumes/network only. No credentials used anywhere in this WO. No changes made to the mt5-gateway image or scripts. No identifiers appear below.

**Note on methodology:** the WO's Test A instructions assumed the stock `gmag11/metatrader5_vnc` image auto-starts an mt5linux/RPyC bridge on its own ("let the image's own start.sh finish until the mt5linux server is listening. Don't exec anything into Wine yourself"). Confirmed (again, as in WO-MT5GW-0002 Task 3b) that it does not — the stock image only installs Wine/MT5/Python/`mt5linux`, nothing starts a listener automatically. Whatever production's actual auto-start mechanism is (likely a `DOCKER_MODS`-injected service, invisible from the plain public image), it isn't reproducible without that information. Started the bridge myself, as the **same user that runs `terminal64.exe`** (`abc`, non-root) — this is the correct, minimal way to establish Test A's "same session" baseline, and is a different thing from Test B's deliberately-different-session method below.

**Second finding along the way:** `mt5linux`'s own bundled `metatrader5.py` (both the Wine-side server module and the Linux-side client module, same file) fails to import under Python < 3.12 — genuine PEP 701 (Python 3.12) multi-line f-string syntax, a hard `SyntaxError` on Python 3.9 (Wine side) and Python 3.11 (tested client side). This is a real, pre-existing packaging bug in current `mt5linux` (whatever version `pip install mt5linux` resolves to), unrelated to anything in this repo. Trinity's own system-wide `mt5linux` install is pinned to `1.0.3`, which does **not** have this bug — used `1.0.3` for the client in this experiment as the closest match to what's actually in use elsewhere on this infrastructure.

## Test A — gmag11 as production uses it

- Fresh `gmag11/metatrader5_vnc:latest`, throwaway volume, isolated docker network, no host-published ports. Only change made: `numpy<2` (the fix already found in WO-MT5GW-0002 Task 3b), applied as the `abc` user.
- Bridge started as `abc` (same user as `terminal64.exe`) — see methodology note above.

**Process table:**

| Process | User | UID | WINEPREFIX |
|---|---|---|---|
| `wineserver` | abc | 911 | `/config/.wine` |
| `terminal64.exe` | abc | 911 | `/config/.wine` |
| bridge (`python.exe`) | abc | 911 | `/config/.wine` |

**Wineserver count: 1.** Same user, same prefix, same session — this is the "good" baseline the hypothesis needs.

**Client call**, from a separate container on the same network, using the official `mt5linux.MetaTrader5` client class (v1.0.3, the production path) with no arguments:

```
initialize() -> False
last_error   -> [-10005, "IPC timeout"]
terminal_info().build -> None (unreadable, initialize() failed)
```

**Test A FAILS.** Same session, same user, real production client path, only the known numpy fix applied — still `-10005`.

## Test B — reproduce the old test method on the same container

Attempted literally as specified: `docker exec` as root, `wine python`, `initialize()`. **Wine itself refuses this outright** before any IPC attempt: `wine: '/config/.wine' is not owned by you` — Wine's own built-in per-prefix ownership check blocks root from touching a prefix owned by another user, full stop. This means the literal "docker exec as root" scenario as historically described could never actually have run against an unmodified `abc`-owned prefix — some ownership step must have been involved if this was ever done before.

To actually test the underlying question ("does a second wineserver appear under a different UID, and what happens"), temporarily `chown`'d the prefix to `root:root` (this is a throwaway container, destroyed immediately after) and reran the same call as root:

```
initialize() -> False
last_error   -> [-10003, "IPC initialize failed, MetaTrader 5 x64 not found"]
```

**A second wineserver did appear, under `root` (uid 0)** — confirmed via `pgrep`/`ps`: two `wineserver` processes, one `abc`/911 (unchanged, still serving `terminal64.exe`), one new `root`/0. **Wineserver count: 2.**

This is the cleanest part of the result: a genuine session mismatch produces a **different, immediately-explicable error** (`-10003`, "not found" — the root session's wineserver literally cannot see the other session's `terminal64.exe`, which is exactly what you'd expect from two isolated Wine sessions). This is qualitatively different from the `-10005` timeout we've been chasing everywhere else, including in Test A's genuinely-same-session run.

## Test C — mt5-gateway:0.2.0-rc2

Fresh container, no credentials.

**Process table:**

| Process | User | UID |
|---|---|---|
| `wineserver` | headless | 1000 |
| `terminal64.exe` | headless | 1000 |
| `bridge/rpyc_server.py` | headless | 1000 |

**Wineserver count: 1.** Same user throughout — this repo's own `start.sh` never uses `docker exec`/root at all; everything runs from the same process tree under the single `USER headless` the Dockerfile sets.

**Client call**, via the bridge, from a separate container:

```
initialize() -> False
last_error   -> [-10005, "IPC timeout"]
terminal_info().build -> None (unreadable, initialize() failed)
```

Same result as Test A and as every prior test in this repo.

## Interpretation — stated explicitly, per instruction

**A fails. Hypothesis REFUTED.**

Session/process identity was never actually the uncontrolled variable in any of this repo's real tests — `mt5-gateway` (Test C) and our own bridge script have always run the bridge as the same user as `terminal64.exe`, single wineserver, matching Test A's "good" configuration exactly. Test B shows what an *actual* session mismatch produces, and it isn't `-10005` — it's a distinct, well-explained `-10003`. The `-10005` failure this whole investigation has been chasing (May 2026 through today, across the Debian12 self-build, the KasmVNC variant, stock gmag11, and this repo's `mt5-gateway`, with and without credentials, with and without matched process identity) is not explained by Wine session mismatch.

**The Config-diff experiment (checksums of the terminal's `Config` directory before and after a real VNC login) is the next step**, as you proposed. Nothing else in the eliminated-hypothesis list from May, or from this WO, points anywhere else.

## Cleanup

All test resources removed and confirmed gone: `MT5_0004_TESTA`, `MT5_0004_CLIENT`, `MT5_0004_TESTC`, `MT5_0004_CLIENTC` containers; `helm_mt5gw_0004_testA_config`, `helm_mt5gw_0004_testC_config` volumes; `mt5gw-0004-net` network.
