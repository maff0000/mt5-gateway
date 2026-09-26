# WO-MT5GW-0003 — T3 First Credentialed Login (Vantage DEMO, paper)

All work on dell-debian. No account identifiers appear anywhere below. Task 3c (live build probe against `MT5_FTMO_Practice`) was dropped by Matt before it ran — the earlier attempt in WO-MT5GW-0002 was blocked by the auto-mode classifier and not pursued further.

## Task 0 — Secrets wiring: gap confirmed and fixed

**Before this WO:** `start.sh` expected a pre-rendered `mt5.ini` bind-mounted at `$MT5_MQL5_FILES` (never read `/run/secrets/*` at all), and KasmVNC launched with `-SecurityTypes None -disableBasicAuth` — **no VNC authentication whatsoever**, and no read of `/run/secrets/vnc_password` either. Both are real gaps the Task 5 compose template's security model (KasmVNC's own password, no firewall rule) depended on without actually being wired up.

**Fixed, branch `wo/WO-MT5GW-0003`, rebuilt as `mt5-gateway:0.2.0-rc3`:**

- `render_mt5_ini_from_secrets()` — reads `/run/secrets/mt5_login` + `/run/secrets/mt5_password` plus the non-secret `MT5_SERVER` env var, renders `[Common] Login=/Password=/Server=` to **tmpfs only** (`$GATEWAY_SECRETS_DIR`, mode 0400) — never the persistent volume. Step 11's launch now checks this instead of the old bind-mount path.
- `render_vnc_password()` — reads `/run/secrets/vnc_password`, generates a KasmVNC VncAuth password file via `vncpasswd` (flag combination confirmed directly against `Xvnc --help`: `SecurityTypes` supports `None`/`VncAuth`/`Plain`, `PasswordFile` is the classic VNC-auth password file). Switches Xvnc to `-SecurityTypes VncAuth -PasswordFile`.
- Both fall back to the old no-auth/no-credential behavior **only** when the corresponding secret is absent or empty — every prior no-credential test path (T0–T2, Task 3b) still works, now with an explicit log line stating why.
- `compose.instance.yml`: added a `tmpfs` mount for `$GATEWAY_SECRETS_DIR` (`mode=0700`), bumped image tag to `0.2.0-rc3`.
- Removed the now-dead `WIN_MT5_INI` variable (comments-must-match-code discipline, same as the WO-MT5GW-0002 stale-comment fix).
- **No secret value is ever echoed or logged**: the Python credential renderer reads each file directly and writes straight to the tmpfs output file; the VNC renderer pipes file contents straight into `vncpasswd`'s stdin with no shell `echo` of the value anywhere.

**Verification performed:**
- Empirically confirmed the `vncpasswd` + `-SecurityTypes VncAuth -PasswordFile` combination against a disposable non-primary-display Xvnc instance with a throwaway test password (never a real secret) before committing to it.
- Full no-credential smoke test on `rc3` (fresh volume, no secrets present): both new fallback log lines fire correctly (`"no vnc_password secret, running WITHOUT auth"` / `"no mt5_login/mt5_password secrets — launching without credentials"`), MT5 + `rpyc_server` still boot clean, and the T2 gate fix (`[Experts] Api=1`/`AllowDllImport=1`) still applies. Smoke container + volume removed and confirmed gone.
- Checked the real instance's secret files per instruction — **existence and non-emptiness only** (`test -s`), never contents: as of this check, `mt5_login`, `mt5_password`, `vnc_password`, and `bridge_token` under `/srv/mt5-gateway-instances/mt5-vantage-paper/secrets/` are **all still empty**, and `instance.env`'s `MT5_SERVER` is still the literal placeholder.

## Task 1 — Start and verify: BLOCKED, waiting on Matt

Cannot run a genuine credentialed start — the secrets aren't filled in yet. Starting the instance now would only exercise the no-credential fallback path already covered by the Task 0 smoke test, not the actual T3 credentialed-login check this WO exists to run. Holding here rather than starting it pointlessly.

**Once Matt fills in `mt5_login`, `mt5_password`, `vnc_password`, `bridge_token`, and `MT5_SERVER`, the remaining Task 1/2 checks run as specified:**
- `docker compose -p mt5-vantage-paper --env-file .../instance.env -f deploy/compose.instance.yml up -d`
- Throwaway client container on the same compose network (no host RPyC port): `initialize()` → expect `True`; `terminal_info().build` (report only the number); `account_info().trade_mode` — report **only** whether it equals `DEMO`, nothing else; if not DEMO, stop the container immediately and report. `symbol_info_tick` for 2–3 liquid symbols — report symbol names + tick age in seconds only.
- No order/modification/trade calls of any kind.
- Confirm KasmVNC answers on `192.168.11.10:3021` and now actually asks for a password (it didn't before this fix — that's the point of Task 0).
- R12 interpretation: build 6230 + `initialize()` succeeding refutes R12 (points at the no-credential T2 test criterion instead); an older build would mean R12 stands.

Will report PASS/FAIL per check the moment the secrets are in place and the run completes. Not proceeding further until then.

## Task 1 — Start and verify: RESULTS

Real credentials in place (`mt5_login`, `mt5_password`, `vnc_password`, `MT5_SERVER` — `bridge_token` still empty, unused by anything currently). Two real bugs found and fixed live against the actual running instance before a valid result could even be obtained — recorded in full in the `[WO-MT5GW-0003] Fix secrets file permissions...` commit:

1. Docker Compose (non-Swarm) mounts secrets `root:root` mode `0400` always, and silently ignores `uid`/`gid`/`mode` overrides in the compose spec (confirmed via a live "not supported" warning) — the non-root `headless` container user could not read them at all. Fixed via `sudo` (headless has passwordless sudo per the Dockerfile) rather than changing the container's user model.
2. The `$GATEWAY_SECRETS_DIR` tmpfs mount is itself created `root:root` mode `0700` by Docker (`tmpfs: mode=` only sets mode, not ownership) — `headless` had zero access to the mount itself, separately from the individual secret files. Fixed with an early `sudo mkdir` + `sudo chown`.
3. Along the way, also fixed a `printf`/newline normalisation bug in the VNC password renderer (a raw `cat "$src"; echo` double-newlines when the secret file already ends in `\n`, which made `vncpasswd` see a spurious blank line and report "Passwords don't match").

With all three fixed and the instance restarted clean:

- **VNC auth now genuinely enabled** — Step 1 log line confirms `"VncAuth enabled from secret"` (previously always fell back to no-auth, silently, even with the secret present — the whole point of this WO's Task 0).
- **Credentialed launch confirmed** — Step 11 log line confirms `"mt5_login/mt5_password secrets present — launching with /config:"`.
- **New, separate finding, not part of this WO's scope to fix:** KasmVNC's raw RFB port (`5901`, what `compose.instance.yml` currently publishes) never actually binds a listener in this image — confirmed via `/proc/net/tcp` inside the container: only the websocket port (`6901`) and the RPyC bridge (`18812`) are listening. This was never actually verified in any earlier no-credential test (those used local X display capture via `docker exec ... import -window root`, never a real network connection to the VNC port). **`docs/evidence/` records this as a finding; `compose.instance.yml` has not been changed** — that decision belongs to whoever owns Task 5's template next, since WO-MT5GW-0004 (running concurrently) restricts image/config changes.
- **`initialize()` → `False`, `last_error = [-10005, 'IPC timeout']`** — same failure as every prior no-credential test, now confirmed with a real, correctly-injected Vantage demo login, correct broker server, and VNC auth all genuinely working. Terminal build confirmed **6230** via the native MT5 log (Python API's own `terminal_info()` was unreadable since `initialize()` failed).
- **`account_info().trade_mode`**: unreadable — `account_info()` itself failed, same as `terminal_info()`, both downstream of the `initialize()` failure. Not "not DEMO" — genuinely unreadable, so the "stop immediately if not DEMO" trigger doesn't strictly apply, but the check did not PASS either.
- Tick freshness check: not attempted — `initialize()` failing makes it moot.

**R12 interpretation, per this WO's own stated rule:** *"a logged-in build-6230 initialize() succeeding refutes R12"* — it did not succeed. **R12 stands.**

Per Task 2's explicit rule ("leave running unless a check fails; if one fails, compose down but keep the volume"): the `initialize()` check failed, so the instance was brought down. No named volume was ever defined in `compose.instance.yml` for `/home/headless` (Task 5 never asked for one) — there was nothing to "keep"; every start is a fresh MT5 install from scratch (confirmed: each restart across this whole diagnosis took ~90–105s to reinstall MT5 + Wine Python + packages).
