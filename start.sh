#!/bin/bash
# Trinity self-build MT5 image — KasmVNC variant start.sh.
# Launches KasmVNC's Xvnc directly with gmag11-style args (single architectural
# change vs 0.1.2 — TigerVNC standalone replaced by KasmVNC Xvnc).

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
WIN_MT5_INI="C:\\Program Files\\MetaTrader 5\\MQL5\\Files\\mt5.ini"

WINE_PY_INSTALLER="/tmp/python-installer.exe"
WINE_PY_URL="https://www.python.org/ftp/python/3.9.13/python-3.9.13.exe"
WINE_PY_BIN="C:\\Program Files (x86)\\Python39-32\\python.exe"

step() { echo "[$(date -u +%FT%TZ)] $1" | tee -a "$START_LOG"; }
fail() { echo "[$(date -u +%FT%TZ)] FAIL $1" | tee -a "$START_LOG" >&2; exit 1; }

# === Step 1 — KasmVNC Xvnc (gmag11-style direct invocation) ===
step "[1/12] Starting KasmVNC Xvnc on :$VNC_PORT (websocket :$WEBSOCKET_PORT)"
mkdir -p ~/.vnc
# KasmVNC requires its own password format (or run without auth in isolated test)
# Use -SecurityTypes None -disableBasicAuth for isolated test container
Xvnc :$DISPLAY_NUM \
    -PublicIP 127.0.0.1 \
    -disableBasicAuth \
    -SecurityTypes None \
    -AlwaysShared \
    -geometry "$RESOLUTION" \
    -depth 24 \
    -rfbport $VNC_PORT \
    -websocketPort $WEBSOCKET_PORT \
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

# === Step 7 — Suppress MT5 auto-update (R3) ===
suppress_auto_update() {
    [ -f "$MT5_COMMON_INI" ] || return 0
    python3 - "$MT5_COMMON_INI" <<'PY' 2>/dev/null || true
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
in_common = False
au_set = False
for i, line in enumerate(lines):
    s = line.strip('\x00').strip()
    if s.startswith('['):
        in_common = (s == '[Common]')
        continue
    if not in_common or '=' not in s:
        continue
    k = s.split('=', 1)[0].strip()
    if k == 'AutoUpdate':
        lines[i] = "AutoUpdate=0"
        au_set = True
if not au_set:
    for i, line in enumerate(lines):
        s = line.strip('\x00').strip()
        if s == '[Common]':
            lines.insert(i + 1, "AutoUpdate=0")
            au_set = True
            break
new_text = nl.join(lines)
new_data = bom + new_text.encode('utf-16-le')
if new_data != raw:
    p.write_bytes(new_data)
PY
}
step "[7/12] Suppressing MT5 auto-update"
suppress_auto_update
step "[7/12] AutoUpdate suppression applied"

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

# === Step 11 — Launch MT5 ===
step "[11/12] Launching MT5"
mkdir -p "$MT5_MQL5_FILES" 2>/dev/null
if [ -f "$MT5_MQL5_FILES/mt5.ini" ]; then
    step "[11/12]   mt5.ini bind-mount detected — launching with /config:"
    WINEDEBUG=-all wine "$MT5_EXE" /config:"$WIN_MT5_INI" 2>&1 | redact >>"$WINE_LOG" &
else
    step "[11/12]   no mt5.ini — launching without credentials"
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
