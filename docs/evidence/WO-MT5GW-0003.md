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
