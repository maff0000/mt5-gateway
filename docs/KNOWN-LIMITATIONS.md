# Known limitations

Read this before using the gateway. Each row states the limitation, its effect, and the **planned
increment**. "Planned" refers to the sequence in the maintainers' MT5 Instance Template Contract
(design, not approved; GOAL audit record 2026-10-15), whose increments are: 1 template skeleton (this
repository's configuration contract, done), 2 typed service and test double, 3 first DEMO instance with a
digest-pinned image and a verify command, 4 lifecycle proof, 5 restart/recovery proof, 6 standardise.
Where the contract assigns no increment, the row says so. Nothing here is scheduled or approved.

## Deferred hazards

These three are pinned by strict expected-failure tests in `tests/test_static_security.py`; fixing one
makes the suite demand an update.

| Id | Limitation | Effect | Planned increment |
|---|---|---|---|
| H1 | The runtime user `headless` has passwordless sudo (`Dockerfile`). `start.sh` itself uses `sudo` to read secrets, chown the tmpfs and the Wine prefix | Root inside the container is one command away for anything running as `headless`, including through the bridge. Combined with H3 and root-readable secrets, reaching the bridge means credential access | No increment assigned (contract gap G6). Fix needs a secrets-handling change (read secrets as root, then drop privileges). Candidate for increment 3 image work |
| H2 | VNC authentication fails open: if `vnc_password` is missing, empty, or password provisioning fails, `start.sh` starts the UI with Basic Auth disabled and logs a warning only | An unauthenticated UI (the terminal window and the account it is logged into) if the secret is absent. Lint requires the secret but does not run in the container; publishing is loopback-only by lint | No increment assigned. Target is "refuse to start without it" (the strict-xfail test encodes this); candidate for increment 3 |
| H3 | The bridge is the stock RPyC `SlaveService`, all attributes exposed, bound to `0.0.0.0:18812` in the container, no authentication | Arbitrary code execution for any peer on the instance network, including every MT5 trading call. Network isolation is the only protection; the network is not `internal`, so a compromised peer also has outbound access | Increment 2: the typed, bounded gateway (ADR-MT5-001) replaces it. Until then: no other container on the network, port never published |

## Other limitations

| Limitation | Effect | Planned increment |
|---|---|---|
| **No typed gateway and no Unix-domain-socket transport.** Only the raw bridge exists; nothing speaks the TRON-facing protocol | TRON cannot and must not be connected. There are no allow-lists, caps, idempotency or environment latch | Increment 2 (typed service with a test double), then 3 and 4 for proof on DEMO |
| **No `verify` command.** The container healthcheck only checks that the terminal and bridge processes exist. `mt5ctl` has no `up`, `down`, `status`, `logs`, `restart`, `verify`, `retire` | Login, tick age, account class and exposure are checked by hand (OPERATOR-GUIDE section 7). Health `healthy` says little | Increment 3 (verify, with the lifecycle wrappers) |
| **No in-container LIVE guard.** The DEMO-only gate is `mt5ctl` lint/render. `EXPECTED_TRADE_MODE` reaches the environment but nothing reads it | The terminal logs into whatever the secrets open. A live account could be configured by bypassing the tooling | Gateway-side environment latch in increments 2 and 3 (contract section 3.3). Not implemented |
| **Image build is not hermetic.** apt, `wget` and `git clone` at build; Wine, KasmVNC and noVNC pinned by version, not digest; base image by tag; the Dockerfile labels are stale (`rc2`) | Builds are not reproducible; two builds can differ. No image provenance is proven | Increment 3 (digest-pinned image, version lock) |
| **Unpinned installers at first boot.** The MT5 installer (always the current build), the Wine Python installer, and `pip install --upgrade pip` carry no checksum. `MetaTrader5==5.0.36`, `rpyc==5.2.3`, `numpy<2` are pinned but newer MetaTrader5 wheels are 64-bit only | A new first boot may get a different terminal build; supply-chain integrity is not verified; AutoUpdate=0 did not suppress the LiveUpdate dialog in the evidence | Increment 3 (pinned artefact lock). Terminal build pinning has no assigned design yet |
| **No container-level proof of the new template.** Only lint, render and `docker compose config` are tested. The earlier credentialed success (WO-MT5GW-0006) used the pre-template compose file and `rc6` | The template may have defects that only a container reveals; two instances have never run side by side | Increments 3 and 6 |
| **The running image `0.2.0-rc6` is not the tip.** It matches WO-MT5GW-0008, not WO-MT5GW-0010, and its label says `rc2` | Cannot be used as evidence for the tip. Kept only as rollback evidence (ERRATA E3) | Build a new candidate from `main` (increment 3) |
| **The browser UI is cleartext HTTP with Basic Auth** and a fixed user name `matt` in `start.sh` | Credentials cross loopback or a tunnel unencrypted; fine only for loopback/tunnel use | No increment assigned; TLS was named as a pre-production requirement in WO-MT5GW-0008 |
| **The UI is bound to a LAN interface address on an existing instance** (created before the template, which allows loopback only) | That instance's UI is reachable from the LAN behind Basic Auth over plain HTTP | Recreate it from the template with a loopback bind; the maintainers recorded this as a separate approved change |
| **`accounts.dat` is world-readable (mode 0644) inside a terminal volume** (the terminal creates it; observed on an existing instance) | Any process in the container can read the terminal's binary account metadata; contents not examined | No increment assigned; needs investigation of how the terminal creates the file |
| **Restart and stop behaviour.** Default `restart: "no"`; no reconcile-before-write; no idempotency journal; no signal handling in `start.sh`; no stop grace period set | After a reboot nothing comes back by itself; clean terminal shutdown on stop is unverified | Increment 5 (restart/recovery proof) and the contract's stop/restart design |
| **Order lifecycle never proven on this stack** (pending, cancel, SL/TP, partial close, restart, idempotency, broker-side protection) | Nothing may be said about trading behaviour | Increment 4 (required by ADR-MT5-001 before PAPER) |
| **Tick freshness never measured.** A tick-age check was planned in WO-MT5GW-0003 and never run | The data path is not shown to be live | Increment 3 (verify) |
| **Disjointness is checked between configs only**, not against Docker or host state | A port or name held by something else is found only when Docker fails | Not assigned |
| **`LOG_LEVEL`, `BROKER`, `ENVIRONMENT`, `TZ` reach the container but `start.sh` does not read them** (only labels and the container environment) | Setting `log_level` has no effect on gateway logging | Not assigned |
| **The RFB port 5901 is configured but not bound**; the Dockerfile `EXPOSE`s it and the ready banner prints it | Confusing; raw VNC clients cannot connect (the web UI is the only UI) | Not assigned |
| **The terminal's own local "MCP" listener** (logged at each launch) has not been characterised | Unknown bind class; not published | Characterise before any promotion (GOAL verification item 19) |
| **The repository is public** (since 2026-09-26) and its history contains two broker server addresses and internal host details in evidence docs | Anything committed is public; some topology is already public | Accepted and recorded (ERRATA E2); making it private is the owner's separate decision |
| **Single-file secrets, healthcheck/verify, gateway allow-list from the design contract** | Not implemented (see CONFIG-REFERENCE section 10) | Increments 2 and 3 |
| **A legacy MT5 container and a legacy live-flagged executor (ADR-MT5-002)** exist elsewhere on the deployment host | Out of scope here; this repository must not depend on them and was not tested against them | Controlled operations work outside this repository |

## What this means in practice

- It is acceptable to run a DEMO instance on a trusted host, on its own network, with loopback-only UI
  and no other containers attached, for read-only diagnostics, with the owner's approval.
- It is **not** acceptable to attach TRON or any trading system to the bridge, expose the bridge or UI
  beyond loopback/tunnel, or use real-money credentials.
- No statement in this repository should be read as "secure", "verified live", or "production-ready".
