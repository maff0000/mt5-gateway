# mt5-gateway

A Docker image and per-instance Compose template that run one **MetaTrader 5 terminal under Wine**
(Debian 12 base, Wine 10.0 stable, 32-bit Python 3.9) together with an RPyC bridge to the terminal's
Python API and a KasmVNC browser UI. One container is one broker account. Instances are described by a
small non-secret `instance.yaml` and checked by a stdlib-only tool, `tools/mt5ctl`.

> ## Status: working-but-unfinished DEMO gateway. NOT production-ready.
>
> - **DEMO accounts only.** LIVE is refused by the tooling (a lint/render gate; there is no equivalent
>   guard inside the image).
> - **The bridge is unauthenticated.** It is the stock RPyC `SlaveService` with every attribute
>   exposed. Anyone who can reach it can run arbitrary code in the container, including every MT5
>   trading call and access to the mounted credentials. Network isolation is its only protection.
> - There is **no typed, bounded gateway** yet (the target is described in
>   [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)), no `verify` command, and no TRON integration.
> - Nothing in this repository should be read as "secure", "verified live" or "production-ready".
>   See [docs/KNOWN-LIMITATIONS.md](docs/KNOWN-LIMITATIONS.md) before doing anything with it.

## What is proven, and what is not

Proven (historical work orders, evidence in [docs/EVIDENCE-INDEX.md](docs/EVIDENCE-INDEX.md)):

- An earlier, pre-template deployment of this image connected a terminal to a broker DEMO server:
  established external sockets, `initialize()` returned `True`, `trade_mode` reported DEMO, and the
  result repeated after a `docker restart` with the persistent volume (WO-MT5GW-0006).
- The browser UI login is gated by KasmVNC Basic Auth provisioned from a secret: 401 without
  credentials, 200 with the right one, 401 with a wrong one, checked over HTTP against that
  deployment (WO-MT5GW-0008). The result of an interactive browser login test is not recorded in this
  repository.
- The configuration contract (schema, lint, render, LIVE refusal, two-instance disjointness) is
  covered by the test suite (`python3 -m pytest -q tests`: all pass, plus 3 strict expected failures that
  pin known hazards, and a docs test for links and addresses).

Reported by the maintainers, **not re-verified here** (the evidence is not in this repository): a
read-only host-side check on 2026-10-15 of an existing instance (DEMO authorisation in the terminal
journals, container uptime, which UI address was bound, file modes). Treat it as a claim, not as proof.

Not proven:

- **No container has been built or started from the new template.** `docker compose config` proves
  variable interpolation only. The running DEMO evidence is historical (WO-MT5GW-0006/0008, image
  `0.2.0-rc6`) plus the read-only verification above.
- The `rc6` image matches the WO-MT5GW-0008 `start.sh` but not the current tip; its label still says
  `rc2`. It is kept as historical rollback evidence only. A new candidate has to be built from `main`.
- The image build is not hermetic (apt, downloads and `git clone` at build time, unpinned installers).
- No in-container enforcement of DEMO-only operation, no tick-freshness or login check tooling, no
  order-lifecycle proof on this stack.

## Architecture in one paragraph

`start.sh` is PID 1 in the container. It starts KasmVNC (`Xvnc`) with a browser UI on container port
6901, a minimal window manager, the Wine prefix, the MT5 terminal (installed on first boot), and an
RPyC server under Wine Python on container port 18812. Credentials come from three Compose file
secrets and are rendered into a tmpfs, never into the persistent volume. The bridge port is never
published to the host; it is reachable only from other containers on the instance's own Compose
network. The browser UI is published only if you ask for it, and only on a loopback address. Terminal
state (Wine prefix, MT5 install, logs) lives on a named volume. Details and diagrams:
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Quickstart (DEMO)

Everything below uses placeholders. Values in angle brackets are yours. No step here has been run
against the current template in a container; see "Not proven" above.

```bash
# 1. Configure: create a config dir from the skeleton (DEMO names only), then edit it.
tools/mt5ctl new /srv/<root>/instances/mt5-<broker>-demo-<id> mt5-<broker>-demo-<id>
$EDITOR /srv/<root>/instances/mt5-<broker>-demo-<id>/instance.yaml
#    Set broker_server (an alias, never an address), image (an explicit built tag), servers_dat,
#    secrets.dir. Remove nothing else; unknown keys are rejected.

# 2. Provision the three secrets outside the repository (names and modes: docs/OPERATOR-GUIDE.md).
install -d -m 0700 /srv/<root>/secrets/mt5-<broker>-demo-<id>

# 3. Lint, then render (render lints again, writes rendered/instance.env, runs `docker compose config`).
tools/mt5ctl lint   /srv/<root>/instances/mt5-<broker>-demo-<id>/instance.yaml
tools/mt5ctl render /srv/<root>/instances/mt5-<broker>-demo-<id>/instance.yaml

# 4. Start (manual; mt5ctl has no up/down wrapper). Owner-approved step.
docker compose --env-file /srv/<root>/instances/mt5-<broker>-demo-<id>/rendered/instance.env \
  -f deploy/compose.instance.yml up -d
#    add: -f deploy/compose.operator-ui.yml   when ports.operator_ui is a number

# 5. Verify: what can be checked today is manual (container health, log lines, listeners, the UI's
#    401 challenge). There is no `mt5ctl verify`. See docs/OPERATOR-GUIDE.md section 7.

# 6. Operate: logs and restart are plain docker commands. Stopping never closes positions.
docker logs <instance> --tail 50
docker restart <instance>

# 7. Stop (volume is kept; do not add -v unless you are retiring the instance).
docker compose --env-file .../rendered/instance.env -f deploy/compose.instance.yml down
```

A second DEMO account is a second config dir and a second secrets dir; no source file is edited
([docs/OPERATOR-GUIDE.md](docs/OPERATOR-GUIDE.md) section 9).

## Safety summary

- DEMO only: `mt5ctl new` creates only `demo` names; lint refuses any DEMO config carrying a LIVE flag;
  `render` refuses LIVE outright. This is a configuration gate, not an in-container control. The
  terminal will log into whatever account its credentials open.
- Secrets live in a mode-0700 directory outside the repository and are mounted as Compose file
  secrets. Lint checks names, types, modes and emptiness but never reads values. Never put credentials
  in `instance.yaml`, `instance.env`, compose files, commands or commit messages.
- The bridge port is not published. Do not publish it, do not attach other containers to an instance
  network, and do not give anything else access to the instance network.
- The browser UI is plain HTTP with Basic Auth. Lint only allows a loopback bind; reach it through an
  SSH tunnel, never directly over a network.
- Known unresolved hazards (passwordless sudo for the runtime user, VNC auth fails open if its secret
  is missing, unauthenticated bridge) are recorded and pinned by strict expected-failure tests.
- Instances default to `restart: "no"`: after a host reboot or daemon restart they stay down.

## Documentation map

| Document | Purpose |
|---|---|
| [docs/OPERATOR-GUIDE.md](docs/OPERATOR-GUIDE.md) | Deployment and day-to-day operation, secrets, network binding, restart/stop, second account, retiring |
| [docs/CONFIG-REFERENCE.md](docs/CONFIG-REFERENCE.md) | Authoritative `instance.yaml` reference, lint rules, LIVE refusal matrix, examples |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Components, trust boundaries, diagram, ADR-MT5-001 target vs what exists, TRON attachment (not implemented) |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Symptom, cause, check, fix, with unverified items marked |
| [docs/RECOVERY.md](docs/RECOVERY.md) | Instance recovery and source recovery (bundle and `reconcile/pre/*` tags) |
| [docs/KNOWN-LIMITATIONS.md](docs/KNOWN-LIMITATIONS.md) | Deferred hazards and gaps, each with its planned increment |
| [docs/EVIDENCE-INDEX.md](docs/EVIDENCE-INDEX.md) | Every historical work-order record: what it claimed, what it proves, status |
| [docs/ERRATA.md](docs/ERRATA.md) | Dated corrections to historical records (which are preserved unedited) |
| [docs/DESIGN.md](docs/DESIGN.md) | Historical design export (2026-05-13). Provenance only, not the current specification |
| [docs/TEMPLATE-CONFIG.md](docs/TEMPLATE-CONFIG.md) | Pointer to the config reference |
| `docs/evidence/` | Historical work-order records. Never edited; corrections go in ERRATA |

## Repository layout

| Path | Contents |
|---|---|
| `Dockerfile`, `start.sh`, `bridge/rpyc_server.py` | The image: build recipe, container entrypoint, RPyC bridge |
| `deploy/compose.instance.yml`, `deploy/compose.operator-ui.yml` | Parametrised Compose template and the optional loopback UI overlay |
| `schemas/mt5-instance.schema.json` | Normative `instance.yaml` schema (`mt5-instance/1`) |
| `tools/mt5ctl` | `new`, `lint`, `render`; stdlib-only, no container start, no broker contact |
| `instances/_skeleton/instance.yaml` | Fake-valued skeleton copied by `mt5ctl new` |
| `tests/` | `python3 -m pytest -q tests` |
| `.gitleaks.toml`, `scripts/hooks/pre-commit` | Secret scanning rules and hook; this is a public repository |

Public repository rules: no real broker server addresses, internal IPs, account numbers, credentials
or host-specific paths in committed files outside `docs/evidence/`. Documentation uses placeholders and
RFC 5737 example ranges. `docs/evidence/` is preserved as a historical record (never edited) and
**does** contain internal addresses and some secret-length and user details, as noted in the
maintainers' audit; see [docs/ERRATA.md](docs/ERRATA.md) and
[docs/KNOWN-LIMITATIONS.md](docs/KNOWN-LIMITATIONS.md). Do not copy values from it into other files.
