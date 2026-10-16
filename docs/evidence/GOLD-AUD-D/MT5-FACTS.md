# GOLD-AUD-D mirror note: MT5 gateway facts

Mirror note of the read-only audit `GOLD-AUD-D` (GOLD MVP lane D). The primary evidence is in `maff0000/GOAL` at `audits/2026-10-15/gold-mvp/lanes/GOLD-AUD-D/` on branch `wo/GOLD-AUD-D-evidence` (local at the time of writing; not pushed, no pull request). This note carries only the gateway facts and is written to the public-repository standard: no addresses, hostnames, ports, account or credential identifiers. It changes no source, compose or template file and nothing outside `docs/evidence/GOLD-AUD-D/`.

## 1. Revision read

`main` = `6263d61f4cb0d4d5b16337e67c30f409bc9c5051` (46 commits; PR #9 merged). It did not move during the audit. Issue #10 ("Gate A follow-up") was open.

## 2. State after the MT5-GW-001 consolidation (re-confirmed, read-only)

- Present and tested: instance configuration schema, `mt5ctl` lint and render tool (refuses unless the code constant `LIVE_PROVISIONING_ENABLED` is set), two-instance disjointness check, documentation set, CI workflow. In a scratch clone: `105 passed, 3 xfailed` (the three strict expected failures encode known hazards H1 to H3). The `validate` workflow concluded `success` for the head.
- Absent (searched in all Python, tool, shell, image and YAML/JSON sources for the operation and error names of the template contract): any typed operation, `client_order_id`, reconcile operation, `TIMEOUT_UNKNOWN_OUTCOME`, place-order call. The only control surface is the stock remote-execution bridge (`bridge/rpyc_server.py`, 9 lines), which exposes every attribute without authentication.
- No in-container DEMO latch: the start script and image do not read the expected-mode key; DEMO-only is enforced by the lint and render tool, which refuses unless the code constant `LIVE_PROVISIONING_ENABLED` is set. No verify command; no Unix-domain-socket transport; image build is not hermetic.
- The template contract (operation set, idempotency, error taxonomy, safeguards M1..M12, increments 0..6) is a design held in the programme repository and is unapproved.
- TRON must not be connected to the existing bridge (ADR-MT5-001). Nothing in this audit connected to it.

## 3. Gap rows (primary evidence `GAP-MATRIX.md`)

| Row | Capability | Status | Maps to |
|---|---|---|---|
| G-25 | Typed allow-list service | missing | `MT5-GW-003`, template increment 2 |
| G-26 | DEMO environment assertion | partial (lint and render only) | `MT5-GW-003`, increments 2 and 3 |
| G-27 | Place order with broker-side SL/TP | missing | `MT5-GW-004`, increment 4 |
| G-28 | Typed error taxonomy | missing | `MT5-GW-003` |
| G-29 | `TIMEOUT_UNKNOWN_OUTCOME` handling | missing | `MT5-GW-003`, `TRON-T2` |
| G-30 | Protected transport and instance configuration contract | partial | `MT5-GW-002`, increments 1 and 3 |
| G-31 | Reproducible image provenance | missing | `MT5-GW-002`, increment 3 |
| G-32 | Typed reads (positions, orders, deals, account, symbol spec) | missing | `MT5-GW-004`, increment 3 |

## 4. Findings that concern this repository

F-D-09 (the repository already holds template increment 1 and CI while the programme backlog still shows the gateway items at their earlier states), F-D-10 (no in-container DEMO latch), F-D-11 (no typed gateway; the raw bridge is the only surface), F-D-22 (two exposure statements in `docs/KNOWN-LIMITATIONS.md` are reported by the maintainers and were not re-verified, because no probe was permitted). Findings only: nothing here changes the repository or issue #10.

## 5. Increments that touch this repository

INC-08 (clear issue #10), INC-09 (digest-pinned image), INC-10 (typed service with a fake backend and conformance suite), INC-13 (first DEMO instance, read-only proof), INC-15 and INC-16 (lifecycle and restart proofs, write approval). Order and gates: primary evidence `INCREMENTS.md` and `ORDERING.md`. The typed gateway must exist and be approved before accepted TRON integration or PAPER proof.
