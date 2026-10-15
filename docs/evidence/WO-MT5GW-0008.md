# WO-MT5GW-0008 — KasmVNC login via provisioned Basic Auth (replaces WO-0007's approach)

All work on dell-debian. No account identifiers, no secret values, no internet-reachable IPs appear below.

## Why WO-MT5GW-0007's fix was not the real answer

WO-MT5GW-0007 correctly found that KasmVNC's HTTP/websocket layer (Basic Auth, `WWW-Authenticate:
Basic realm="Websockify"`) was rejecting every browser connection because its password store
(`KasmPasswordFile`) was never provisioned. Its fix disabled that layer (`-disableBasicAuth`) and
relied solely on classic `VncAuth`/`PasswordFile` instead.

Testing that fix against a real browser surfaced a second, deeper problem: **the bundled KasmVNC
web client (`ui-D357AMxM.js`) does not support classic "Std VNC Auth" (RFB security type 2,
`VncAuth`) at all.** Its handshake function for that security type is a stub:

```js
_negotiateStdVNCAuth(){
  if(this._sock.rQwait("auth challenge",16))return!1;
  this._rfbCredentials.password="";   // <-- hardcoded empty, always
  const e=..., t=We.genDES(this._rfbCredentials.password,e);
  return this._sock.send(t), this._rfbInitState="SecurityResult", !0
}
```

It hardcodes the password to an empty string and never fires a `credentialsrequired` event for this
security type — no prompt is ever shown, and authentication always fails. Confirmed live in
`wine.log`: `AuthFailureException: Authentication failure` within ~13ms of connection accept, before
any real challenge-response could have occurred, with no HTTP-layer or RFB-layer prompt reaching the
browser at all. This matches exactly what Matt reported: "connection rejected, authentication
failure... there was no login prompt offered."

The client *does* implement a real, working `credentialsrequired` (username + password) flow, but
only for a different RFB security type: `Plain` (via VeNCrypt subtype 256). Server-side, `Xvnc`
supports `-SecurityTypes Plain` + `-PlainUsers`, but that path authenticates via PAM against a real
Linux system account's password — a materially different, more invasive mechanism (a real OS login
credential, not an isolated app-specific one) that Matt explicitly declined in favour of the option
below.

## Decision (Matt, this WO)

Do not use Plain/PAM or set any Unix account password. Revert WO-0007's `-disableBasicAuth` in the
credentialed branch. Provision KasmVNC's own native Basic Auth instead — this is the layer the
browser's login prompt was always actually driven by, and the one gap was simply that it was never
provisioned with real credentials.

## Fix

`start.sh`, credentialed branch:

- Replaced `render_vnc_password()` (classic `vncpasswd`/`PasswordFile`/`VncAuth`, now known
  non-functional against this client) with `render_kasm_basicauth_password()`, which generates
  KasmVNC's own `KasmPasswordFile` via `kasmvncpasswd -u matt -w -o ...` from the same
  `/run/secrets/vnc_password` secret (double-piped per `kasmvncpasswd`'s own documented
  non-interactive usage, same normalisation pattern as WO-MT5GW-0003). Written to tmpfs only,
  owned by the Xvnc user (`headless`, the process's own user — no chown needed), mode `0600`
  (`chmod` applied explicitly). Never logs or prints the password.
- `matt` is a **VNC-only Basic-Auth username** managed entirely inside `kasmvncpasswd`'s own store —
  it is not an OS account and has no relation to any Linux user on the container.
- Xvnc launch: `-KasmPasswordFile "$KASM_PASSWD_FILE" -SecurityTypes None` (Basic Auth left enabled
  — no `-disableBasicAuth` — since it's now the sole, working login gate; RFB-level security is
  `None` because access is already authenticated by Basic Auth before the websocket upgrade
  completes).
- No-credential branch: unchanged (`-disableBasicAuth -SecurityTypes None`).
- Rebuilt as `mt5-gateway:0.2.0-rc6`; bumped `deploy/compose.instance.yml`'s image tag to match.

## Verification

Redeployed `mt5-vantage-paper` on `rc6`. Confirmed via `pgrep -af Xvnc`:
`-KasmPasswordFile /run/gateway-secrets/kasm.passwd -SecurityTypes None` (no `-disableBasicAuth`).

| Check | Result |
|---|---|
| Unauthenticated GET | `401`, `WWW-Authenticate: Basic realm="Websockify"` present |
| `matt` + correct secret value (read on-host from the secret file, never printed) | `200` |
| `matt` + a deliberately wrong password | `401` |

`start_sh.log`: `"Basic Auth enabled from secret (dev/paper: cleartext HTTP, LAN-only)"`.

Handing back to Matt for the actual browser login test.

## Security note — accepted for dev/paper only, must change before prod

Basic Auth over plain HTTP sends the password in clear text on the LAN (base64-encoded, not
encrypted, in every request). Accepted here because this instance is LAN-only, dev/paper, and this
is an explicit Helm-approved condition for this WO. **Before any prod or internet-reachable use:**
put KasmVNC behind TLS (its own SSL support, `-cert`/`-key`, or a reverse proxy) and keep VNC access
reachable only through a tunnel — never expose Basic Auth over plain HTTP outside a trusted LAN.

This carries forward WO-MT5GW-0007's own security note about the abandoned VncAuth approach for
context only — that mechanism is no longer in use on the credentialed path (RFB security type is
now `None`, gated entirely by Basic Auth instead), so its 8-character DES-key limitation no longer
applies to this instance.

## Scope discipline

No other containers touched (`MT5_Vantage` on either host, `MT5_FundedNext`, `MT5_FTMO_Practice`
all untouched, no restart/exec/config/network changes). No OS account password was set on `headless`
or any other Linux user. No account identifiers, secret values, or internet-reachable addresses
appear in this file, the diff, commit messages, or PR text. Standard branch/PR discipline:
`wo/WO-MT5GW-0008`, stacked on `wo/WO-MT5GW-0007`.
