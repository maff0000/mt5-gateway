# WO-MT5GW-0007 — Fix KasmVNC browser login rejecting all credentials

All work on dell-debian. No account identifiers, no secret values, no internet-reachable IPs appear below.

## Symptom

`mt5-vantage-paper` (LAN-only, `192.168.11.10:3021`) rejected every browser login attempt with
username `headless` + the `vnc_password` secret value, surfacing to the browser as "This page is
not working at the moment."

## Root cause

KasmVNC's `Xvnc` exposes **two independent authentication layers**:

- `PasswordFile` / `SecurityTypes VncAuth` — the classic RFB "VNC Authentication" security type,
  checked when a client actually connects to the VNC session.
- `KasmPasswordFile` (default `~/.kasmpasswd`, created with `kasmvncpasswd`) — a **separate** HTTP
  Basic-Auth store gating the websocket/HTTP layer, controlled by `DisableBasicAuth` (default `0`,
  i.e. **on**).

`start.sh`'s credentialed branch only ever configured the first layer (`-SecurityTypes VncAuth
-PasswordFile ...`). `KasmPasswordFile` was never provisioned, and `DisableBasicAuth` was left at
its default of `0` in that branch (it was only explicitly disabled in the *no-credential* fallback
branch). Result: every browser connection was rejected by the unprovisioned Basic-Auth layer before
VncAuth was ever reached — no password could ever succeed. Confirmed live: an unauthenticated GET
against the running instance returned `401 Unauthorized` with `WWW-Authenticate: Basic
realm="Websockify"`; a GET with a deliberately wrong Basic-Auth credential returned a bare `401
Forbidden` with **no** `WWW-Authenticate` header and an immediately-closed connection with no body
— exactly what a browser renders as a dead page rather than a re-prompt.

`render_vnc_password()` itself, the tmpfs mount, and file ownership were all confirmed correct on
the live container before this fix (password file present, correct size/owner/mode, generated at
the exact container-start timestamp, "VncAuth enabled from secret" logged) — the bug was purely the
missing `-disableBasicAuth` flag in the credentialed branch, not the password-rendering path.

## Fix

`start.sh`, credentialed branch: added `-disableBasicAuth` alongside the existing `-SecurityTypes
VncAuth -PasswordFile "$VNC_PASSWD_FILE"`, matching what the no-credential fallback branch already
did. Rebuilt as `mt5-gateway:0.2.0-rc5`; bumped `deploy/compose.instance.yml`'s image tag to match.

## Verification

- Redeployed `mt5-vantage-paper` on `rc5`. Confirmed via `pgrep -af Xvnc`: process now launches with
  `-disableBasicAuth -SecurityTypes VncAuth -PasswordFile ...` together.
- Unauthenticated `curl` GET against the instance: `HTTP/1.1 200 OK`, full page body served
  (68800 bytes) — no `401`, no Basic-Auth challenge. Previously this same request returned `401
  Unauthorized`.
- `start_sh.log`: `"VncAuth enabled from secret, BasicAuth disabled (dev/LAN/paper only)"`.
- Handing back to Matt for the actual browser login test (VncAuth password prompt inside the
  KasmVNC page itself, not a browser-native Basic-Auth popup).

## Security note — accepted for dev/LAN/paper only, must change before prod

With Basic Auth disabled, access relies solely on classic VncAuth: a DES challenge-response scheme
where **only the first 8 characters of the password are cryptographically significant** (RFB
protocol definition, not a KasmVNC-specific limitation) and the underlying DES challenge-response
is itself weak by modern standards. Accepted here because this instance is LAN-only, dev/paper, and
matches an explicit Helm-approved condition for this WO.

**Confirmed against the real instance, length only, no characters read or logged:** the real
`vnc_password` secret is 10 characters. Since this exceeds 8, **only the first 8 characters are
actually significant for login** — Matt should know the effective password is its first 8
characters, not the full 10 he set.

**Before any prod or internet-reachable use:** provision KasmVNC's own Basic-Auth store
(`KasmPasswordFile`, via `kasmvncpasswd`) from the secret instead of disabling it, serve over HTTPS,
and keep VNC access reachable only through a tunnel — never expose `-disableBasicAuth` outside a
trusted LAN.

## Scope discipline

No other containers touched (`MT5_Vantage` on either host, `MT5_FundedNext`, `MT5_FTMO_Practice`
all untouched, no restart/exec/config/network changes). No account identifiers, secret values, or
internet-reachable addresses appear in this file, the diff, commit messages, or PR text. Standard
branch/PR discipline: `wo/WO-MT5GW-0007`, stacked on `wo/WO-MT5GW-0006`.
