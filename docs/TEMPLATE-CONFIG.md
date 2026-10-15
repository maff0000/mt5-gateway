# Template configuration reference (MT5GW-TEMPLATE-001)

Minimum reusable-instance contract on top of `deploy/compose.instance.yml`. Credential-free:
nothing here starts a container, contacts a broker or reads a secret value.

## Workflow

```
tools/mt5ctl new    <dir> mt5-<broker>-demo-<id>   # copy skeleton (DEMO names only)
$EDITOR <dir>/instance.yaml                        # non-secret values only
install -d -m 0700 <secrets.dir>                   # then create the 3 secret files, mode 0600
tools/mt5ctl lint   <dir>/instance.yaml            # schema + cross-field + LIVE + secrets + peers
tools/mt5ctl render <dir>/instance.yaml            # writes rendered/instance.env, runs `docker compose config`
```

`render` only validates (`docker compose config`). Bringing an instance up is deliberately not
wrapped; it remains a manual, owner-approved step.

## instance.yaml (schema: `schemas/mt5-instance.schema.json`, `schema: mt5-instance/1`)

Unknown keys are rejected at every level. All values are fake in the skeleton.

| Field | Rule |
|---|---|
| `instance_name` | `mt5-<broker>-<demo\|live>-<id>`; becomes compose project, container name and prefix of volume/network |
| `broker_label` | must equal the broker segment of the name |
| `broker_server` | broker server alias (not an address) |
| `environment` / `account_class` | `DEMO`/`LIVE`; `DEMO` requires `demo-*`, `LIVE` requires `live-capital` |
| `image` | explicit tag or digest, never `:latest`. Skeleton uses a CANDIDATE tag (not yet built) |
| `restart` | `no` (default, same as before) \| `on-failure` \| `unless-stopped` |
| `network.name` / `network.bind` | per-instance bridge network (`<instance_name>-...`); bind only `127.0.0.1` or `::1` |
| `ports.operator_ui` | `none` or a host port >=1024, published on `network.bind` only |
| `data_volume` | must start with `<instance_name>-` |
| `limits.memory_mb/cpus/pids` | hard limits |
| `timezone`, `log_level` | container TZ; log level (optional) |
| `servers_dat` | absolute host path of the shared `servers.dat` seed, outside the repo |
| `secrets.dir` | absolute path, outside the repo and outside the config dir |
| `live.*` | see below; must be absent (or `enable: false`) for DEMO |

Format: a strict YAML subset (nested maps, scalars, `#` comments). Lists, flow style, anchors, tabs,
duplicate keys and multi-documents are errors. Decision: `tools/mt5ctl` is stdlib-only, so no PyYAML
dependency or install step is required; the JSON Schema is the normative contract and a test
cross-checks the built-in validator against `jsonschema` when it is installed.

## Secrets contract

`secrets.dir` (mode 0700) holds exactly three files, mode 0600, non-empty, regular (no symlinks):
`mt5_login`, `mt5_password`, `vnc_password`. These are the names the existing `start.sh` reads from
`/run/secrets/`, so no application source changed. (The design doc proposed one `mt5.secrets` file;
that needs an entrypoint change and is deferred.) lint checks names, types, modes and emptiness only;
values are never read, printed, rendered into `instance.env`, or placed in compose.

## Lint rules

1. Schema + unknown-key rejection.
2. Name/broker/environment consistency; volume and network prefixed by instance name; image tag rule;
   `broker_server` not an address; `servers_dat` outside the repo.
3. LIVE refusal. DEMO with any live flag fails. LIVE requires ALL of: `account_class: live-capital`,
   `live.enable: true`, `live.capital_gate_marker` (existing, non-empty, root-owned, 0444),
   `live.live_capable_build: true` and an image tag containing `live-capable`. Even then `render`
   refuses LIVE (`LIVE_PROVISIONING_ENABLED = False`) and `new` only creates DEMO names.
4. Secrets contract (above), dir not in repo or config dir.
5. No wildcard binds (schema enum), explicit disjointness against peers (project, container, network,
   volume, secrets dir, published port). Default peers are sibling dirs of the instance dir.
   `--skip-fs` skips filesystem checks (used for the skeleton in CI) and says so.

## Differences from the pre-template compose file

See the header of `deploy/compose.instance.yml`. Default behaviour is preserved (restart `no`, same
volume name rule, same container name, same secret names) except: no ports unless the loopback overlay
is added, explicit network name, `cpus`/`pids_limit` added, image is a parameter.

## Known deferred hazards (explicit allow-list in `tests/test_static_security.py`, strict xfail)

| Id | Hazard |
|---|---|
| H1 | Runtime user has NOPASSWD sudo (Dockerfile) |
| H2 | start.sh runs VNC without auth if the vnc_password secret is absent (lint requires the secret; publishing is loopback-only) |
| H3 | RPyC SlaveService unauthenticated on 0.0.0.0 inside the container (never published) |

## NOT yet proven

- No container was built or started; `docker compose config` proves interpolation only, not that two
  instances run side by side, that the ports bind, or that secrets mount.
- The skeleton image tag is a CANDIDATE placeholder. rc6 remains historical rollback evidence only and
  is not relabelled. The image build is not hermetic (apt/wget/git clone at build time, Wine/KasmVNC/noVNC
  pins by version not digest; base image `debian:12-slim` by tag); reproducibility is not proven.
- The LIVE gate is a configuration/lint gate only; no in-container enforcement exists in this effort.
- Disjointness is enforced across configs given to lint (siblings by default), not against Docker state
  on the host (`docker volume ls`/`network ls`).
- Single-secrets-file, healthcheck/verify, gateway allow-list, restart/stop semantics from the design
  contract are not implemented. Actions are pinned by commit SHA; Python test deps by version only.
