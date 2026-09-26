#!/bin/bash
# mt5-gateway start.sh (KasmVNC variant, imported from trinity-mt5-image).
# Launches KasmVNC's Xvnc directly with gmag11-style args (single architectural
# change vs 0.1.2 — TigerVNC standalone replaced by KasmVNC Xvnc).
# WO-MT5GW-0002 Task 3: pre-seeds/reasserts [Common] AutoUpdate=0 and the
# [Experts] Python-API gate (Api=1, AllowDllImport=1) before every launch —
# see the comment on preseed_experts_and_autoupdate() below for why.
# WO-MT5GW-0003 Task 0: reads credentials from Docker secrets
# (/run/secrets/mt5_login, mt5_password, vnc_password) instead of expecting
# a pre-rendered mt5.ini bind-mount or an env-var VNC password — see
# render_mt5_ini_from_secrets() and render_vnc_password() below.

# === Step 0 — IME hardening ===
unset XMODIFIERS GTK_IM_MODULE QT_IM_MODULE XIM XIM_PROGRAM

WINE_LOG="/tmp/wine.log"
START_LOG="/tmp/start_sh.log"
RPYC_LOG="/tmp/rpyc_server.log"
> "$WINE_LOG"; > "$START_LOG"; > "$RPYC_LOG"

redact() { sed -E 's/(Password|MT5_FTMO_PRACTICE_PASSWORD)=[^[:space:]]*/\1=<REDACTED>/gi'; }

VNC_PORT=5901
WEBSOCKET_PORT=6901
DISPLAY_NUM=1
RESOLUTION="${SCREEN_RESOLUTION:-1280x800}"

MT5_INSTALLER="/home/headless/mt5setup.exe"
MT5_INSTALLER_URL="https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"
MT5_DIR="/home/headless/.wine/drive_c/Program Files/MetaTrader 5"
MT5_EXE="$MT5_DIR/terminal64.exe"
MT5_MQL5_FILES="$MT5_DIR/MQL5/Files"
MT5_COMMON_INI="$MT5_DIR/Config/common.ini"

WINE_PY_INSTALLER="/tmp/python-installer.exe"
WINE_PY_URL="https://www.python.org/ftp/python/3.9.13/python-3.9.13.exe"
WINE_PY_BIN="C:\\Program Files (x86)\\Python39-32\\python.exe"

# === WO-MT5GW-0003 Task 0 — secrets wiring ===
# Everything rendered from /run/secrets/* goes to tmpfs ONLY, never into the
# persistent /home/headless volume, and is never echoed/logged — only
# generic status lines via step(). If a secret is absent/empty the container
# still boots (no-credential mode, same as every T0-T2 test so far); it just
# skips the credentialed launch / VNC-auth steps below.
GATEWAY_SECRETS_DIR="/run/gateway-secrets"
RENDERED_MT5_INI="$GATEWAY_SECRETS_DIR/mt5.ini"
WIN_RENDERED_MT5_INI="Z:\\run\\gateway-secrets\\mt5.ini"
VNC_PASSWD_FILE="$GATEWAY_SECRETS_DIR/vnc.passwd"

step() { echo "[$(date -u +%FT%TZ)] $1" | tee -a "$START_LOG"; }
fail() { echo "[$(date -u +%FT%TZ)] FAIL $1" | tee -a "$START_LOG" >&2; exit 1; }

# Renders the KasmVNC VncAuth password file from /run/secrets/vnc_password.
# Never prints the value; feeds it to vncpasswd twice (password + confirm)
# via a pipe, per vncpasswd's own documented non-interactive usage.
render_vnc_password() {
    local src="/run/secrets/vnc_password"
    # Docker Compose (non-Swarm) mounts secrets root:root mode 0400, always
    # -- its uid/gid/mode override syntax is silently ignored on this driver
    # (confirmed live). headless (this process's user) has passwordless
    # sudo (see the Dockerfile), so read via that instead of plain cat.
    sudo test -s "$src" || return 1
    mkdir -p "$GATEWAY_SECRETS_DIR"
    # printf normalises to exactly one trailing newline per entry regardless
    # of whether the secret file itself ends in one -- a raw `cat "$src"; echo`
    # double-newlines when the file already has a trailing \n, which makes
    # vncpasswd see a spurious blank third line and report "Passwords don't
    # match" (found + fixed during the real WO-MT5GW-0003 Task 1 run).
    { printf "%s\n" "$(sudo cat "$src")"; printf "%s\n" "$(sudo cat "$src")"; } | vncpasswd -u headless -w -r "$VNC_PASSWD_FILE" >/dev/null 2>&1
    [ -s "$VNC_PASSWD_FILE" ]
}

# The tmpfs mount at $GATEWAY_SECRETS_DIR is created root:root mode 0700 by
# Docker (its `mode=` tmpfs option only sets mode, not ownership) -- headless
# (this process's user) has zero access to it at all otherwise. Fix
# ownership once, up front, via headless's passwordless sudo (see the
# Dockerfile), rather than sudo-ing every single file op inside it. Found +
# fixed during the real WO-MT5GW-0003 Task 1 run -- the standalone tests
# that validated render_vnc_password()/render_mt5_ini_from_secrets() used a
# /tmp scratch dir and never exercised this real target path.
sudo mkdir -p "$GATEWAY_SECRETS_DIR"
sudo chown headless:headless "$GATEWAY_SECRETS_DIR"

# === Step 1 — KasmVNC Xvnc (gmag11-style direct invocation) ===
# -httpd /usr/share/kasmvnc/www: without this, -websocketPort only opens a raw
# WebSocket upgrade endpoint -- nothing serves the actual browser client page
# (index.html + JS), so a plain browser/curl GET gets an empty HTTP reply.
# Found live during WO-MT5GW-0005's Config-diff handoff: the port fix
# (5901->6901, WO-MT5GW-0003) was necessary but not sufficient on its own.
mkdir -p ~/.vnc
if render_vnc_password; then
    step "[1/12] Starting KasmVNC Xvnc on :$VNC_PORT (websocket :$WEBSOCKET_PORT) — VncAuth enabled from secret"
    XVNC_SECURITY_ARGS=(-SecurityTypes VncAuth -PasswordFile "$VNC_PASSWD_FILE")
else
    step "[1/12] Starting KasmVNC Xvnc on :$VNC_PORT (websocket :$WEBSOCKET_PORT) — no vnc_password secret, running WITHOUT auth (no-credential test mode only)"
    XVNC_SECURITY_ARGS=(-disableBasicAuth -SecurityTypes None)
fi
Xvnc :$DISPLAY_NUM \
    -PublicIP 127.0.0.1 \
    "${XVNC_SECURITY_ARGS[@]}" \
    -AlwaysShared \
    -geometry "$RESOLUTION" \
    -depth 24 \
    -rfbport $VNC_PORT \
    -websocketPort $WEBSOCKET_PORT \
    -httpd /usr/share/kasmvnc/www \
    -interface 0.0.0.0 \
    -sslOnly 0 \
    -RectThreads 0 \
    -Log "*:stdout:10" \
    >>"$WINE_LOG" 2>&1 &
XVNC_PID=$!
sleep 3
export DISPLAY=:$DISPLAY_NUM
# Readiness check via X socket presence (xset not in image)
for i in {1..20}; do [ -S /tmp/.X11-unix/X$DISPLAY_NUM ] && break; sleep 1; done
[ -S /tmp/.X11-unix/X$DISPLAY_NUM ] || fail "Xvnc did not come up (no X socket)"
step "[1/12] KasmVNC Xvnc OK (pid=$XVNC_PID)"

# === Step 2 — Openbox + tint2 ===
step "[2/12] Starting Openbox + tint2"
openbox >>"$WINE_LOG" 2>&1 &
tint2 >>"$WINE_LOG" 2>&1 &
sleep 1
step "[2/12] WM OK"

# === Step 3 — noVNC (optional — KasmVNC has built-in but keep for parity) ===
step "[3/12] KasmVNC has built-in websocket on :$WEBSOCKET_PORT (no separate noVNC needed)"

# === Step 4 — Wine boot ===
step "[4/12] Initialising Wine prefix"
if [ -d "$HOME/.wine" ]; then sudo chown -R "$(whoami):$(whoami)" "$HOME/.wine" 2>>"$WINE_LOG"; fi
WINEDLLOVERRIDES="mscoree,mshtml=" wineboot -i >>"$WINE_LOG" 2>&1
while pgrep -u "$(whoami)" wineboot >/dev/null 2>&1; do sleep 1; done
step "[4/12] Wine prefix OK"

# === Step 5 — Wineserver keep-alive ===
step "[5/12] Starting wineserver -p"
wineserver -p >>"$WINE_LOG" 2>&1 &
sleep 1

# === Step 6 — Install MT5 ===
if [ ! -f "$MT5_EXE" ]; then
    step "[6/12] Downloading MT5 installer"
    wget -q "$MT5_INSTALLER_URL" -O "$MT5_INSTALLER" 2>>"$WINE_LOG"
    [ -s "$MT5_INSTALLER" ] || fail "MT5 installer download failed"
    step "[6/12] Installing MT5 (silent)"
    wine "$MT5_INSTALLER" /auto >>"$WINE_LOG" 2>&1 &
    WAIT=0
    while [ ! -f "$MT5_EXE" ] && [ "$WAIT" -lt 600 ]; do sleep 5; WAIT=$((WAIT+5)); done
    [ -f "$MT5_EXE" ] || fail "MT5 install timed out"
    rm -f "$MT5_INSTALLER"
    step "[6/12] MT5 installed"
else
    step "[6/12] MT5 already installed"
fi

# === Step 7 — Pre-seed / reassert [Common] AutoUpdate + [Experts] Python-API gate ===
# T2 FIX (WO-MT5GW-0002 Task 3): this function is defined here but CALLED just before
# Step 11 (Launch) below, not here — it must run immediately before every launch, not
# just once after a fresh install, so it also reasserts on runs where Steps 6/8/9 were
# skipped because everything was already installed.
#
# Root cause this fixes: the previous version of this function only PATCHED an
# existing common.ini ("[ -f "$MT5_COMMON_INI" ] || return 0") and only touched
# [Common] AutoUpdate. On a genuinely fresh volume common.ini does not exist until
# MT5's own first run creates it, so that early-return made the function a no-op on
# first boot — and MT5's own default for [Experts] on a fresh profile is Api=0 /
# AllowDllImport=0 (Python API disabled). Nothing upstream of the terminal's first
# launch ever set it to 1. That is what reproduced the T2 "-10005 IPC timeout" on a
# completely fresh, no-credential volume (verified directly: common.ini after a fresh
# boot had no [Experts] section at all until MT5 itself wrote Api=0 the first time a
# user touched the toolbar). This function now creates common.ini from scratch when
# it does not exist, and always reasserts both [Common] AutoUpdate=0 and the
# [Experts] gate keys, whether the file is being created or patched.
#
# [Experts] Account=0/Profile=0/Chart=0 are included alongside Api=1/AllowDllImport=1
# per prior KRONOS/Helm doctrine (helm:doctrine:wine_mt5_python_api_gate_and_options_
# navigation:v1) — these three persist pre-launch and defeat MT5's auto-disable
# triggers that would otherwise flip Api back to 0 after a restart. This goes beyond
# the WO's literal minimum (Api=1, AllowDllImport=1) but directly serves keeping
# those two durable, so it is included rather than left as a known gap.
preseed_experts_and_autoupdate() {
    mkdir -p "$MT5_DIR/Config"
    python3 - "$MT5_COMMON_INI" <<'PY' 2>/dev/null || true
import sys
from pathlib import Path

p = Path(sys.argv[1])
desired_common = {"AutoUpdate": "0"}
desired_experts = {"AllowDllImport": "1", "Api": "1",
                    "Account": "0", "Profile": "0", "Chart": "0"}

if p.exists():
    raw = p.read_bytes()
    bom = b''
    data = raw
    if raw.startswith(b'\xff\xfe'):
        bom = b'\xff\xfe'
        data = raw[2:]
    text = data.decode('utf-16-le', errors='replace')
    nl = '\r\n' if '\r\n' in text else '\n'
    lines = text.split(nl)
else:
    raw = b''
    bom = b'\xff\xfe'
    nl = '\r\n'
    lines = []

def apply_section(lines, section, desired):
    start = None
    end = len(lines)
    for i, line in enumerate(lines):
        s = line.strip('\x00').strip()
        if s == section:
            start = i
            end = len(lines)
            for j in range(i + 1, len(lines)):
                t = lines[j].strip('\x00').strip()
                if t.startswith('[') and t.endswith(']'):
                    end = j
                    break
            break
    if start is None:
        if lines and lines[-1].strip('\x00').strip() != '':
            lines.append('')
        lines.append(section)
        for k, v in desired.items():
            lines.append(f"{k}={v}")
        return lines
    seen = set()
    for i in range(start + 1, end):
        s = lines[i].strip('\x00').strip()
        if '=' not in s:
            continue
        k = s.split('=', 1)[0].strip()
        if k in desired:
            lines[i] = f"{k}={desired[k]}"
            seen.add(k)
    missing = [k for k in desired if k not in seen]
    for k in missing:
        lines.insert(end, f"{k}={desired[k]}")
        end += 1
    return lines

lines = apply_section(lines, '[Common]', desired_common)
lines = apply_section(lines, '[Experts]', desired_experts)

new_text = nl.join(lines)
new_data = bom + new_text.encode('utf-16-le')
if new_data != raw:
    p.write_bytes(new_data)
PY
}

# Renders the MT5 startup config (login/password/server) from
# /run/secrets/{mt5_login,mt5_password} + the non-secret MT5_SERVER env var
# into tmpfs ONLY (WIN_RENDERED_MT5_INI, under the container's Z: drive —
# never into $MT5_MQL5_FILES, which lives on the persistent named volume).
# Reads each secret file directly in Python; never echoes/logs a value.
render_mt5_ini_from_secrets() {
    local login_file="/run/secrets/mt5_login"
    local pass_file="/run/secrets/mt5_password"
    # Same root:root mode-0400 secrets mount as render_vnc_password() above
    # -- read via sudo, and run the whole interpreter under sudo too so its
    # own open() calls on the secret paths succeed (not just an existence
    # check followed by a plain-user open that would still fail).
    sudo test -s "$login_file" && sudo test -s "$pass_file" || return 1
    mkdir -p "$GATEWAY_SECRETS_DIR"
    sudo python3 - "$login_file" "$pass_file" "${MT5_SERVER:-}" "$RENDERED_MT5_INI" <<'PY'
import sys, os
login_file, pass_file, server, out_path = sys.argv[1:5]
with open(login_file) as f:
    login = f.readline().strip()
with open(pass_file) as f:
    pw = f.readline().strip()
lines = ["[Common]", f"Login={login}", f"Password={pw}"]
if server:
    lines.append(f"Server={server}")
content = "\r\n".join(lines) + "\r\n"
with open(out_path, "w", newline="") as f:
    f.write(content)
os.chown(out_path, 1000, 1000)
PY
    chmod 0400 "$RENDERED_MT5_INI"
    [ -s "$RENDERED_MT5_INI" ]
}

# === Step 8 — Install Wine Python 3.9.13 32-bit ===
if [ ! -f "/home/headless/.wine/drive_c/Program Files (x86)/Python39-32/python.exe" ]; then
    step "[8/12] Downloading Wine Python 3.9.13 (32-bit)"
    wget -q "$WINE_PY_URL" -O "$WINE_PY_INSTALLER" 2>>"$WINE_LOG"
    step "[8/12] Installing Wine Python (silent, 32-bit)"
    WINEDEBUG=-all wine "$WINE_PY_INSTALLER" /quiet InstallAllUsers=1 PrependPath=0 Include_test=0 >>"$WINE_LOG" 2>&1
    rm -f "$WINE_PY_INSTALLER"
    step "[8/12] Wine Python 32-bit installed"
else
    step "[8/12] Wine Python 32-bit already installed"
fi

# === Step 9 — Install MetaTrader5 + RPyC + numpy on 32-bit ===
if ! WINEDEBUG=-all wine "$WINE_PY_BIN" -c "import MetaTrader5" 2>/dev/null; then
    step "[9/12] Installing pip packages on 32-bit Python"
    WINEDEBUG=-all wine "$WINE_PY_BIN" -m pip install --no-cache-dir --upgrade pip >>"$WINE_LOG" 2>&1
    WINEDEBUG=-all wine "$WINE_PY_BIN" -m pip install --no-cache-dir "MetaTrader5==5.0.36" "rpyc==5.2.3" "numpy<2" >>"$WINE_LOG" 2>&1
    step "[9/12] Pip packages installed on 32-bit Python"
else
    step "[9/12] MetaTrader5/rpyc/numpy already installed"
fi

# === Step 10 — Reset offscreen dialog positions ===
reset_offscreen_dialogs() {
    local terminal_ini="$MT5_DIR/Config/terminal.ini"
    [ -f "$terminal_ini" ] || return 0
    python3 - "$terminal_ini" <<'PY' 2>/dev/null || true
import sys
from pathlib import Path
p = Path(sys.argv[1])
raw = p.read_bytes()
bom = b''
data = raw
if raw.startswith(b'\xff\xfe'):
    bom = b'\xff\xfe'
    data = raw[2:]
text = data.decode('utf-16-le', errors='replace')
nl = '\r\n' if '\r\n' in text else '\n'
lines = text.split(nl)
fixes = {"Dlg_133_left": "312", "Dlg_133_top": "251",
         "Dlg_2405_left": "378", "Dlg_2405_top": "441"}
changed = False
for i, line in enumerate(lines):
    s = line.strip()
    for k, v in fixes.items():
        if s.startswith(k + "=") and s[len(k)+1:] == "-3":
            lines[i] = f"{k}={v}"
            changed = True
            break
if changed:
    p.write_bytes(bom + nl.join(lines).encode('utf-16-le'))
PY
}
reset_offscreen_dialogs

# === Step 10.5 — Reassert AutoUpdate + Python-API gate (T2 fix, every start) ===
step "Pre-seeding/reasserting [Common] AutoUpdate + [Experts] Api/AllowDllImport gate"
preseed_experts_and_autoupdate
step "AutoUpdate + Python-API gate reasserted"

# === Step 10.6 — Seed the broker directory (servers.dat), FIRST START ONLY ===
# WO-MT5GW-0006: a fresh MT5 install's own default servers.dat only contains
# MetaQuotes' own demo servers -- boutique/prop-firm brokers (confirmed:
# Vantage, FTMO) are simply absent, and the terminal has no way to resolve
# their server names without this file (this is a real, live-verified
# finding, not a Wine/IPC bug -- see docs/evidence/WO-MT5GW-0005.md and
# WO-MT5GW-0006.md). /seed/servers.dat is a read-only bind mount of the
# shared, pre-merged directory (see compose.instance.yml). This only ever
# runs on a volume's first boot -- once the terminal has its own
# servers.dat (ours or one it wrote itself), it is NEVER touched again, so
# any brokers a user finds/adds later via Find your company are preserved
# across restarts.
seed_servers_dat_if_missing() {
    local target="$MT5_DIR/Config/servers.dat"
    local seed="/seed/servers.dat"
    [ -f "$target" ] && return 0
    [ -s "$seed" ] || return 0
    mkdir -p "$MT5_DIR/Config"
    cp "$seed" "$target"
    chmod 0644 "$target"
    return 0
}
if [ -f "$MT5_DIR/Config/servers.dat" ]; then
    step "Broker directory (servers.dat) already present -- not touching it"
else
    seed_servers_dat_if_missing
    if [ -f "$MT5_DIR/Config/servers.dat" ]; then
        step "Seeded broker directory (servers.dat) from shared seed (first start only)"
    else
        step "No shared seed available -- terminal will use its own default broker directory"
    fi
fi

# === Step 11 — Launch MT5 ===
step "[11/12] Launching MT5"
mkdir -p "$MT5_MQL5_FILES" 2>/dev/null
if render_mt5_ini_from_secrets; then
    step "[11/12]   mt5_login/mt5_password secrets present — launching with /config: (tmpfs-rendered, credentials never logged)"
    WINEDEBUG=-all wine "$MT5_EXE" /config:"$WIN_RENDERED_MT5_INI" 2>&1 | redact >>"$WINE_LOG" &
else
    step "[11/12]   no mt5_login/mt5_password secrets — launching without credentials"
    WINEDEBUG=-all wine "$MT5_EXE" >>"$WINE_LOG" 2>&1 &
fi

WAIT=0
while ! pgrep -f "terminal64.exe" >/dev/null && [ "$WAIT" -lt 120 ]; do sleep 2; WAIT=$((WAIT+2)); done
if pgrep -f "terminal64.exe" >/dev/null; then
    step "[11/12] MT5 started (pid=$(pgrep -f terminal64.exe | head -1))"
else
    step "[11/12] MT5 FAILED to start"
fi

# === Step 12 — Launch rpyc_server.py under 32-bit Wine python ===
step "[12/12] Launching rpyc_server.py under Wine 32-bit python"
(
    while true; do
        WINEDEBUG=-all wine "$WINE_PY_BIN" /Metatrader/rpyc_server.py >>"$RPYC_LOG" 2>&1
        echo "[$(date -u +%FT%TZ)] rpyc_server exited, restarting in 5s" >> "$RPYC_LOG"
        sleep 5
    done
) &
sleep 5
step "[12/12] rpyc_server supervisor running"

echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║   Trinity MT5 — Ready (KasmVNC variant)      ║"
echo "  ╠══════════════════════════════════════════════╣"
echo "  ║  VNC:        localhost:$VNC_PORT                  ║"
echo "  ║  WebSocket:  localhost:$WEBSOCKET_PORT                 ║"
echo "  ║  RPyC:       localhost:18812                 ║"
echo "  ╚══════════════════════════════════════════════╝"

# Watchdog
while true; do
    RUNNING=false
    pgrep -f "terminal64.exe" >/dev/null 2>&1 && RUNNING=true
    pgrep -f "rpyc_server.py" >/dev/null 2>&1 && RUNNING=true
    pgrep -x "wine" >/dev/null 2>&1 && RUNNING=true
    pgrep -f "wine-preloader" >/dev/null 2>&1 && RUNNING=true
    pgrep -f "wineserver" >/dev/null 2>&1 && RUNNING=true
    [ "$RUNNING" = false ] && break
    sleep 10
done
step "All wine processes gone — exiting"
exit 0
