# WO-MT5GW-0010 — Close R2D2's merge conditions

All work on dell-debian. Pure repo/evidence hygiene ahead of merge — no running instance was
touched or redeployed for this WO (none of the four items below required it).

## 1. Redact broker-server IPs; correct the "no identifiers" claim

`docs/evidence/WO-MT5GW-0006.md` line 3 claimed "No identifiers appear anywhere in this document,"
which was inaccurate: Task 3b's `/proc/net/tcp` output (lines 59-60) recorded two genuine,
internet-routable broker-server IP addresses. Corrected:

- Line 3 now states the accurate scope (no *account* identifiers; the two broker-server IPs are
  redacted below).
- Lines 59-60: the two addresses replaced with `<BROKER_SERVER_IP_1>`/`<BROKER_SERVER_IP_2>`,
  preserving the fact that both connections were observed in `ESTABLISHED` state (the whole point
  of that evidence — a genuine, verified live broker connection, not title-bar/chart-data proof).

**Full repo grep for any other non-private IPv4 address:** every IPv4-shaped string across
`docs/evidence/`, `docs/DESIGN.md`, and `start.sh` was checked. Everything else is either:
- an RFC1918 private/LAN address (`192.168.11.10` — dell-debian itself, already named as such in
  `CLAUDE.md`; `192.168.246.77` — a LAN device, unrelated to MT5, discussed in WO-MT5GW-0002's
  Task 0 stop-hook diagnosis), or
- not actually an IP at all — `10.0.0.0` appearing repeatedly is the Wine package version string
  `wine-stable 10.0.0.0~bookworm-1`, which happens to match the IPv4 regex shape, or
- a bind-all/loopback address (`0.0.0.0`, `127.0.0.1` in `start.sh`'s Xvnc invocation) — not an
  identifier.

No other non-private IPv4 address exists anywhere in the evidence tree. The two broker-server IPs
in WO-MT5GW-0006.md were the only genuine finding.

## 2. Remove `bridge_token`

`bridge_token` was defined in `deploy/compose.instance.yml`'s `secrets:` block from WO-MT5GW-0003
onward but never read, checked, or wired to anything by `start.sh`, `bridge/rpyc_server.py`, or any
other file in the repo (confirmed via a repo-wide case-insensitive grep) — it has been an empty
file on every real instance since it was introduced. Removed both references (the service-level
secret mount and the top-level `secrets:` definition). Compose template re-validated:
`docker compose ... config --quiet` exits clean with the field gone.

No standalone `secrets.example` file exists anywhere in this repo to also update — the only place
`bridge_token` was ever wired was `deploy/compose.instance.yml`, now fixed. (The historical evidence
record `docs/evidence/WO-MT5GW-0003.md`, which correctly noted `bridge_token` was present-but-empty
at that point in time, is left unedited — it is an accurate record of what was true then, not a
description of the current template, and rewriting historical evidence to erase now-obsolete
mentions would itself be a form of evidence tampering.)

**Recorded finding, as instructed:** the bridge is unauthenticated RPyC classic (`SlaveService`),
protected only by compose-network isolation (no host-published port for the bridge — confirmed
throughout WO-MT5GW-0003 through 0008's `/proc/net/tcp` checks: only the KasmVNC web port and the
bridge's internal port are listening, and the bridge port is never in any `ports:` mapping). An
authenticated, typed bridge is deferred to the Forge TRON/bridge work. **MUST be resolved before
prod.**

Matt may delete the now-orphaned empty `bridge_token` file from
`/srv/mt5-gateway-instances/mt5-vantage-paper/secrets/` himself — not touched here, since deleting
files under an instance's `secrets/` directory is Matt's own action per standing practice, not
Helm's.

## 3. Remove the non-existent Fabric doctrine citation

`start.sh`'s `preseed_experts_and_autoupdate()` comment cited `helm:doctrine:wine_mt5_python_api_
gate_and_options_navigation:v1` as the source for including `Account=0`/`Profile=0`/`Chart=0`
alongside the WO's literal `Api=1`/`AllowDllImport=1` minimum. That Fabric key does not exist —
removed the citation, kept the substantive inline explanation (these three persist pre-launch and
defeat MT5's auto-disable triggers that would otherwise flip `Api` back to `0` after a restart),
which stands on its own without needing an external doctrine reference. Checked the rest of the
repo for the same citation or other `helm:doctrine:*`/KRONOS references: `docs/evidence/
WO-MT5GW-0002.md` mentions "prior KRONOS/Helm doctrine" in prose but never cites a specific
(non-existent) Fabric key, so nothing else needed changing there.

## 4. Visibility-change record

**Checked directly against GitHub, not assumed:**

| Repo | `isPrivate` |
|---|---|
| `maff0000/mt5-gateway` | **true** |
| `maff0000/tron` | **false — still public** |

`mt5-gateway` is private. `tron` is not, as of this check. This WO does **not** change `tron`'s
visibility — flipping a repo's visibility is a GitHub admin/settings action, outside the standing
`gh` token risk acceptance's scope (PR operations only on these two repos), and the one narrow
settings exception already granted and used (WO-MT5GW-0006, adding the two deploy keys) does not
cover this. Recorded here as an open gap for Matt to close directly (or explicitly extend the risk
acceptance to cover it) — not silently performed and not silently assumed done.

**Recorded per Matt's instruction — the standing `gh` token risk acceptance's scope is EXTENDED**:
acceptable to use the broad token as already scoped (PR operations only on `maff0000/mt5-gateway`
and `maff0000/tron`, plus the one already-used deploy-key exception) **only up to the point live
broker credentials are ever introduced to any instance** — at which point the risk acceptance must
be revisited before any further use of this token against either repo.

## Scope discipline

No running instance touched, no redeploy performed (none of the four items required it — this WO
is repo/evidence hygiene ahead of merge). No account identifiers, secret values, or (after this WO)
internet-reachable addresses appear in the affected files. `gitleaks` clean. Branch:
`wo/WO-MT5GW-0010`, stacked on `wo/WO-MT5GW-0008` (no `WO-MT5GW-0009` branch or record exists
anywhere in this repo, `/srv/tron`, or the wider `/srv` tree — checked and confirmed empty before
this WO started).
