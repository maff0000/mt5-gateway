# Instance configuration reference

**This is the single authoritative reference** for `instance.yaml`, the lint rules, the LIVE refusal
matrix and the secrets contract (schema `mt5-instance/1`). It consolidates the former
`docs/TEMPLATE-CONFIG.md`, which is now a pointer to this file; nothing from it was dropped. Normative
sources: `schemas/mt5-instance.schema.json` (types and patterns) and `tools/mt5ctl` (cross-field,
LIVE, secrets and peer rules). If this page and the code ever disagree, the code wins; please report
it.

Scope: the minimum reusable-instance contract on top of `deploy/compose.instance.yml`. Credential-free:
nothing here starts a container, contacts a broker or reads a secret value.

## 1. Workflow

```text
tools/mt5ctl new    <dir> mt5-<broker>-demo-<id>   # copy skeleton (DEMO names only)
$EDITOR <dir>/instance.yaml                        # non-secret values only
install -d -m 0700 <secrets.dir>                   # then create the 3 secret files, mode 0600
tools/mt5ctl lint   <dir>/instance.yaml            # schema + cross-field + LIVE + secrets + peers
tools/mt5ctl render <dir>/instance.yaml            # writes rendered/instance.env, runs `docker compose config`
```

`render` only validates (`docker compose config`). Bringing an instance up is deliberately not wrapped;
it remains a manual, owner-approved step ([OPERATOR-GUIDE.md](OPERATOR-GUIDE.md) section 7).

Commands and flags:

| Command | Flags | Notes |
|---|---|---|
| `mt5ctl new <dest-dir> <name>` | `--force` | name must match `mt5-<broker>-demo-<id>`; refuses an existing `instance.yaml` without `--force` |
| `mt5ctl lint <instance.yaml>` | `--peers FILE...`, `--skip-fs` | default peers: sibling directories of the instance dir that contain `instance.yaml`, names not starting with `_`. Exit 1 on any error |
| `mt5ctl render <instance.yaml>` | `--out DIR`, `--peers FILE...`, `--no-docker` | default output `<instance-dir>/rendered/`. Runs full lint first. `--no-docker` skips `docker compose config` |

## 2. File format

A strict YAML subset: nested maps, scalars, `#` comments, two-space indentation. Lists, flow style,
anchors, tabs, duplicate keys, empty values and multi-document files are errors. Quote strings that
would otherwise parse as a number or boolean (the skeleton quotes `"no"`).

Decision: `tools/mt5ctl` is stdlib-only, so no PyYAML dependency or install step is required; the JSON
Schema is the normative contract, and a test cross-checks the built-in validator against `jsonschema`
when it is installed. Unknown keys are rejected at every level.

## 3. Fields

All example values are fake. Required unless marked optional.

| Field | Type / pattern | Rule | Becomes |
|---|---|---|---|
| `schema` | const `mt5-instance/1` | exact | n/a |
| `instance_name` | `^mt5-[a-z0-9]+-(demo\|live)-[a-z0-9]{1,16}$` | `mt5-<broker>-<demo\|live>-<id>`; compose project, container name and prefix of volume and network. Third segment must equal `environment` in lower case | `INSTANCE_NAME`, label `mt5gateway.instance` |
| `broker_label` | `^[a-z0-9]{2,24}$` | must equal the broker segment of the name | `BROKER`, label `mt5gateway.broker` |
| `broker_server` | `^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$` | a server alias, not an address. Anything shaped like an IPv4 address or ending in `:port` is rejected | `MT5_SERVER`, written into the terminal start config |
| `environment` | `DEMO` or `LIVE` | see matrix below; LIVE is refused | `ENVIRONMENT`, label `mt5gateway.environment` |
| `account_class` | `demo-unfunded`, `demo-simulated-capital`, `live-capital` | `DEMO` requires a `demo-*` class, `LIVE` requires `live-capital` | n/a |
| `image` | `^[a-z0-9][a-z0-9._/-]*(:[A-Za-z0-9._-]+\|@sha256:<64 hex>)$`, max 200 | explicit tag or digest; never `:latest`; a bare name with no tag is an error. The skeleton uses a CANDIDATE tag that does not exist yet | `IMAGE_REF` |
| `restart` (optional) | `no`, `on-failure`, `unless-stopped` | default `no` (quote it) | `RESTART_POLICY` |
| `network.name` | `^mt5-[a-z0-9-]{3,60}$` | must start with `<instance_name>-`; per-instance bridge network created by Compose | `NETWORK_NAME` |
| `network.bind` | `127.0.0.1` or `::1` | the only addresses a UI port may bind; no wildcard exists in the schema | `OPERATOR_UI_BIND` |
| `ports.operator_ui` | `none`, or an integer 1024 to 65535 | `none` publishes nothing. A number publishes container port 6901 on `network.bind:<port>` via `deploy/compose.operator-ui.yml` | `OPERATOR_UI_PORT` |
| `data_volume` | `^mt5-[a-z0-9-]{3,60}$` | must start with `<instance_name>-`; mounted at `/home/headless` | `DATA_VOLUME` |
| `limits.memory_mb` | integer 512 to 16384 | hard memory limit | `MEM_LIMIT_MB` |
| `limits.cpus` | number 0.25 to 8 | CPU limit | `CPUS` |
| `limits.pids` | integer 64 to 4096 | process limit | `PIDS_LIMIT` |
| `timezone` | `^[A-Za-z][A-Za-z0-9_+/-]{1,40}$` | container TZ | `TZ` |
| `servers_dat` | absolute path `^/[A-Za-z0-9_./-]+$` | host path of the shared `servers.dat` seed; no `..`; outside the repository. Existence is not checked | `SERVERS_DAT` |
| `log_level` (optional) | `DEBUG`, `INFO`, `WARNING`, `ERROR` | default `INFO` | `LOG_LEVEL` |
| `secrets.dir` | absolute path `^/[A-Za-z0-9_./-]+$` | see secrets contract | `SECRETS_DIR` |
| `live.enable`, `live.capital_gate_marker`, `live.live_capable_build` (optional block) | boolean, absolute path, boolean | see LIVE matrix; must be absent (or `enable: false` only) for DEMO | n/a |

`render` also sets `EXPECTED_TRADE_MODE` (`DEMO` for DEMO, `REAL` otherwise). The whole generated
`instance.env` is passed to the container as environment variables (compose `env_file`) and contains no
secrets.

**What actually consumes these values.** The Compose template uses the image, restart policy,
network, volume, limits, `TZ`, seed path, secrets directory and the three labels. Inside the container,
`start.sh` reads `MT5_SERVER` and (optionally) `SCREEN_RESOLUTION`. `LOG_LEVEL`, `EXPECTED_TRADE_MODE`,
`BROKER` and `ENVIRONMENT` are present in the container environment but are **not read by `start.sh`
or the bridge**: in particular nothing asserts the trade mode at runtime (see
[KNOWN-LIMITATIONS.md](KNOWN-LIMITATIONS.md)). `SCREEN_RESOLUTION` has no `instance.yaml` field.

## 4. Secrets contract

`secrets.dir` (mode 0700) holds exactly three files, mode 0600, non-empty, regular (no symlinks):
`mt5_login`, `mt5_password`, `vnc_password`. These are the names the existing `start.sh` reads from
`/run/secrets/`, so no application source changed. (The design doc proposed one `mt5.secrets` file; that
needs an entrypoint change and is deferred.) Lint checks names, types, modes and emptiness only; values
are never read, printed, rendered into `instance.env`, or placed in compose. Lint does not check file
ownership. `secrets.dir` must not contain `..`, must not be inside the repository, and must not be the
instance's config directory, inside it, or contain it. A missing directory is an error. Providing and
using them: [OPERATOR-GUIDE.md](OPERATOR-GUIDE.md) section 4.

## 5. Lint rules

1. Schema and unknown-key rejection (types, patterns, ranges above).
2. Name, broker and environment consistency; volume and network prefixed by the instance name; image
   tag rule; `broker_server` not an address; `servers_dat` outside the repository and without `..`.
3. LIVE refusal (matrix below).
4. Secrets contract (above), directory not in the repository or config directory.
5. No wildcard binds (schema enum), and explicit disjointness against peers on project, container,
   network, volume, secrets directory and published port. Secrets directories are compared after
   path normalisation (`realpath`: trailing slash, `//`, `/./`, symlinked parents) and are rejected when
   equal **or nested** (one inside the other). Default peers are sibling directories of the
   instance directory. `--skip-fs` skips the secrets filesystem checks only and says so.

Peer disjointness is evaluated across the configs given to lint, not against Docker state on the host.

## 6. LIVE refusal matrix

| `environment` | Other inputs | Result |
|---|---|---|
| `DEMO` | no `live` block, or `live: {enable: false}` only | lint passes this rule |
| `DEMO` | any of `live.enable: true`, a `capital_gate_marker` key, `live_capable_build: true` | lint error: "DEMO instance must not carry live flags" |
| `LIVE` | `account_class` not `live-capital` | lint error |
| `LIVE` | `live.enable` not `true` | lint error (default refusal) |
| `LIVE` | `live_capable_build` not `true`, or image tag does not contain `live-capable` | lint error |
| `LIVE` | no `capital_gate_marker`, or the file is missing, empty, not a regular file, not root-owned, or not mode 0444 | lint error |
| `LIVE` | every condition above satisfied | lint can pass, but **`render` still refuses** (`LIVE_PROVISIONING_ENABLED = False`) |
| any | `mt5ctl new` with a `live` name | refused: `new` only creates DEMO names |

The LIVE marker file check runs even with `--skip-fs`. The printed warning (corrected after the audit,
finding F15) says so: secrets directory/file checks are skipped, the capital-gate marker check still runs.
When a LIVE config passes lint, lint prints a `WARNING` that `render` will still refuse it (finding F3).

This is a **configuration and lint gate only**. The image contains no environment guard: whatever
credentials the secret files hold are what the terminal will use. Nothing in the container asserts the
account is DEMO.

## 7. Examples (fake values)

Minimal valid DEMO config (the skeleton, `instances/_skeleton/instance.yaml`, with an operator UI):

```yaml
schema: mt5-instance/1
instance_name: mt5-example-demo-a1
broker_label: example
broker_server: ExampleBroker-Demo      # a server alias, never an address
environment: DEMO
account_class: demo-unfunded
image: mt5-gateway:0.3.0-example       # an explicit tag you built; never :latest
restart: "no"
network:
  name: mt5-example-demo-a1-net
  bind: 127.0.0.1
ports:
  operator_ui: 3901                    # published on 127.0.0.1:3901 only
data_volume: mt5-example-demo-a1-data
limits:
  memory_mb: 2048
  cpus: 1.5
  pids: 512
timezone: Etc/UTC
servers_dat: /srv/example/_shared/servers.dat
secrets:
  dir: /srv/example/secrets/mt5-example-demo-a1
```

Typical lint errors and what they mean:

| Message fragment | Cause |
|---|---|
| `unknown key 'x'` | key not in the schema |
| `missing required key` | a required field is absent |
| `instance_name environment segment must equal environment` | name says `demo` but `environment: LIVE`, or the reverse |
| `broker segment must equal broker_label` | name and label disagree |
| `must start with '<instance_name>-'` | `data_volume` or `network.name` lacks the prefix |
| `image must carry an explicit non-latest tag or digest` | `:latest` or a bare image name |
| `broker_server must be an alias, not an address` | IPv4-shaped value or trailing `:port` |
| `secrets.dir ... does not exist` / `mode is ..., must be 0700` | directory missing or wrong mode |
| `secret X is missing` / `is empty` / `mode ..., must be 0600` | secret file problems |
| `unexpected entry 'Y' in secrets.dir` | a file with a name other than the three allowed |
| `collides with peer ... on <field>` | another instance config uses the same name, network, volume, secrets directory or UI port |

Network example ranges: if you need to write an address in an example, use RFC 5737 blocks
(`192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24`); never a real address.

## 8. Differences from the pre-template compose file

See the header of `deploy/compose.instance.yml`. Default behaviour is preserved (restart `no`, same
volume name rule, same container name, same secret names) except: no ports unless the loopback overlay
is added, explicit network name, `cpus`/`pids_limit` added, image is a parameter.

**`instance.env` is injected whole.** The compose `env_file` passes every line of the generated
`instance.env` into the container environment, including host-side path variables (`SECRETS_DIR`,
`SERVERS_DAT`, `INSTANCE_ENV_FILE`) that only compose needs. No secret values are among them, but the host
path layout is visible to anything in the container (finding F6; listed in KNOWN-LIMITATIONS).

**Migration note for existing instances.** The template is not a drop-in for the previous compose
file. Before recreating an existing instance from it:

- `IMAGE_REF` is required (no default image); set `image` in `instance.yaml`.
- There are no default ports. The UI is published only if `ports.operator_ui` is set, on loopback only;
  an instance that was published on another address will lose that publication.
- The network gets an explicit name (`network.name`) instead of the project-scoped `instance-net`;
  recreating creates a new network and the old one is left behind.
- The data volume name is `data_volume` (must start with `<instance_name>-`); if it differs from the
  existing volume, the terminal state will not be found. Match the existing volume name or migrate the data.
- The secrets path is a parameter (`secrets.dir`, mode 0700, files 0600, outside the repository and the
  config directory); the old per-instance `secrets` location is not read.
- `cpus` and `pids_limit` are new and untested under Wine/MetaTrader; `servers.dat` and `TZ` are
  parameters. Run `mt5ctl render` and compare with `docker compose config` of the old file before any
  `up`.

## 9. Known deferred hazards

Explicit allow-list in `tests/test_static_security.py`, strict xfail: if one is fixed the suite fails
until the allow-list is updated.

| Id | Hazard |
|---|---|
| H1 | Runtime user has NOPASSWD sudo (Dockerfile) |
| H2 | `start.sh` runs VNC without auth if the `vnc_password` secret is absent (lint requires the secret; publishing is loopback-only) |
| H3 | RPyC SlaveService unauthenticated on 0.0.0.0 inside the container (never published) |

Full list with planned increments: [KNOWN-LIMITATIONS.md](KNOWN-LIMITATIONS.md).

## 10. NOT yet proven

- No container was built or started from this template; `docker compose config` proves interpolation
  only, not that two instances run side by side, that the ports bind, or that secrets mount.
- The skeleton image tag is a CANDIDATE placeholder. `rc6` remains historical rollback evidence only and
  is not relabelled. The image build is not hermetic (apt/wget/git clone at build time, Wine, KasmVNC
  and noVNC pins by version not digest; base image `debian:12-slim` by tag); reproducibility is not
  proven.
- The LIVE gate is a configuration/lint gate only; no in-container enforcement exists in this effort.
- Disjointness is enforced across configs given to lint (siblings by default), not against Docker state
  on the host (`docker volume ls`/`network ls`).
- Single-secrets-file, healthcheck/verify, gateway allow-list, restart/stop semantics from the design
  contract are not implemented. Actions are pinned by commit SHA; Python test deps by version only.
