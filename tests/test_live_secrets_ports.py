import os, stat, pytest

def _live(ctl, make_instance, tmp_path, monkeypatch, live_block, image="mt5-gateway:CANDIDATE-live-capable", mode=0o444, root=True, marker=True):
    monkeypatch.setattr(ctl, "is_root_owned", lambda st: root)
    marker_path = tmp_path / "gate.marker"
    if marker:
        marker_path.write_text("fixture-approval-record\n"); os.chmod(marker_path, mode)
    lines = "".join(f"  {k}: {str(v).replace('@M@', str(marker_path)).lower() if isinstance(v, bool) else str(v).replace('@M@', str(marker_path))}\n" for k, v in live_block.items())
    edit = {"environment: DEMO": "environment: LIVE", "account_class: demo-unfunded": "account_class: live-capital",
            "image: mt5-gateway:CANDIDATE-unbuilt-from-main": f"image: {image}",
            "timezone: Etc/UTC": "timezone: Etc/UTC" + ("\nlive:\n" + lines.rstrip("\n") if lines else "")}
    cfg = make_instance(name="mt5-example-live-a1", edit=edit)
    return ctl.lint(cfg)[0], cfg


FULL = {"enable": True, "capital_gate_marker": "@M@", "live_capable_build": True}


def test_live_all_gates_pass_lint_but_render_refuses(ctl, make_instance, tmp_path, monkeypatch):
    errs, cfg = _live(ctl, make_instance, tmp_path, monkeypatch, FULL)
    assert errs == []
    rerrs, info = ctl.render(cfg, tmp_path / "out", run_docker=False)
    assert info is None and any("LIVE provisioning is not enabled" in e for e in rerrs)


@pytest.mark.parametrize("label,block,kw,frag", [
    ("no live block", {}, {}, "live.enable"),
    ("enable false", {**FULL, "enable": False}, {}, "live.enable"),
    ("no marker key", {"enable": True, "live_capable_build": True}, {}, "no live.capital_gate_marker"),
    ("marker missing file", FULL, {"marker": False}, "does not exist"),
    ("marker writable", FULL, {"mode": 0o644}, "0444"),
    ("marker not root", FULL, {"root": False}, "0444"),
    ("no build flag", {"enable": True, "capital_gate_marker": "@M@"}, {}, "live_capable_build"),
    ("default image tag", FULL, {"image": "mt5-gateway:0.3.0"}, "live-capable"),
])
def test_live_refusal_matrix(ctl, make_instance, tmp_path, monkeypatch, label, block, kw, frag):
    errs, _ = _live(ctl, make_instance, tmp_path, monkeypatch, block, **kw)
    assert any(frag in e for e in errs), (label, errs)


def test_live_empty_block_via_yaml_is_rejected(ctl, make_instance):
    # `live:` with no children is not valid in the strict subset
    with pytest.raises(ctl.ParseError):
        ctl.parse_yaml("live:\n")


@pytest.mark.parametrize("block", ["enable: true", "capital_gate_marker: /x/y", "live_capable_build: true"])
def test_demo_can_never_carry_live_flags(ctl, make_instance, block):
    cfg = make_instance(edit={"timezone: Etc/UTC": "timezone: Etc/UTC\nlive:\n  " + block})
    assert any("must not carry live flags" in e for e in ctl.lint(cfg)[0])


def test_demo_with_live_enable_false_is_ok(ctl, make_instance):
    cfg = make_instance(edit={"timezone: Etc/UTC": "timezone: Etc/UTC\nlive:\n  enable: false"})
    assert ctl.lint(cfg)[0] == []


def test_new_refuses_live(ctl, tmp_path):
    assert ctl.new(tmp_path, "mt5-example-live-a1")


# ---- secrets contract
def sec_dir(cfg, ctl):
    import re
    return re.search(r"dir: (\S+)", cfg.read_text()).group(1)


def test_secret_dir_mode(ctl, make_instance):
    cfg = make_instance(); d = sec_dir(cfg, ctl); os.chmod(d, 0o750)
    assert any("must be 0700" in e for e in ctl.lint(cfg)[0])


@pytest.mark.parametrize("mode", [0o644, 0o640, 0o400, 0o660])
def test_secret_file_mode(ctl, make_instance, mode):
    cfg = make_instance(); os.chmod(os.path.join(sec_dir(cfg, ctl), "mt5_password"), mode)
    assert any("must be 0600" in e for e in ctl.lint(cfg)[0])


def test_secret_missing_unexpected_empty_symlink(ctl, make_instance, tmp_path):
    cfg = make_instance(); d = sec_dir(cfg, ctl)
    os.remove(os.path.join(d, "vnc_password"))
    assert any("vnc_password is missing" in e for e in ctl.lint(cfg)[0])
    open(os.path.join(d, "vnc_password"), "w").close(); os.chmod(os.path.join(d, "vnc_password"), 0o600)
    assert any("is empty" in e for e in ctl.lint(cfg)[0])
    open(os.path.join(d, "stray"), "w").write("x"); os.chmod(os.path.join(d, "stray"), 0o600)
    assert any("unexpected entry 'stray'" in e for e in ctl.lint(cfg)[0])
    os.remove(os.path.join(d, "stray")); os.remove(os.path.join(d, "mt5_login"))
    os.symlink("/etc/hostname", os.path.join(d, "mt5_login"))
    assert any("not a regular file" in e for e in ctl.lint(cfg)[0])


def test_secrets_dir_inside_repo_or_config_refused(ctl, make_instance, tmp_path):
    cfg = make_instance(); old = sec_dir(cfg, ctl)
    inrepo = ctl.REPO / "tests" / "_tmp_secret_probe"
    cfg.write_text(cfg.read_text().replace(old, str(inrepo)))
    assert any("inside the repository" in e for e in ctl.lint(cfg)[0])
    incfg = cfg.parent / "secrets"
    cfg.write_text(cfg.read_text().replace(str(inrepo), str(incfg)))
    assert any("outside the config directory" in e for e in ctl.lint(cfg)[0])


def test_lint_never_reads_secret_values(ctl, make_instance, monkeypatch):
    cfg = make_instance(); d = sec_dir(cfg, ctl)
    real_open = open
    def guard(p, *a, **k):
        assert not str(p).startswith(d), "secret file opened"
        return real_open(p, *a, **k)
    monkeypatch.setattr("builtins.open", guard)
    monkeypatch.setattr(type(cfg), "read_text", lambda self, *a, **k: real_open(self).read() if not str(self).startswith(d) else (_ for _ in ()).throw(AssertionError("secret read")))
    assert ctl.lint(cfg)[0] == []


# ---- ports
def test_ui_port_binds_loopback_only(ctl, make_instance, tmp_path):
    cfg = make_instance(ui=16901)
    errs, info = ctl.render(cfg, tmp_path / "o", run_docker=False)
    assert errs == []
    env = (tmp_path / "o" / "instance.env").read_text()
    assert "OPERATOR_UI_BIND=127.0.0.1" in env and "0.0.0.0" not in env
    assert info["plan"]["published"] == ["127.0.0.1:16901"]


def test_no_ui_means_no_port_env(ctl, make_instance, tmp_path):
    errs, info = ctl.render(make_instance(), tmp_path / "o", run_docker=False)
    assert errs == [] and "OPERATOR_UI" not in (tmp_path / "o" / "instance.env").read_text()
    assert info["plan"]["published"] == []


def test_env_file_has_no_secret_names_or_values(ctl, make_instance, tmp_path):
    cfg = make_instance(); ctl.render(cfg, tmp_path / "o", run_docker=False)
    txt = (tmp_path / "o" / "instance.env").read_text().lower()
    assert "demo-fixture" not in txt and "password=" not in txt and "login=" not in txt


def test_live_capable_tag_is_case_insensitive(ctl, make_instance, tmp_path, monkeypatch):
    errs, _ = _live(ctl, make_instance, tmp_path, monkeypatch, FULL, image="mt5-gateway:CANDIDATE-Live-Capable")
    assert errs == []


def test_live_config_passing_lint_prints_render_refusal_warning(ctl, make_instance, tmp_path, monkeypatch, capsys):
    _, cfg = _live(ctl, make_instance, tmp_path, monkeypatch, FULL)
    errs, warns = ctl.lint(cfg)
    assert errs == [] and any("REFUSES LIVE" in w for w in warns)
    ctl.main(["lint", str(cfg), "--peers"])
    assert "WARNING" in capsys.readouterr().out


# ---- F2: parent path checks
def test_symlinked_parent_component_rejected(ctl, make_instance, tmp_path):
    cfg = make_instance(); d = sec_dir(cfg, ctl)
    link = tmp_path / "alias"; os.symlink(os.path.dirname(d), link)
    cfg.write_text(cfg.read_text().replace(d, str(link / os.path.basename(d))))
    assert any("symlinked component" in e for e in ctl.lint(cfg)[0])


@pytest.mark.parametrize("mode", [0o770, 0o757, 0o777])
def test_writable_parent_rejected(ctl, make_instance, mode):
    cfg = make_instance(); os.chmod(os.path.dirname(sec_dir(cfg, ctl)), mode)
    assert any("parent directory is group- or world-writable" in e for e in ctl.lint(cfg)[0])


def test_hard_linked_secret_rejected(ctl, make_instance, tmp_path):
    cfg = make_instance(); d = sec_dir(cfg, ctl)
    os.link(os.path.join(d, "mt5_login"), tmp_path / "other_link")
    assert any("hard links" in e for e in ctl.lint(cfg)[0])
