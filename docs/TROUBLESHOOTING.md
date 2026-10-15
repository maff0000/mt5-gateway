# Troubleshooting

Format: symptom, cause, check, fix. Causes come from `start.sh`, `tools/mt5ctl`, the Compose template or
the cited evidence. Where behaviour was **not observed**, the entry says "unverified". No entry here
means the repository has no evidence for a diagnosis, not that none exists.

Handy, read-only starting points (run from the host):

```bash
docker ps --filter name=<instance>
docker inspect -f '{{.State.Status}} {{.State.Health.Status}} restarts={{.RestartCount}}' <instance>
docker logs <instance> --tail 80
docker exec <instance> tail -n 60 /tmp/start_sh.log      # step log written by start.sh
```

Container-internal logs are `/tmp/start_sh.log` (steps), `/tmp/wine.log` (Xvnc, Wine) and
`/tmp/rpyc_server.log` (bridge). `/tmp` is the container's own layer: it survives `docker restart` but
not a recreate, and `start.sh` truncates all three at every start.

## A. Configuration tooling

| Symptom | Cause | Check | Fix |
|---|---|---|---|
| `lint: FAIL` with `unknown key`, `missing required key`, pattern errors | `instance.yaml` violates the schema | the message names the path, e.g. `$.limits.cpus` | edit per [CONFIG-REFERENCE.md](CONFIG-REFERENCE.md) section 3 |
| `ERROR line N: ... lists/flow/anchors unsupported`, `tabs are not allowed`, `indent must be a multiple of 2`, `duplicate key`, `empty value` | the strict YAML subset (no PyYAML) | line number in the message | use plain nested maps with two-space indents; quote empty or ambiguous strings |
| `secrets.dir ... does not exist`, `mode is 0o..., must be 0700`, `secret X is missing/empty`, `mode ... must be 0600` | secrets not provisioned or wrong mode | `stat -c '%a %U:%G %n' <secrets.dir> <secrets.dir>/*` (modes and names only; do not read the files) | create the three files, `chmod`, fill them |
| `unexpected entry 'bridge_token'` (or any other name) | extra file in the secrets dir. An old `bridge_token` was dropped from the contract in WO-MT5GW-0010 | listing of the directory | the owner removes the file; tooling never deletes secrets |
| `collides with peer ... on project/network/volume/secrets_dir` or `published port` | two configs share a resource | the message names the peer | give each instance its own name and UI port; compare with `--peers` explicitly if siblings are not the right peer set |
| `peer ...: unreadable/invalid, cannot prove disjointness` | a sibling directory with a broken `instance.yaml` | lint that file | fix or move it; directories starting with `_` are ignored |
| LIVE errors, `refused: LIVE provisioning is not enabled` | by design; `render` refuses LIVE always | n/a | do not use LIVE with this template |
| `docker compose config failed: ...` from `render` | Docker or the Compose plugin missing/failing, or a rendering error | run the printed compose command by hand; or use `render --no-docker` to confirm lint passes | install the Compose plugin; the message tail is passed through (first 500 characters) |
| `WARNING secrets directory/file checks SKIPPED by --skip-fs ...` | expected with `--skip-fs` | n/a | do not use `--skip-fs` for a real instance. The LIVE marker check still runs (see CONFIG-REFERENCE section 6) |

## B. Compose and Docker

| Symptom | Cause | Check | Fix |
|---|---|---|---|
| `required variable X is missing a value` on `up`, `stop`, `down`, `ps` | the template uses required variables; the command lacked `--env-file` or the same `-f` files | compare with the command printed by `render` | repeat every compose command with identical `--env-file` and `-f` arguments |
| port already allocated / address already in use for the UI port | the host port is held by another process or container (standard Docker behaviour; not exercised on this template) | `ss -ltn` for the port; `docker ps` | choose another `ports.operator_ui`. Lint only compares configs, not the host |
| container name already in use | a container with the instance name exists (`container_name` equals the instance name) | `docker ps -a --filter name=<instance>` | remove the stale container yourself (verify first) or rename the instance |
| volume or network "already exists with a different configuration" / unexpected reuse | names are fixed by config; Docker state is not checked by lint | `docker volume ls`, `docker network ls` | keep names disjoint; do not reuse another instance's names |
| secret file not found when creating the container | `secrets.dir` path wrong or file missing at start | `ls` the directory (names only) | fix the path or create the file |
| `servers_dat` bind mount problems | lint does not check that the seed exists; Docker's behaviour for a missing source is unverified here | `ls -l <servers_dat>` | create the seed file before `up` |
| image not found | the skeleton tag `CANDIDATE-unbuilt-from-main` does not exist | `docker image ls mt5-gateway` | build and set a real tag in `image` |
| compose warns that secret `uid`/`gid`/`mode` are ignored | Compose (non-Swarm) always mounts secrets root:root 0400 (WO-MT5GW-0003) | n/a | expected; `start.sh` reads them with `sudo` (hazard H1) |

## C. Startup and health

| Symptom | Cause | Check | Fix |
|---|---|---|---|
| health `starting` for minutes after first boot | first boot installs MT5, Wine Python and pip packages; about 100 seconds was seen in WO-MT5GW-0003; start period is 300 s | `start_sh.log` step lines `[6/12]`, `[8/12]`, `[9/12]` | wait; if downloads fail see below |
| `FAIL Xvnc did not come up (no X socket)` | Xvnc failed to start | `/tmp/wine.log` | check resources and the Xvnc lines in the log. A stale X lock after `docker restart` was fixed in WO-MT5GW-0006: `start.sh` now removes `/tmp/.X1-lock` and the socket every start |
| `FAIL MT5 installer download failed` or `MT5 install timed out` | no outbound access to the MetaQuotes download host, or install exceeded 600 s | `start_sh.log`, `/tmp/wine.log` | restore outbound access and restart. Note: the installer URL is unpinned (known limitation) |
| Wine Python or pip steps seem to stall | downloads from python.org and PyPI at first boot; unpinned installers | `/tmp/wine.log` | restore connectivity; the build/first boot is not hermetic |
| `[11/12] MT5 FAILED to start` | `terminal64.exe` did not appear within 120 s | `/tmp/wine.log` | unverified causes; look at Wine output |
| health `unhealthy` | `pgrep` found no `terminal64.exe` or no `rpyc_server` process | `docker exec <instance> pgrep -af 'terminal64|rpyc_server'` | the bridge is restarted by its own loop after 5 s (`rpyc_server exited, restarting in 5s` in `/tmp/rpyc_server.log`); a missing terminal is not restarted by `start.sh`. Restart the container |
| `All wine processes gone — exiting` and the container stops | the watchdog saw no Wine, terminal or bridge process and exited 0 | `docker logs` tail | start it again; under `restart: "no"` it will not come back by itself |
| first-boot modal dialogs on the UI ("Select a company ...", "Welcome to LiveUpdate") | observed on fresh no-credential volumes (WO-MT5GW-0002); `AutoUpdate=0` did not suppress the LiveUpdate popup | UI screenshot via the tunnelled browser | dismiss them in the UI. With credentials and a seed, not re-observed in the evidence |
| instance does not return after a host reboot | restart policy defaults to `no` | `docker inspect -f '{{.HostConfig.RestartPolicy.Name}}'` | start it manually; `unverified` whether `unless-stopped` is clean on this template |

## D. Terminal login and API

| Symptom | Cause | Check | Fix |
|---|---|---|---|
| bridge `initialize()` returns `False`, `last_error` = `[-10005, 'IPC timeout']` | historically seen in every no-credential run and in WO-MT5GW-0003 even with credentials. WO-MT5GW-0006 attributes it to the terminal having no usable broker directory and routing data: with a seeded `servers.dat` plus credentials it succeeded. That change was not isolated experimentally (the seed, a persistent volume and a lock fix landed together). Ruled out by experiment: the Python-API gate, first-run dialogs, a one-minor-version package bump (a broader "package version ruled out" claim was withdrawn, ERRATA E6), Wine session identity (WO-0004), image vintage (WO-0005) | `start_sh.log` should say `Seeded broker directory ...` or `... already present`; `broker_server` must be the right alias; secrets must be non-empty | provide the seed and correct alias, confirm credentials. For any other cause: unverified |
| `last_error` = `[-10003, 'IPC initialize failed, MetaTrader 5 x64 not found']` | seen when the client ran in a different Wine session (a root `docker exec` against a user-owned prefix, WO-MT5GW-0004 Test B) | which user runs the client | run Wine commands as the same user as the terminal (`headless` is the image default for `docker exec`) |
| start log says `launching without credentials` | `mt5_login` or `mt5_password` missing or empty at container start | secrets file sizes (not contents) | fill both, restart |
| terminal logged in at the wrong account or wrong server | wrong secrets or `broker_server` alias | the instance's own terminal journal | correct and restart. There is no check that the account is DEMO (see KNOWN-LIMITATIONS). Failure signatures for a wrong password are not recorded in the evidence: unverified |
| `servers.dat` changed in `servers_dat` but the instance ignores it | the seed is copied on first boot only and never overwrites | `start_sh.log` says `already present -- not touching it` | to re-seed you must replace the file inside the volume (a maintainer action, not exercised in the evidence) or use a new volume |
| client cannot talk to the bridge, odd protocol errors | rpyc 6.x client against the 5.2.3 server is protocol-incompatible; a stock numpy 2.x breaks the MT5 import (WO-MT5GW-0002 Task 3b) | client package versions | use `rpyc==5.2.3`, `numpy<2` |
| stale or no ticks | no evidence in this repository: tick freshness was planned in WO-MT5GW-0003 but never run, and no tool measures tick age. Possible, all unverified: market closed for that symbol (crypto symbols trade at weekends; FX does not), terminal disconnected from the broker | established sockets to external addresses (see OPERATOR-GUIDE section 7); the terminal's own journal | none established. If connectivity is gone, restart; otherwise investigate in the terminal UI |
| `terminal_info()` or `account_info()` unreadable | follows an `initialize()` failure (WO-MT5GW-0003) | see the first row of this table | n/a |

## E. Browser UI

| Symptom | Cause | Check | Fix |
|---|---|---|---|
| start log says `running WITHOUT auth (no-credential test mode only)` (the **fail-open warning**), or an unauthenticated request returns `200` | `vnc_password` missing or empty, or `kasmvncpasswd` could not create the store. `start.sh` then launches Xvnc with `-disableBasicAuth` | `curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:<port>/` should be `401` | provide a non-empty `vnc_password` and recreate. Treat the instance as exposed until fixed. This is hazard H2 |
| browser login rejected | wrong user or password. The Basic Auth user is `matt` (fixed in `start.sh`), the password is the content of `vnc_password`. With `headless` as user, login failed in WO-MT5GW-0007 | the `[1/12]` log line says `Basic Auth enabled from secret` | use user `matt` |
| 401 prompt, then blank or "not working" page | historical: WO-0007 found Basic Auth unprovisioned while VncAuth was configured; replaced by WO-0008 | `Xvnc` arguments | current `start.sh` provisions Basic Auth; outcome of an interactive browser test is not recorded in the evidence |
| a VNC client cannot connect to port 5901 | the RFB port is neither published nor bound by a listener in this image (WO-MT5GW-0003). The `start.sh` banner still prints it | `/proc/net/tcp` inside the container | use the web UI on 6901 through the loopback port. The classic VncAuth route does not work with the bundled web client (WO-MT5GW-0008) |
| UI port unreachable from another machine | by design: loopback bind only | n/a | use an SSH tunnel to the host's loopback port. The UI is cleartext HTTP |
| browser shows passwords or session in cleartext on a network | Basic Auth over HTTP is base64 only | n/a | never expose the UI beyond loopback/tunnel |

## F. When in doubt

- Do not "fix" a symptom by publishing the bridge port, widening the UI bind, or disabling secrets.
- Do not paste logs that may include account details into public places; the evidence rules in this
  repository forbid account numbers, real server addresses and secrets.
- If the problem is not listed here, record exactly what you observed; add it to this page only once
  there is evidence for the cause.
