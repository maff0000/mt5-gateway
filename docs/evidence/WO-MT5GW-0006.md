# WO-MT5GW-0006 — Shared Broker Directory Template + Retest

All work on dell-debian except the deploy-key exception below (GitHub settings, explicitly authorized). No identifiers appear anywhere in this document.

## One-off exception — deploy keys added via `gh` (2026-09-26)

Matt authorized a **one-off exception** to risk acceptance 2 (the broad `gh` token is otherwise scoped to PR operations only on `maff0000/mt5-gateway` and `maff0000/tron`): used it to add the two repo-scoped deploy keys already generated on dell-debian (WO-MT5GW-0001A), via exactly:

```
gh repo deploy-key add /root/.ssh/deploy_mt5-gateway_ed25519.pub --repo maff0000/mt5-gateway --allow-write --title dell-debian
gh repo deploy-key add /root/.ssh/deploy_tron_ed25519.pub --repo maff0000/tron --allow-write --title dell-debian
```

No other settings, repos, or admin actions touched. Both keys verified via `ssh -T git@github.com` using each repo's dedicated key — both authenticated successfully; scoping itself was verified by an actual push, not just the SSH greeting (see below). All previously-stacked `mt5-gateway` branches (`WO-0002` through `WO-0005`) pushed successfully and PRs opened:
- `wo/WO-MT5GW-0002` → `main`: https://github.com/maff0000/mt5-gateway/pull/1
- `wo/WO-MT5GW-0003` → `wo/WO-MT5GW-0002`: https://github.com/maff0000/mt5-gateway/pull/2
- `wo/WO-MT5GW-0004` → `wo/WO-MT5GW-0003`: https://github.com/maff0000/mt5-gateway/pull/3
- `wo/WO-MT5GW-0005` → `wo/WO-MT5GW-0004`: https://github.com/maff0000/mt5-gateway/pull/4

This document (and this branch) covers WO-MT5GW-0006 itself.
