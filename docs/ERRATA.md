# Errata

Dated corrections to statements in this repository. The historical records under `docs/evidence/`
(and the work-order files) are **preserved unedited**: they are history, and rewriting them would itself
be a form of evidence tampering. Corrections live here and are linked from
[EVIDENCE-INDEX.md](EVIDENCE-INDEX.md).

Entry dates are the date the erratum was written. Source of the findings: the independent audit of the
pull-request consolidation (2026-10-15, GOAL audit record) and a re-read of the code for this
documentation set.

## 2026-10-15

### E1. The repository is PUBLIC, not private (audit finding F2)

Affected: `docs/evidence/WO-MT5GW-0010.md` section 4 ("Visibility-change record") and the text of pull
request #8.

Those say `maff0000/mt5-gateway` has `isPrivate = true` and record a decision that it is private. That
is **wrong**. The repository has been **public since its creation on 2026-09-26**, per the independent
audit's check against GitHub on 2026-10-15 (`maff0000/tron` is also public, by a recorded decision). The WO-MT5GW-0010
statement was therefore false when written and remained false afterwards.

Consequences recorded:

- Everything committed here has been publicly readable since 2026-09-26, including the history.
- The wider rule that follows is the one this documentation set applies: public-repository rules for
  every file (placeholders only, no real broker addresses, internal addresses, account numbers or
  credentials).
- Making the repository private is a separate decision for the owner; it would not change history.
  Until then, nothing here may assume privacy.
- The `gh` token risk acceptance in WO-MT5GW-0002/0010 was phrased around the repositories going
  private; its operative trigger (revisit before live broker credentials are used) is unaffected.

### E2. Two broker server addresses remain reachable in git history

Affected: `docs/evidence/WO-MT5GW-0006.md`, lines recorded in the evidence section "3b".

WO-MT5GW-0010 redacted two broker server addresses from the current text and said "no other
non-private IPv4 address exists", which is true of the tip but not of history. The unredacted text
remains reachable:

| Fact | Value |
|---|---|
| Introduced | commit `b5170ff` (blob `d271672`) |
| Present at | the heads of pull requests #5, #6 and #7 and in the corresponding GitHub pull refs |
| Redacted | commit `fbcd433` (in pull request #8) |
| Exposure window | the repository has been public since 2026-09-26 |
| Sensitivity (audit ruling) | low: broker server endpoints, no credential, no account identifier |
| Still holding the unredacted blob | the remote branches for WO-MT5GW-0006 to 0008 and their `reconcile/pre/*` tags (audit finding F13) |

Merging this work does not remove the blob: the remote branches for WO-MT5GW-0006, 0007 and 0008 and
their `reconcile/pre/WO-MT5GW-0006` to `-0008` tags still hold the unredacted blob, and so do the GitHub
pull refs. Only deleting those refs (and a history rewrite plus GitHub support purge of cached views)
would change that; none of that is done or decided.

Decision (accepted and recorded, option A of the audit): history is **not rewritten**. Rewriting would
invalidate every commit hash and the recovery tags and could not remove copies already cloned or cached.
Do not copy the addresses anywhere; this repository refers to them only as "two broker server addresses".

### E3. Running image `0.2.0-rc6`: provenance and label

The image tagged `0.2.0-rc6` that was running when the maintainers' read-only verification was made
contains a `start.sh` that matches the WO-MT5GW-0008 version, **not** the WO-MT5GW-0010 tip. Its
Dockerfile label `gateway.image.tag` still says `rc2` (and the `wo` label names an older diagnostic work
order). The labels are stale metadata and must not be used as version evidence. Decision: `rc6` is kept
as **historical rollback evidence only**, is not relabelled, and a new candidate is to be built from
`main`. The skeleton uses a placeholder tag (`CANDIDATE-unbuilt-from-main`) for that reason.

### E4. WO-MT5GW-0006 "first verified-live" wording is slightly strong

`docs/evidence/WO-MT5GW-0006.md` calls the result "the first genuine, verified-live MT5 Python API
success". The evidence is: established external sockets observed in `/proc/net/tcp`, `initialize()` returning
`True` with `last_error` = success, `terminal_build` 6230, and `trade_mode` = demo, repeated after a
restart. It rests on established sockets plus `initialize()` in demo mode. **No authenticated-login read**
was taken (by instruction: no login, name or balance was read). Read it as "network-connected
and `initialize()` succeeded against a DEMO terminal", not as proof of an authenticated, trade-capable
session. Likewise, its explanation that the earlier `-10005` failures were caused by a missing broker
directory is the work order's attribution and was not isolated by a controlled experiment.

### E5. DESIGN.md "redaction enforced" overstates `start.sh`

`docs/DESIGN.md` (a May 2026 design export) says redaction is "enforced at start.sh: any line containing
/Password=/ ... is dropped". The actual `start.sh` defines a `sed` filter that **masks**
`Password=...` values, and applies it **only** to the pipe of the credentialed MT5 launch. It is not
applied to other output, and it does not drop lines. Redaction there is a best-effort filter, not an
enforced guarantee. Other design statements that no longer match the build (Ubuntu base, TigerVNC, a
bind-mounted `mt5.ini`, a one-file secret, health check with `nc`, xdotool fallback) are listed in
[EVIDENCE-INDEX.md](EVIDENCE-INDEX.md).

### E6. Superseded experimental conclusions (not errors, but no longer current)

These were reasonable at the time and are recorded as superseded in the index, not as mistakes:

- The `-10005 IPC timeout` was attributed to terminal build 6230 / risk R12 (WO-MT5GW-0002, 0003) and
  later to "runtime state accumulated over lifetime" (WO-MT5GW-0005). Superseded by WO-MT5GW-0006's
  attribution to missing broker routing data.
- "A package version bump was ruled out" (WO-MT5GW-0002) was withdrawn by the work order's own
  Correction 3.
- Classic VNC authentication (WO-MT5GW-0003 and 0007) does not work with the bundled web client;
  replaced by provisioned Basic Auth (WO-MT5GW-0008).
- "No named volume exists" (WO-MT5GW-0003) was superseded by the persistent volume added in
  WO-MT5GW-0006.

### E7. Documentation versus code, found while preparing this set

- The `--skip-fs` warning text claimed the LIVE marker check is skipped; the code still runs it
  ([CONFIG-REFERENCE.md](CONFIG-REFERENCE.md) section 6). Behaviour was stricter than the message. The
  warning text was corrected in MT5GW-AUDIT-FIX (finding F15).
- The `start.sh` ready banner prints "VNC: localhost:5901", but no listener is bound on that port in
  this image (WO-MT5GW-0003), and the Dockerfile still `EXPOSE`s 5901.
- `LOG_LEVEL`, `EXPECTED_TRADE_MODE`, `BROKER` and `ENVIRONMENT` reach the container environment but
  are not read by `start.sh`; nothing asserts the trade mode at runtime.

No code was changed to address E7; they are recorded for the next code change.
