# MT5 Self-Build Image — Design Report

Exported from Memory Fabric key `helm:reports:WO-NEO-FTMO-PRACTICE-EXECUTION-RET_CODE-10044-DIAGNOSTIC-0001:helm_self_build_minimal_mt5_image_design:v1`.

Original scope at time of authoring (2026-05-13): DESIGN ONLY — no build, no container start, no credential read, no broker login.

This document is historical design record, imported as-is for WO-MT5GW-0001 Task 3. It predates the KasmVNC variant, the `trinity-mt5-image` build actually shipped, and this repo's naming/port conventions — read it as provenance, not as the current spec.

```json
{
  "wo": "WO-NEO-FTMO-PRACTICE-EXECUTION-RET_CODE-10044-DIAGNOSTIC-0001",
  "report_kind": "helm_self_build_minimal_mt5_image_design",
  "version": "v1",
  "authored_utc": "2026-05-13T17:17:59.354750+00:00",
  "authored_by": "HELM",
  "scope": "DESIGN ONLY \u2014 no build, no container start, no credential read, no broker login",
  "verdict": "SELF_BUILD_DESIGN_READY_FOR_R2_AUDIT",
  "B_proposed_image_architecture": {
    "image_name": "trinity/mt5:0.1.0",
    "alt_names": [
      "helm/mt5-trinity:0.1.0",
      "trinity-prop-mt5:0.1.0"
    ],
    "registry": "local only (no public push)",
    "base_os": "ubuntu:24.04 (noble)",
    "base_image_pin_method": "FROM ubuntu:24.04 + by digest (e.g. ubuntu@sha256:<digest>) pinned at build-time",
    "wine": {
      "version_pin": "winehq-stable=10.0.0.0~noble-1 + wine-stable=10.0.0.0~noble-1",
      "available_confirmed": "verified at design time: dl.winehq.org/wine-builds/ubuntu/dists/noble/main/binary-amd64/Packages",
      "repo_install": "dpkg --add-architecture i386 + curl https://dl.winehq.org/wine-builds/winehq.key + echo 'deb https://dl.winehq.org/wine-builds/ubuntu/ noble main' + apt-get update + apt-get install -y --no-install-recommends winehq-stable=10.0.0.0~noble-1 wine-stable=10.0.0.0~noble-1 wine-stable-amd64=10.0.0.0~noble-1 wine-stable-i386:i386=10.0.0.0~noble-1",
      "do_NOT_install": [
        "winehq-staging",
        "winehq-devel"
      ],
      "rationale": "Wine 10.0 stable is the gmag11 production baseline where MetaTrader5 Python IPC works (-10005 IPC timeout was Wine 11.2 Staging-specific in hudsonventura)"
    },
    "x_server": {
      "package": "tigervnc-standalone-server",
      "binary": "Xtigervnc :1",
      "why": "real XTEST extension support (proven in hudsonventura T1 \u2014 Ctrl+E toggled Algo Trading with MT5 Journal proof)"
    },
    "window_manager": {
      "primary": "openbox + obconf + tint2",
      "why": "matches hudsonventura proven layout; lightweight; does not intercept synthetic events"
    },
    "vnc_web": {
      "noVNC": "git clone --branch v1.4.0 --depth 1 from github.com/novnc/noVNC.git",
      "websockify": "git clone --branch v0.11.0 --depth 1 from github.com/novnc/websockify.git",
      "ports_default_internal": {
        "vnc": 5901,
        "novnc": 6901
      },
      "ports_external_per_account": "mapped per docker-compose service (e.g. FTMO=3011/18813)"
    },
    "mt5_installation": {
      "installer_source": "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe",
      "install_mode": "/auto (silent)",
      "install_when": "first boot only; idempotent \u2014 if terminal64.exe present skip",
      "install_step": "wine mt5setup.exe /auto with WINEDLLOVERRIDES=mscoree,mshtml= ",
      "post_install": "delete installer .exe; ensure terminal64.exe at C:\\Program Files\\MetaTrader 5\\terminal64.exe"
    },
    "wine_prefix_layout": {
      "WINEPREFIX": "/config/.wine",
      "WINEDEBUG": "-all",
      "WINEDLLOVERRIDES": "mscoree,mshtml= (during install only)",
      "wineboot": "wineboot -i at first boot",
      "wineserver": "wineserver -p kept alive in start.sh (prevents premature exit; hudsonventura proven)"
    },
    "config_volume_layout": {
      "named_volume_per_account": "/config (one per account container)",
      "subdirs": [
        "/config/.wine \u2014 Wine prefix",
        "/config/.wine/drive_c/Program Files/MetaTrader 5/ \u2014 MT5 install",
        "/config/.wine/drive_c/Program Files/MetaTrader 5/Config/ \u2014 common.ini, accounts.dat (MT5-encrypted)",
        "/config/.wine/drive_c/Program Files/MetaTrader 5/logs/ \u2014 MT5 daily logs (UTF-16)",
        "/config/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/ \u2014 mt5.ini bind-mount target (read-only)"
      ]
    },
    "config_mt5_ini_support": {
      "launch_command": "wine \"$MT5_EXE\" /config:\"C:\\Program Files\\MetaTrader 5\\MQL5\\Files\\mt5.ini\"",
      "bind_mount_target": "/home/headless/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/mt5.ini",
      "ini_format_supported": [
        "[Common] Login Password Server",
        "[Experts] AllowLiveTrading Enabled AllowDllImport Account Profile Chart Api",
        "[StartUp]",
        "[Charts]",
        "[Trades]"
      ],
      "proven_in": "hudsonventura T3 \u2014 MT5 logged in successfully with rendered mt5.ini \u2192 title bar '<FTMO_DEMO_LOGIN> - <FTMO_DEMO_SERVER> - ...'"
    },
    "python_runtime_inside_wine": {
      "python_installer_url": "https://www.python.org/ftp/python/3.9.13/python-3.9.13-amd64.exe",
      "version_pin": "Python 3.9.13 (gmag11 baseline)",
      "install_mode": "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0",
      "install_when": "first boot; idempotent",
      "why_not_newer": "Python 3.9.13 is the gmag11-baked pin; MetaTrader5==5.0.36 wheel is built for 3.9; new Python versions would require corresponding wheel availability check"
    },
    "metatrader5_package": {
      "version_pin": "MetaTrader5==5.0.36 (gmag11 baseline) OR MetaTrader5==5.0.45 (latest 5.0.x; tested install OK during T2)",
      "preferred_pin": "5.0.36 for production fidelity with current gmag11; bump to 5.0.45 once self-build IPC re-validated",
      "install_command": "wine python -m pip install --no-cache-dir MetaTrader5==5.0.36 'numpy<2'",
      "numpy_pin": "numpy<2 (NumPy 2.x has ABI changes that break MetaTrader5 wheel)"
    },
    "rpyc": {
      "version_pin": "rpyc==5.2.3 (gmag11 baseline)",
      "install_command": "wine python -m pip install --no-cache-dir rpyc==5.2.3",
      "transport": "wine python rpyc_server.py on port 18812 (internal); mapped per-account externally",
      "bind_interface": "0.0.0.0 inside container; Docker network isolation; per-container access control"
    },
    "rpyc_server_py": {
      "source": "port from /srv/prop-firms/template/rpyc_server.py (existing 7-line classic RPyC server)",
      "launch_command": "wine python /Metatrader/rpyc_server.py &",
      "auto_restart": "wrapped in supervisor loop in start.sh \u2014 if rpyc_server exits, restart with logged event"
    },
    "start_sh_responsibilities": [
      "Step 0: unset XMODIFIERS / GTK_IM_MODULE / QT_IM_MODULE / XIM* (IME hardening from helm fix #6)",
      "Step 1: start TigerVNC + Openbox + noVNC + tint2",
      "Step 2: wineboot -i (idempotent)",
      "Step 3: install MT5 if not present (idempotent download + /auto)",
      "Step 4: install Wine Python 3.9.13 if not present (idempotent)",
      "Step 5: pip install MetaTrader5==5.0.36 rpyc==5.2.3 'numpy<2' (idempotent)",
      "Step 6: reset offscreen Dlg_133/Dlg_2405 positions in terminal.ini (helm fix #6)",
      "Step 7: reassert_experts_flags() in common.ini \u2014 Account=0 Profile=0 Chart=0 AllowDllImport=1 Api=1 (helm fix #6)",
      "Step 8: launch terminal64.exe /config:mt5.ini (credentialed startup when mt5.ini bind-mounted)",
      "Step 9: optional fallback \u2014 xdotool Ctrl+E after 30s if mt5.ini didn't enable AutoTrading (helm fix #6 hardened)",
      "Step 10: launch wine python rpyc_server.py with supervisor loop",
      "Step 11: watchdog loop \u2014 exit if terminal64 + wineserver + wine all gone (hudsonventura pattern)"
    ],
    "healthcheck": {
      "method": "HEALTHCHECK CMD",
      "command": "bash -c \"pgrep -f terminal64.exe >/dev/null && pgrep -f rpyc_server >/dev/null && nc -z localhost 18812 || exit 1\"",
      "interval": "30s",
      "timeout": "10s",
      "start_period": "180s (first-boot install can take 2-3 min)",
      "retries": 3
    },
    "logging": {
      "container_driver": "json-file with max-size=10m, max-file=5 (in docker-compose service config)",
      "wine_log": "/tmp/wine.log (volatile per-container)",
      "mt5_log": "/config/.wine/drive_c/Program Files/MetaTrader 5/logs/YYYYMMDD.log (UTF-16 \u2014 MT5 native)",
      "start_sh_log": "/tmp/start_sh.log (volatile per-container)",
      "rpyc_server_log": "/tmp/rpyc_server.log",
      "no_secret_logging": "redaction enforced at start.sh: any line containing /Password=/ in start.sh stdout/stderr is dropped"
    }
  },
  "C_version_pinning_plan": {
    "base_image_digest_pin": "FROM ubuntu:24.04 \u2014 record final sha256 digest at first successful build; subsequent builds use ubuntu@sha256:<digest>",
    "winehq_stable_pin": "winehq-stable=10.0.0.0~noble-1",
    "wine_stable_pin": "wine-stable=10.0.0.0~noble-1 + wine-stable-amd64=10.0.0.0~noble-1 + wine-stable-i386:i386=10.0.0.0~noble-1",
    "python_pin": "Python 3.9.13 (Wine python; installed via python.org installer with sha256 verification)",
    "metatrader5_pin": "MetaTrader5==5.0.36 (validated production version)",
    "rpyc_pin": "rpyc==5.2.3 (gmag11 baseline)",
    "numpy_pin": "numpy<2 (specifically tested numpy==1.26.4)",
    "tigervnc_pin": "tigervnc-standalone-server apt version captured at build (typically apt-controlled but pin specific version in Dockerfile)",
    "novnc_pin": "noVNC v1.4.0 (git tag)",
    "websockify_pin": "websockify v0.11.0 (git tag)",
    "mt5_installer_source": "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe \u2014 record sha256 at first successful build; verify against pin on subsequent builds",
    "servers_dat_source": "either bake from existing FTMO Vantage FundedNext containers (known-good) OR download once + ship in image",
    "no_silent_autoupgrade": {
      "wine_apt_pin_via_apt_preferences": "/etc/apt/preferences.d/wine: Package: winehq-stable wine-stable* \u2014 Pin: version 10.0.0.0~noble-1 \u2014 Pin-Priority: 1001",
      "python_wine_no_autoupgrade": "Wine python 3.9.13 has no automatic upgrade mechanism inside Wine",
      "pip_no_autoupgrade": "wine python -m pip install with exact == pins; no upgrade-pip step",
      "mt5_built_in_autoupdate": "MT5 application auto-updates terminal64 build (5833 \u2192 5836 etc.) \u2014 this is per-account state inside the volume, NOT per-image; acceptable",
      "container_image_immutability": "once trinity/mt5:0.1.0 is tagged and validated, image is immutable; new builds get new tag (0.1.1, 0.1.2)"
    }
  },
  "D_runtime_capabilities_required": {
    "xdotool_ctrl_e_toggle_with_journal_proof": "MUST PASS \u2014 hudsonventura T1 baseline",
    "config_mt5_ini_credentialed_startup": "MUST PASS \u2014 hudsonventura T3 baseline (login + Algo Trading green)",
    "terminal_info_trade_allowed_True": "MUST PASS \u2014 the gate that fails in current production",
    "terminal_info_tradeapi_disabled_False": "MUST PASS \u2014 the Python-API gate",
    "metatrader5_python_ipc_works": "MUST PASS \u2014 the gate that fails in hudsonventura Wine 11.2 Staging (-10005); gmag11 Wine 10.0 baseline",
    "rpyc_classic_connect_from_host": "MUST PASS \u2014 NEO scripts use rpyc.classic.connect('localhost', port=18812-mapped)",
    "read_only_probes_work": [
      "account_info() returns identity + balance + trade_allowed + trade_mode",
      "terminal_info() returns connected + trade_allowed + tradeapi_disabled + build",
      "symbol_info('XAUUSD') returns trade_mode + bid/ask + visible",
      "positions_get() returns list (count only used at test stage)",
      "orders_get() returns list (count only used at test stage)",
      "last_error() returns tuple"
    ],
    "explicitly_not_tested_at_self_build_T1_T2_T3": [
      "order_send",
      "order_check",
      "order_modify",
      "order_close",
      "position_close",
      "any mutation"
    ]
  },
  "E_secret_handling_model": {
    "inherits_from": "R2-accepted T3 credential design lock (helm_t3_credential_design_lock:v1)",
    "source_file": "/etc/mt5_secrets.env (mode 0600 root:root)",
    "parser": "Python open() + line.split('=', 1)[1].rstrip('\\r\\n') \u2014 NEVER bash source",
    "render_path": "/run/helm/selfbuild-test-<phase>/mt5.ini (tmpfs)",
    "render_mode": "0444 root:root",
    "render_dir_mode": "0700 root:root",
    "container_mount": "single-file read-only bind mount at /home/headless/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/mt5.ini",
    "no_credentials_in": [
      "argv",
      "env vars",
      "fabric",
      "logs",
      "Git",
      "screenshots",
      "docker inspect",
      "compose files"
    ],
    "tools_options_server_screenshot_banned": true,
    "cleanup_after_identity_assertion": "shred -u + rmdir at design-lock spec",
    "no_credential_read_during_design": true
  },
  "F_test_sequence": {
    "SELFBUILD_T0_build_only_smoke": {
      "purpose": "build image and prove it boots without credentials",
      "actions": [
        "docker buildx build -t trinity/mt5:0.1.0 .",
        "record sha256 digest of resulting image",
        "record sha256 of mt5setup.exe consumed during build",
        "record dpkg --version of wine-stable in built image",
        "no docker compose up \u2014 image build only",
        "no broker login"
      ],
      "PASS_criteria": [
        "Build completes",
        "Wine version inside image == 10.0.0.0~noble-1",
        "MetaTrader5 package inside image == 5.0.36",
        "rpyc inside image == 5.2.3",
        "Python inside Wine == 3.9.13",
        "Image labels carry build timestamp + git commit"
      ],
      "credentials_used": "NONE",
      "authorisation_required": "architect 'go' to start build"
    },
    "SELFBUILD_T1_gui_xtest": {
      "purpose": "Verify TigerVNC + Openbox + xdotool input still works under our build",
      "container_name": "MT5_HELM_SELFBUILD_T1",
      "ports": {
        "vnc": 5939,
        "novnc": 6939
      },
      "volume": "helm_selfbuild_t1_config (named, isolated, ephemeral)",
      "credentials_used": "NONE \u2014 fresh boot without mt5.ini",
      "checks": [
        "Container starts and reaches Ready! marker in start.sh",
        "VNC reachable on 5939, noVNC on 6939",
        "MT5 GUI launches; xdotool detects MetaTrader window by name and by class terminal64",
        "xdotool key ctrl+e on main window logs 'automated trading is enabled' in MT5 Journal",
        "Second ctrl+e logs 'automated trading is disabled'",
        "Screenshot evidence captured (safe areas only \u2014 toolbar/Journal/charts; no Options/Server)"
      ],
      "authorisation_required": "architect 'go' after T0 PASS"
    },
    "SELFBUILD_T2_python_rpyc_api": {
      "purpose": "Verify MetaTrader5 Python IPC works under our pinned Wine 10.0",
      "container_name": "MT5_HELM_SELFBUILD_T2",
      "ports": {
        "vnc": 5949,
        "novnc": 6949,
        "rpyc": 18839
      },
      "volume": "helm_selfbuild_t2_config (named, isolated, ephemeral)",
      "credentials_used": "NONE",
      "checks": [
        "rpyc_server.py running inside container (pgrep -f rpyc_server returns process)",
        "RPyC bridge reachable from host: rpyc.classic.connect('localhost', 18839) succeeds",
        "Via RPyC: import MetaTrader5 OK, mt5.__version__ == '5.0.36'",
        "Via RPyC: mt5.initialize() no-credential returns True OR False with last_error != -10005 IPC timeout \u2014 must not be IPC error",
        "Via RPyC: mt5.terminal_info() returns object (even if not logged in)",
        "Via RPyC: mt5.last_error() returns tuple",
        "Via RPyC: NO order_send / order_check / order_modify / order_close"
      ],
      "BLOCKING_FAIL_signature": "last_error == [-10005, 'IPC timeout'] \u2014 this is the Wine 11.2 Staging fingerprint and MUST NOT appear under Wine 10.0",
      "authorisation_required": "architect 'go' after T1 PASS"
    },
    "SELFBUILD_T3_credentialed_read_only": {
      "purpose": "Full T3 equivalent with rendered mt5.ini in self-build image",
      "container_name": "MT5_HELM_SELFBUILD_T3",
      "ports": {
        "vnc": 5959,
        "novnc": 6959,
        "rpyc": 18849
      },
      "volume": "helm_selfbuild_t3_config (named, isolated, ephemeral)",
      "credentials_used": "<FTMO_ACCOUNT_LABEL> via R2-accepted T3 credential design lock",
      "checks": [
        "Render mt5.ini per design lock \u2014 Python file-parse, tmpfs, 0444 root",
        "Container starts; MT5 launches with /config:mt5.ini",
        "MT5 Journal shows 'successfully initialized from start config'",
        "Via RPyC: account_info().login == <FTMO_DEMO_LOGIN> AND server == '<FTMO_DEMO_SERVER>'",
        "Identity gate passed \u2192 shred -u /run/helm/selfbuild-t3/mt5.ini",
        "Via RPyC: terminal_info().trade_allowed == True (the original gate)",
        "Via RPyC: terminal_info().tradeapi_disabled == False (the Python-API gate)",
        "Via RPyC: account_info().trade_allowed == True",
        "Via RPyC: terminal_info().connected == True",
        "Via RPyC: symbol_info('XAUUSD').trade_mode == 4 (FULL)",
        "Via RPyC: symbol_info('XAUUSD').bid + ask non-zero, time advancing",
        "Via RPyC: positions_get() count + orders_get() count (target 0/0)",
        "Via RPyC: last_error() benign",
        "NO order_send / order_check / order_modify / order_close",
        "NEO state remains PAUSED",
        "Production untouched (FTMO/FundedNext/Vantage mtimes + uptimes unchanged)"
      ],
      "authorisation_required": "separate architect 'go' AND R2 sign-off after T2 PASS"
    }
  },
  "G_isolation_plan": {
    "every_test_uses_distinct": [
      "container name",
      "ports",
      "named volume",
      "compose file path"
    ],
    "tests_never_touch": [
      "MT5_FTMO_Practice container or its volume",
      "MT5_FundedNext container or its volume",
      "MT5_Vantage container or its volume",
      "any production Config/accounts.dat/common.ini/start.sh",
      "/etc/mt5_secrets.env (except via T3 Python file-parse render path)",
      "/srv/NEO except read-only",
      "neo:prop:accounts (write)",
      "neo:prop:state (write \u2014 read-only confirmation only)",
      "any falcon:* / trader:* / r2d2:* / argus:* / agent-smith:* / plutus:* / rogue:* fabric key"
    ],
    "NEO_kept_PAUSED_throughout": true,
    "production_cutover_NOT_part_of_this_WO": true,
    "all_test_containers_have_helm_test_purpose_label": true,
    "all_test_volumes_named_helm_selfbuild_*": true,
    "ports_avoided": [
      3010,
      3011,
      3013,
      18812,
      18813,
      18815,
      5901,
      6901,
      5919,
      6919,
      5929,
      6929
    ],
    "ports_chosen_for_self_build_tests": {
      "T1": {
        "vnc": 5939,
        "novnc": 6939
      },
      "T2": {
        "vnc": 5949,
        "novnc": 6949,
        "rpyc": 18839
      },
      "T3": {
        "vnc": 5959,
        "novnc": 6959,
        "rpyc": 18849
      }
    }
  },
  "H_acceptance_criteria": {
    "build_reproducibility_PASS": [
      "Dockerfile + .dockerignore + start.sh + rpyc_server.py + Pinfile checked into /srv/prop-firms/trinity-mt5-image/",
      "Two consecutive builds produce identical image digest (modulo build timestamp metadata)",
      "Build args (BASE_DIGEST, WINE_VERSION, PYTHON_VERSION, MT5_INSTALLER_SHA256) recorded"
    ],
    "gui_xtest_PASS": "T1 checks all green (window detection, Ctrl+E + Journal proof, screenshot review)",
    "python_ipc_PASS": "T2 mt5.initialize() returns without -10005 IPC timeout under Wine 10.0",
    "rpyc_PASS": "rpyc.classic.connect from host succeeds; remote MetaTrader5 import works",
    "credentialed_read_only_PASS": "T3 all gate checks (login + terminal.trade_allowed=True + tradeapi_disabled=False + XAUUSD FULL/streaming + 0 positions + 0 orders) all PASS",
    "no_execution_PASS": "Zero order_* calls across T0/T1/T2/T3",
    "cleanup_PASS": [
      "All test containers removed",
      "All test volumes removed",
      "All /run/helm/selfbuild-* tmpfs paths shredded + removed",
      "T0 image retained at trinity/mt5:0.1.0 tag (build artefact)"
    ],
    "no_secret_exposure_PASS": [
      "No password value in fabric / logs / Git / stdout / stderr / screenshots / docker inspect / argv / compose / env",
      "Audit greps return zero matches",
      "Screenshots reviewed manually before evidence promotion"
    ],
    "production_untouched_PASS": [
      "MT5_FTMO_Practice / MT5_FundedNext / MT5_Vantage status Up + uptime monotonic across all 4 phases",
      "ftmo-practice/start.sh mtime unchanged",
      "production common.ini mtime unchanged",
      "neo:prop:state:<FTMO_ACCOUNT_LABEL>.status == 'PAUSED' (unchanged)"
    ],
    "ANY_FAIL_blocks_next_phase": true
  },
  "I_cleanup_rollback": {
    "between_test_phases": "docker compose down -v for each phase test compose file",
    "tmpfs_credential_files": "shred -u + rmdir; verify /run/helm/selfbuild-* path removed",
    "test_compose_paths_retained": "/srv/prop-firms/trinity-mt5-image/test-T1/ etc. retained for evidence; contain NO secrets",
    "image_retained": "trinity/mt5:0.1.0 is the deliverable; retained",
    "production_unaffected_proof_per_phase": [
      "stat -c mtime on /srv/prop-firms/ftmo-practice/start.sh \u2014 unchanged",
      "docker exec MT5_FTMO_Practice stat -c mtime on common.ini \u2014 unchanged",
      "docker ps Status uptime monotonic on all 3 prod containers",
      "fabric neo:prop:state:<FTMO_ACCOUNT_LABEL>.status == 'PAUSED'"
    ],
    "retention_of_non_secret_evidence": [
      "Build manifest (Dockerfile + Pinfile + image digest)",
      "T1 screenshots (Algo Trading toggle proof)",
      "T2 RPyC connection logs",
      "T3 redacted probe JSON (no password fields)",
      "Each phase published as separate fabric report key"
    ]
  },
  "J_risks": [
    {
      "id": "R1",
      "risk": "Wine 10.0 deb may be deprecated from WineHQ noble repo in future",
      "severity": "LOW",
      "mitigation": "Cache deb files locally; bake into image; consider host-local apt mirror"
    },
    {
      "id": "R2",
      "risk": "MT5 installer URL changes / new build incompatible",
      "severity": "LOW-MED",
      "mitigation": "Record sha256 of mt5setup.exe; bake known-good installer into image OR pin to a specific build number"
    },
    {
      "id": "R3",
      "risk": "MT5 in-app auto-update breaks Python IPC after first boot",
      "severity": "MEDIUM",
      "mitigation": "Disable LiveUpdate via terminal.ini [Common] AutoUpdate=0; test with auto-update enabled vs disabled in T2"
    },
    {
      "id": "R4",
      "risk": "MetaTrader5 5.0.36 wheel may not install on Python 3.9.13 on Wine 10.0 (regression)",
      "severity": "LOW",
      "mitigation": "T0 install step verifies; fallback to 5.0.45 (T2-verified to install in hudsonventura)"
    },
    {
      "id": "R5",
      "risk": "RPyC 5.2.3 has known security boundary \u2014 classic mode exposes remote eval surface",
      "severity": "MEDIUM",
      "mitigation": "Bind RPyC to localhost or Docker network only; never expose to public; access via Docker port mapping with iptables rules if needed"
    },
    {
      "id": "R6",
      "risk": "VNC unauthenticated by default",
      "severity": "LOW",
      "mitigation": "VNC_PW env always set; bind to Docker network only; external port mapping uses host firewall rules"
    },
    {
      "id": "R7",
      "risk": "Credential handling regression",
      "severity": "LOW",
      "mitigation": "Inherits R2-accepted T3 credential design lock unchanged \u2014 no new credential surface"
    },
    {
      "id": "R8",
      "risk": "Future FTMO account rotation requires same Python file-parse pattern",
      "severity": "LOW",
      "mitigation": "helm-rotate-ftmo-practice CLI already implements pattern; transfers directly to self-build image"
    },
    {
      "id": "R9",
      "risk": "One-container-per-account model \u2014 N accounts = N Wine prefixes",
      "severity": "LOW",
      "mitigation": "Already the production pattern (3 prod containers: FTMO/FundedNext/Vantage); resource use linear in account count; acceptable"
    },
    {
      "id": "R10",
      "risk": "Production migration is a separate WO \u2014 pressure to short-circuit",
      "severity": "MEDIUM",
      "mitigation": "Migration boundary explicitly stated below (section K); self-build PASS != migration approval"
    },
    {
      "id": "R11",
      "risk": "Image-build supply chain (WineHQ key, MQL5 server, GitHub for noVNC)",
      "severity": "LOW-MED",
      "mitigation": "Pin GPG key fingerprints; record source URL + checksum; consider air-gapped build option"
    },
    {
      "id": "R12",
      "risk": "build_5836 vs 5833 vs newer MT5 builds \u2014 Python API IPC may regress on newer MT5 builds",
      "severity": "MEDIUM",
      "mitigation": "Snapshot MT5 application binaries (post-first-install) for offline restore; record exact build number in image manifest"
    },
    {
      "id": "R13",
      "risk": "Wine 10.0 stable lifecycle \u2014 Wine 11.0 is now WineHQ-stable",
      "severity": "MEDIUM",
      "mitigation": "Pin to 10.0.0.0~noble-1 in apt preferences; revisit when MetaTrader5 publishes Wine-11-compatible release"
    },
    {
      "id": "R14",
      "risk": "Test-phase port conflicts with future infrastructure",
      "severity": "LOW",
      "mitigation": "Selected port ranges 5939/49/59 + 6939/49/59 + 18839/49 \u2014 clear of all known prod and test ranges"
    }
  ],
  "K_production_migration_boundary": {
    "self_build_T1_T2_T3_pass_does_NOT_equal_production_cutover": true,
    "next_step_after_pass": "Phase 1A migration design (SEPARATE WO)",
    "phase_1A_requirements": [
      "Backup current FTMO container + volume (mt5_ftmo_practice_config) to tarball",
      "Snapshot current compose+env+start.sh to .pre-migration.<UTC>/ (additive, no delete)",
      "Create new production container at parallel path /srv/prop-firms/ftmo-practice-trinity-mt5/ with EXTERNAL ports DISABLED initially",
      "Identity verification \u2014 login == <FTMO_DEMO_LOGIN> + server == '<FTMO_DEMO_SERVER>' confirmed under new image",
      "endpoint_identity key written to neo:prop:endpoint_identity:<FTMO_ACCOUNT_LABEL> (the missing canary from prior session)",
      "Ranger deployment confirmation \u2014 neo_ranger_v0.py + neo_ranger_v0_recovery.py identity-resolver targets new container at correct host:port",
      "execution_health verification \u2014 neo_execution_health.py canary returns clean against new container",
      "NEO remains PAUSED throughout migration design + cutover"
    ],
    "phase_1A_separate_wo_required": true,
    "phase_1A_separate_r2_audit_required": true,
    "phase_1A_separate_architect_go_required": true,
    "NEO_unpause_is_phase_2": "Phase 2 = activation gate; SEPARATE again from Phase 1A; requires Phase 1A all green AND independent architect decision; not within self-build WO scope",
    "fundednext_and_vantage_migration": "OUT OF SCOPE for this WO \u2014 each lane owner (Rogue/Trader) authorises their own image swap separately if/when they choose"
  },
  "safety_proof": {
    "design_only_phase": true,
    "no_image_build": true,
    "no_docker_build": true,
    "no_container_start": true,
    "no_credential_use": true,
    "no_etc_mt5_secrets_env_value_read": true,
    "no_mt5_ini_render": true,
    "no_broker_login": true,
    "no_order_send_check_modify_close": true,
    "no_neo_unpause": true,
    "no_production_container_restart": true,
    "no_production_config_changes": true,
    "no_current_MT5_FTMO_Practice_changes": true,
    "no_fundednext_changes": true,
    "no_vantage_changes": true,
    "no_live_trader_changes": true,
    "no_agent_smith_changes": true,
    "no_plutus_changes": true,
    "no_rogue_lane_changes": true,
    "no_push_merge_tag": true,
    "neo_state_unchanged": "PAUSED"
  }
}
```
