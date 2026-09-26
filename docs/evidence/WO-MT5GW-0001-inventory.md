# WO-MT5GW-0001 Task 3 — Pre-Import File Inventory

Source: `/srv/prop-firms/trinity-mt5-image/` (left in place, read-only; nothing there was modified).

**Correction to the original STOP 1 report:** that report said "33 files." A re-count of the actual `find` output below gives **43 files**. This document uses the correct count.

No account login numbers, server names, or account labels are quoted anywhere in this document — leaks are described generically per WO-MT5GW-0002 instruction. See `docs/evidence/WO-MT5GW-0002.md` for the redaction placeholder scheme used when any of this material was actually imported.

## Legend
- **IMPORT** — no sensitive content, safe as-is.
- **IMPORT-REDACTED** — sensitive content present but the file has ongoing value; redact before import.
- **EXCLUDE** — not imported (image content, low value, or scope narrowed by R2D2/WO-MT5GW-0002).

## Inventory

| # | File | Action | Reason |
|---|------|--------|--------|
| 1 | `diag-20260514T111252Z/diag1_fresh_gmag11_probe.txt` | EXCLUDE | Single stray connection-reset error line; no ongoing value. |
| 2 | `diag-20260514T111252Z/diag2_gmag11_prod.txt` | EXCLUDE | Kernel sysctl dump; superseded by `DESIGN.md` narrative. |
| 3 | `diag-20260514T111252Z/diag2_kernel.txt` | EXCLUDE | Kernel sysctl dump; also leaks this host's own hostname via a raw `uname` line. |
| 4 | `diag-20260514T111252Z/diag2_selfbuild.txt` | EXCLUDE | Kernel sysctl dump; low ongoing value. |
| 5 | `diag-20260514T111252Z/diag3_post_install_diff.txt` | EXCLUDE | Wine registry CLSID diff noise; no ongoing value. |
| 6 | `diag-20260514T111252Z/diag3_section_diff.txt` | EXCLUDE | Wine registry CLSID diff noise; no ongoing value. |
| 7 | `diag-20260514T111252Z/diag4_etc_wine_selfbuild.txt` | EXCLUDE | Effectively empty. |
| 8 | `diag-20260514T111252Z/diag4_etc_wine.txt` | EXCLUDE | Effectively empty. |
| 9 | `diag-20260514T111252Z/diag_config_dir_listing.txt` | EXCLUDE | Lists MT5 config filenames (incl. the account-credential file by name) with owner/size/date. No secret values, but adjacent to the identity surface; no ongoing value for the new repo. |
| 10 | `diag-20260514T111252Z/diag_process_summary.txt` | EXCLUDE | Process list snapshot; no ongoing value. |
| 11 | `Dockerfile` | EXCLUDE (superseded) | Ubuntu-base variant; WO-MT5GW-0002 imports `Dockerfile.kasmvnc` only, renamed to `Dockerfile`. |
| 12 | `Dockerfile.kasmvnc` | IMPORT | Build recipe, no secrets. Imported as `Dockerfile` per WO-MT5GW-0002. |
| 13 | `.dockerignore` | IMPORT | Trivial ignore list, no secrets. |
| 14 | `evidence/t1_algo_trading_journal_proof.png` | EXCLUDE | Screenshot is clean (no identity visible) but WO-MT5GW-0002 excludes **all** PNGs regardless of classification. |
| 15 | `evidence/t1_d12_20260513T185757Z.png` | EXCLUDE | Same — clean but PNG, excluded per WO-MT5GW-0002. |
| 16 | `rpyc_server.py` | IMPORT | No secrets. Security-relevant: this is an RPyC classic `SlaveService` with `allow_public_attrs`/`allow_all_attrs` both `True` — unauthenticated remote code execution by design (that's the point — it's how NEO/Solo drive `MetaTrader5` remotely). Not a leak; a standing design risk to carry forward, mitigated only by network isolation (see Task 4 proposal). Imported to `bridge/rpyc_server.py`. |
| 17 | `start.sh` | EXCLUDE (superseded) | Ubuntu-base variant; WO-MT5GW-0002 imports `start.sh.kasmvnc` only, renamed to `start.sh`, with the T2 fix applied. |
| 18 | `start.sh.kasmvnc` | IMPORT | No secrets; redacts password-pattern lines from its own log output. Imported as `start.sh` per WO-MT5GW-0002, with the T2 fix applied on top (see `docs/evidence/WO-MT5GW-0002.md`). |
| 19 | `test-h3-clean-restart/docker-compose.yml` | EXCLUDE | Compose files are out of scope for WO-MT5GW-0002's Task 2 import list (see note below). Contains a literal short-form VNC password value. |
| 20 | `test-h3-clean-restart/evidence/h3_clean_20260514T144326Z.png` | EXCLUDE | PNG; title bar shows a real login number + server name. |
| 21 | `test-h3-long-wait/docker-compose.yml` | EXCLUDE | Out of scope (compose); literal short-form VNC password value; also a host bind-mount path. |
| 22 | `test-h3-long-wait/evidence/h3_long_baseline_20260514T144637Z.png` | EXCLUDE | PNG; title bar shows a real login number + server name. |
| 23 | `test-h3-long-wait/evidence/h3_long_t30_20260514T151752Z.png` | EXCLUDE | PNG; title bar shows a real login number + server name. |
| 24 | `test-h3-long-wait/evidence/h3_long_wait_probe_log_t30.txt` | IMPORT | Clean — version + timing + generic IPC-timeout error only, no identity. Explicitly named "the clean probe log" in WO-MT5GW-0002 Task 2. Corroborating evidence for the T2 root-cause finding. |
| 25 | `test-K1-kasmvnc/docker-compose.yml` | EXCLUDE | Out of scope (compose); literal short-form VNC password value. |
| 26 | `test-K1-kasmvnc/evidence/k1_kasm_20260514T121123Z.png` | EXCLUDE | Screenshot is clean but PNG, excluded per WO-MT5GW-0002. |
| 27 | `test-K2-kasmvnc/docker-compose.yml` | EXCLUDE | Out of scope (compose); literal short-form VNC password value. |
| 28 | `test-K3-kasmvnc/docker-compose.yml` | EXCLUDE | Out of scope (compose); literal short-form VNC password value; also a host bind-mount path. |
| 29 | `test-K3-kasmvnc/evidence/k3_kasm_20260514T121705Z.png` | EXCLUDE | PNG; title bar shows a real login number + server name. |
| 30 | `test-T1-debian12/docker-compose.yml` | EXCLUDE | Out of scope (compose); literal short-form VNC password value. |
| 31 | `test-T1/docker-compose.yml` | EXCLUDE | Out of scope (compose); literal short-form VNC password value. |
| 32 | `test-T2-debian12/docker-compose.yml` | EXCLUDE | Out of scope (compose); literal short-form VNC password value. |
| 33 | `test-T2/docker-compose.yml` | EXCLUDE | Out of scope (compose); literal short-form VNC password value. |
| 34 | `test-T3-debian12/docker-compose.yml` | EXCLUDE | Out of scope (compose); literal short-form VNC password value; also a host bind-mount path. |
| 35 | `test-T3-debian12/evidence/t3_d12_20260514T094846Z.png` | EXCLUDE | PNG; title bar shows a real login number + server name. |
| 36 | `test-T3-debian12/evidence/t3_d12_login_state_20260514T093800Z.png` | EXCLUDE | PNG; explicit login dialog showing a real login number + server name. |
| 37 | `test-T3-debian12/evidence/t3_d12_probe_result.json` | IMPORT | Clean — already redaction-aware by original design (`password_printed: false`, `account_info: null`). Explicitly named in WO-MT5GW-0002 Task 2's "clean ... JSON files." |
| 38 | `test-warmup-revalidate/docker-compose.yml` | EXCLUDE | Out of scope (compose); literal short-form VNC password value. |
| 39 | `test-warmup-revalidate/evidence/w2_post_probe_state_20260514T140153Z.png` | EXCLUDE | PNG; title bar shows a real login number + server name. |
| 40 | `test-warmup-revalidate/evidence/w2_pre_probe_login_dialog_20260514T135855Z.png` | EXCLUDE | PNG; explicit login dialog showing a real login number + server name. |
| 41 | `warmup-ftmo-practice/docker-compose.yml` | EXCLUDE | Out of scope (compose); literal short-form VNC password value; also a host bind-mount path. |
| 42 | `warmup-ftmo-practice/evidence/w1_20260514T131300Z.png` | EXCLUDE | PNG; title bar shows a real login number + server name. |
| 43 | `warmup-ftmo-practice/evidence/w1_warmed_state_metadata_20260514T131500Z.json` | IMPORT | Clean — filenames + sha256 hashes only; already flags the account-credential file as sensitive without exposing its content. Explicitly named in WO-MT5GW-0002 Task 2's "clean ... JSON files." |

## Summary

- **Imported (7):** `Dockerfile.kasmvnc`→`Dockerfile`, `start.sh.kasmvnc`→`start.sh` (with T2 fix), `rpyc_server.py`→`bridge/rpyc_server.py`, `.dockerignore`, plus the two design/audit docs already exported (`docs/DESIGN.md`, `docs/evidence/r2d2_audit_verdict.md`) and the three clean probe/JSON files (`h3_long_wait_probe_log_t30.txt`, `t3_d12_probe_result.json`, `w1_warmed_state_metadata_20260514T131500Z.json`).
- **Excluded — all 11 evidence PNGs:** 8 leak a real login number + server name in the MT5 title bar or login dialog (invisible to gitleaks — image content, not text); 3 are clean but excluded anyway per WO-MT5GW-0002's blanket PNG exclusion.
- **Excluded — all 11 `docker-compose.yml` test files:** every one hardcodes a literal short-form VNC password. WO-MT5GW-0002's Task 2 file list does not name them, so I read the scope as **not approved for import this round** — the "compose files: VNC_PW → `${VNC_PW}`" instruction is treated here as a standing redaction rule for whenever a compose file *is* imported (e.g. the future `mt5-vantage-paper` instance), not as approval to bring these 11 legacy test-harness files in now, since they also predate the `mt5-<broker>-<env>` naming convention. **Flagging this reading explicitly — correct me if the intent was to import them redacted.**
- **Excluded — 10 diagnostic files:** low ongoing value; one leaks this host's own hostname.
