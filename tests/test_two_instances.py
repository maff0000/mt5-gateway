"""Second-independent-DEMO-instance proof: two instances rendered from ONLY their
config files. No application source is touched between them (asserted by hashing
every tracked source file before/after). No container is started."""
import hashlib, json, os, shutil, subprocess
import pytest

HAVE_DOCKER = shutil.which("docker") and subprocess.run(["docker", "compose", "version"], capture_output=True).returncode == 0


def tree_hash(ctl):
    out = subprocess.run(["git", "ls-files", "-z"], cwd=ctl.REPO, capture_output=True, check=True).stdout.split(b"\0")
    h = hashlib.sha256()
    for f in sorted(x for x in out if x):
        p = ctl.REPO / f.decode()
        if p.is_file():
            h.update(f + b"\0" + p.read_bytes())
    return h.hexdigest()


@pytest.fixture
def pair(ctl, tmp_path, make_instance):
    a = make_instance(name="mt5-example-demo-a1", ui=16901)
    # second instance: own tmp area so secrets/config dirs are distinct
    sub = tmp_path / "second"; sub.mkdir()
    import types
    def mk2():
        text = ctl.SKELETON.read_text().replace("mt5-example-demo-a1", "mt5-example-demo-b2")
        cfgdir = sub / "cfg" / "mt5-example-demo-b2"; cfgdir.mkdir(parents=True)
        sec = sub / "secrets" / "mt5-example-demo-b2"; sec.mkdir(parents=True); os.chmod(sec.parent, 0o755); os.chmod(sec, 0o700)
        text = text.replace("/srv/example/secrets/mt5-example-demo-b2", str(sec)).replace("operator_ui: none", "operator_ui: 16902")
        (cfgdir / "instance.yaml").write_text(text)
        for k in ctl.SECRET_KEYS:
            (sec / k).write_text("demo-fixture\n"); os.chmod(sec / k, 0o600)
        return cfgdir / "instance.yaml"
    return a, mk2()


def test_two_instances_disjoint_and_no_source_edit(ctl, pair, tmp_path):
    a, b = pair
    before = tree_hash(ctl)
    assert ctl.lint(a, peers=[b]) == ([], [])
    assert ctl.lint(b, peers=[a]) == ([], [])
    pa, pb = ctl.plan(ctl.load_config(a)), ctl.plan(ctl.load_config(b))
    for k in ("project", "container", "network", "volume", "secrets_dir"):
        assert pa[k] != pb[k], k
    assert not set(pa["published"]) & set(pb["published"])
    assert tree_hash(ctl) == before  # zero application-source edits


def test_collision_detected(ctl, pair, make_instance):
    a, b = pair
    b.write_text(b.read_text().replace("operator_ui: 16902", "operator_ui: 16901"))
    assert any("published port" in e for e in ctl.lint(a, peers=[b])[0])
    b.write_text(a.read_text())
    errs = ctl.lint(a, peers=[b])[0]
    assert all(any(k in e for e in errs) for k in ("project", "network", "volume", "secrets_dir"))


@pytest.mark.skipif(not HAVE_DOCKER, reason="docker compose not available")
def test_rendered_compose_config_disjoint(ctl, pair, tmp_path):
    a, b = pair
    before = tree_hash(ctl)
    docs = []
    for cfg, out in ((a, tmp_path / "oa"), (b, tmp_path / "ob")):
        errs, info = ctl.render(cfg, out, peers=[])
        assert errs == [], errs
        docs.append(json.loads((out / "compose.rendered.json").read_text()))
    def facts(d):
        svc = d["services"]["mt5-gateway"]
        return {"project": d["name"], "container": svc["container_name"],
                "networks": {n["name"] for n in d["networks"].values()},
                "volumes": {v["name"] for v in d["volumes"].values()},
                "ports": {(p.get("host_ip"), p.get("published")) for p in svc.get("ports", [])},
                "mem": svc["mem_limit"], "secrets": {s["source"] for s in svc["secrets"]}}
    fa, fb = facts(docs[0]), facts(docs[1])
    assert fa["project"] != fb["project"] and fa["container"] != fb["container"]
    assert not fa["networks"] & fb["networks"] and not fa["volumes"] & fb["volumes"]
    assert not fa["ports"] & fb["ports"]
    for f in (fa, fb):
        assert all(h == "127.0.0.1" for h, _ in f["ports"]) and f["ports"]
    secret_files = [s["file"] for d in docs for s in d["secrets"].values()]
    assert len(secret_files) == len(set(secret_files)) == 6
    assert tree_hash(ctl) == before


@pytest.mark.skipif(not HAVE_DOCKER, reason="docker compose not available")
def test_render_without_ui_publishes_nothing(ctl, make_instance, tmp_path):
    cfg = make_instance()
    errs, _ = ctl.render(cfg, tmp_path / "o")
    assert errs == []
    d = json.loads((tmp_path / "o" / "compose.rendered.json").read_text())
    assert "ports" not in d["services"]["mt5-gateway"]
    blob = json.dumps(d)
    assert "0.0.0.0" not in blob and "demo-fixture" not in blob


# ---- N1: secrets-dir disjointness must hold after path normalisation
def _sec(cfg):
    import re
    return re.search(r"dir: (\S+)", cfg.read_text()).group(1)


@pytest.mark.parametrize("variant", ["trailing", "double_slash", "dot", "nested_child", "nested_parent", "symlink_parent"])
def test_peer_secrets_dir_evasions_rejected(ctl, pair, tmp_path, variant):
    a, b = pair
    sa = _sec(a)
    if variant == "trailing":
        alias = sa + "/"
    elif variant == "double_slash":
        alias = sa.replace("/secrets/", "//secrets//")
    elif variant == "dot":
        alias = sa.replace("/secrets/", "/./secrets/./")
    elif variant == "nested_child":
        alias = sa + "/child"
    elif variant == "nested_parent":
        alias = os.path.dirname(sa)
    else:
        link = tmp_path / "linkparent"
        os.symlink(os.path.dirname(sa), link)
        alias = str(link / os.path.basename(sa))
    b.write_text(b.read_text().replace(_sec(b), alias))
    errs = ctl.check_peers(ctl.load_config(a), [b])
    assert any("secrets_dir" in e for e in errs), (variant, errs)
    # also detected from the other side
    errs = ctl.check_peers(ctl.load_config(b), [a])
    assert any("secrets_dir" in e for e in errs), (variant, errs)


def test_distinct_sibling_secrets_dirs_not_flagged_as_nested(ctl, pair):
    a, b = pair
    assert not any("secrets_dir" in e for e in ctl.check_peers(ctl.load_config(a), [b]))
