# Recovery

Two separate topics: recovering a running **instance**, and recovering the **source** history of this
repository. Placeholders as in the [operator guide](OPERATOR-GUIDE.md). Nothing here has been
exercised against a container built from the current template; instance steps cite the historical
evidence where one exists.

## Part 1. Instance recovery

### What state exists where

| State | Where | Lost when |
|---|---|---|
| Wine prefix, MT5 install, terminal config, logs, anything added through the terminal UI | named data volume (`data_volume`) mounted at `/home/headless` | the volume is removed |
| Credentials | the host secrets directory, and (rendered at start) a tmpfs in the container | the secrets directory is deleted; the tmpfs is lost at every container stop |
| Broker directory seed | the host `servers_dat` file | the file is deleted. It is copied into the volume on first boot only |
| Non-secret configuration | `instance.yaml` and the generated `rendered/instance.env` | deleted; `render` regenerates `instance.env` |
| Step and bridge logs | container `/tmp` | container recreate |
| Positions, orders, balance | **the broker**. The gateway keeps no authoritative trading state | never lost by gateway actions |

Stopping, restarting, recreating or destroying an instance never closes or cancels anything: nothing
in this repository sends order calls on those events. Broker-side SL/TP and pending orders persist at
the broker whether or not an instance is running.

### R1. Restart (container hung or unhealthy)

```bash
docker restart <instance>
docker exec <instance> tail -n 40 /tmp/start_sh.log
```

Expected: install steps log "already installed" and the seed log says "already present -- not
touching it", secrets are read again, the terminal reconnects. This was proven on the earlier
deployment in WO-MT5GW-0006 (a genuine `docker restart`, identical `initialize()` result before and
after). Afterwards re-run the manual verification in the operator guide, section 7.

### R2. Recreate (container damaged, image changed, secret replaced)

```bash
ENVF=/srv/<root>/instances/<instance>/rendered/instance.env
docker compose --env-file "$ENVF" -f deploy/compose.instance.yml [-f deploy/compose.operator-ui.yml] \
  up -d --force-recreate
```

The volume is reattached; the terminal is not reinstalled. Not run against this template.

### R3. Volume lost or deliberately replaced

1. Make sure nothing depends on terminal-side state you cannot recreate (it is reproducible from
   config and secrets; only terminal UI customisations and journals are lost).
2. Start the instance again as in operator guide section 7. A fresh volume repeats first boot: MT5,
   Wine Python and pip packages are installed (about 100 seconds seen historically), the seed is copied
   once, and credentials are injected from the secrets again. No manual terminal login is needed for the
   credentials; `start.sh` supplies them in the start config.
3. Re-verify. The first-boot downloads are unpinned: the terminal build you get is whatever MetaQuotes
   currently serves, which may differ from before.

There is no repository-supported volume backup procedure. If you need one, that is a host-level
decision outside this repository.

### R4. Secrets lost, rotated or re-provisioned

1. Recreate the directory: `install -d -m 0700 /srv/<root>/secrets/<instance>`, then the three files
   (`mt5_login`, `mt5_password`, `vnc_password`) at mode 0600, filled by the owner with an editor. Tooling
   never reads, copies or prints values.
2. `mt5ctl lint` to check names, modes and non-emptiness.
3. Restart or, if an editor replaced the files, recreate (R2) so the container picks up the new files.
   `start.sh` reads secrets only at container start.
4. Re-verify that the UI returns 401 and that the start log shows credentials were present.

If a secret was exposed, rotation at the broker and replacement here is the owner's action; this
repository has no rotation tooling.

### R5. Host reboot or Docker daemon restart

`restart` defaults to `no`, so instances do not return. Start each one manually (operator guide
section 7), then verify. Whether `unless-stopped` behaves well with this template is unverified.

### R6. After any recovery

Treat the broker as the source of truth. There is no reconcile or verify tooling here, so look at the
account's positions and orders through the terminal UI or the broker's own interface before anything
writes to the account. Do not connect other systems to the bridge in the meantime.

## Part 2. Source recovery

Why this exists: on 2026-10-15 the eight stacked pull requests (#1 to #8) were consolidated into
`main` as true merge commits. Before that, a maintainer took a complete pre-merge snapshot and local
provenance tags. They guarantee that every pre-merge commit stays recoverable even if history is
rewritten or the remote is damaged.

### What the artefacts are

| Artefact | What it is | Where |
|---|---|---|
| Pre-merge bundle | a single-file `git bundle` of the complete pre-merge repository history (all branches and the GitHub pull-request refs): 25 refs, 28 real commits plus 8 GitHub merge refs, no prerequisite objects ("records a complete history"). Named `mt5-gateway-pre-merge-20261015.bundle`, with a `SHA256SUMS` file | maintainer recovery location, see GOAL audit record |
| Mirror and manifests | a mirror clone, the refs manifest, the live ref listing at that moment, and the preflight and independent-audit reports | maintainer recovery location, see GOAL audit record |
| `reconcile/pre/*` tags | nine annotated tags, one per pre-merge branch head (`main` plus `WO-MT5GW-0002` to `-0008` and `-0010`), created in the maintainer recovery mirror and pushed to the remote on 2026-10-15 (verified via the GitHub API). The bundle was made **before** the tags, so the **bundle does not contain the tags** | the remote repository (`git ls-remote --tags origin 'reconcile/pre/*'`), and the recovery location's mirror |

The tags point at the heads below (public history; the tag names are the stable handles):

| Tag | Points at (pre-merge head) |
|---|---|
| `reconcile/pre/main` | `e6c3781f2c42313a69140bf54b08b95bac243a4a` |
| `reconcile/pre/WO-MT5GW-0002` | `9974babacb6af2cfbe6500c429448520e1342695` |
| `reconcile/pre/WO-MT5GW-0003` | `0e1ad25b9ec75c41e83f92f47a7f4858ad059184` |
| `reconcile/pre/WO-MT5GW-0004` | `f0a875e79b288e151f59fb5e989ae8c6900bffad` |
| `reconcile/pre/WO-MT5GW-0005` | `7ccedcfa5be84ae731f3693bc33159d30fc6b72a` |
| `reconcile/pre/WO-MT5GW-0006` | `b5170ff5cc2a1e7ee742d5ad1c64e92918da9d66` |
| `reconcile/pre/WO-MT5GW-0007` | `8b87f678c6a5bc96f5b0a52dfee1c98eff0e39be` |
| `reconcile/pre/WO-MT5GW-0008` | `a06f1465eb513862c1ad94b1d613c47a3bd1510f` |
| `reconcile/pre/WO-MT5GW-0010` | `720a2e7b1d11c38990defb92e36aa73100a51840` |

Note that the pre-merge history includes the commit that contains two broker server addresses
(see [ERRATA.md](ERRATA.md) E2). The remote branches for WO-MT5GW-0006 to 0008 and their
`reconcile/pre/*` tags still hold the unredacted blob today, merged or not. Restoring it restores them; the repository is public and this was
accepted and recorded.

### Verify the bundle

Get the bundle and its `SHA256SUMS` from the maintainer recovery location (see the GOAL audit record),
into a scratch directory you own. Never run tooling from inside a directory of untrusted files.

```bash
cd /scratch/verify
sha256sum -c SHA256SUMS                       # the bundle's checksum line must say OK
git init verify-repo && cd verify-repo         # `git bundle verify` needs a repository context
git bundle verify ../mt5-gateway-pre-merge-20261015.bundle
#   expected: "The bundle records a complete history."
git bundle list-heads ../mt5-gateway-pre-merge-20261015.bundle
```

The independent audit also restored it as a mirror and found the same 25 refs as the manifest and the
live ref set, a clean `git fsck --full`, and the final pre-merge tree
`5d66f011a40ac8a7e705e19b74fae8b77e03619c` at `wo/WO-MT5GW-0010`.

### Restore from the bundle

```bash
git clone --mirror /scratch/verify/mt5-gateway-pre-merge-20261015.bundle restored.git
git -C restored.git fsck --full
git -C restored.git for-each-ref | wc -l       # expect 25
git -C restored.git rev-parse 'refs/heads/wo/WO-MT5GW-0010^{tree}'
#   expect 5d66f011a40ac8a7e705e19b74fae8b77e03619c
git clone restored.git work && git -C work branch -a
```

Restoring from the bundle reproduces every branch and pull-request ref but **not** the
`reconcile/pre/*` tags. If you need them, recreate them from the table above (the annotation text is
not recoverable from the bundle; the target commits are):

```bash
git -C work tag reconcile/pre/WO-MT5GW-0006 b5170ff5cc2a1e7ee742d5ad1c64e92918da9d66
```

### Verify the live repository against the snapshot

```bash
# every pre-merge head must be an ancestor of current main
for t in main WO-MT5GW-0002 WO-MT5GW-0003 WO-MT5GW-0004 WO-MT5GW-0005 \
         WO-MT5GW-0006 WO-MT5GW-0007 WO-MT5GW-0008 WO-MT5GW-0010; do
  c=$(git rev-parse "reconcile/pre/$t^{commit}")   # in a clone that has the tags
  git merge-base --is-ancestor "$c" origin/main && echo "ok $t" || echo "MISSING $t"
done
# the content consolidated into main equals the last stacked branch
git rev-parse 720a2e7b1d11c38990defb92e36aa73100a51840^{tree}
git rev-parse 46308ba^{tree}                       # both are 5d66f011a40ac8a7e705e19b74fae8b77e03619c
```

In the maintainer clone, at the time this page was written, those two trees were identical
(`5d66f011a40ac8a7e705e19b74fae8b77e03619c`) and the commit `46308ba` is the `main` merge of
pull request #8. If the tags are absent in your clone, use the SHAs in the table directly.

### If history must be restored on the remote

Do not force-push. Follow the repository's rules: no history rewrites, no force pushes, and all work on
feature branches through pull requests. Recovery of the remote itself is a maintainer decision made
with the owner; the bundle and the tag table above are the inputs.
