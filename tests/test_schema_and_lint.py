import os, json, stat, pytest

BASE = "instances/_skeleton/instance.yaml"


def L(ctl, cfg, **kw):
    return ctl.lint(cfg, **kw)


def test_skeleton_is_valid_statically(ctl):
    errs, warns = ctl.lint(ctl.SKELETON, skip_fs=True)
    assert errs == [] and warns


def test_skeleton_fails_fs_check_without_secrets(ctl):
    errs, _ = ctl.lint(ctl.SKELETON)
    assert any("does not exist" in e for e in errs)


def test_good_instance_passes(ctl, make_instance):
    assert ctl.lint(make_instance()) == ([], [])


@pytest.mark.parametrize("edit,frag", [
    ({"timezone: Etc/UTC": "timezone: Etc/UTC\nbogus: 1"}, "unknown key 'bogus'"),
    ({"  bind: 127.0.0.1": "  bind: 0.0.0.0"}, "network.bind"),
    ({"  bind: 127.0.0.1": "  bind: 192.0.2.5"}, "network.bind"),
    ({"  cpus: 1.5": "  cpus: 1.5\n  extra: 1"}, "unknown key 'extra'"),
    ({"environment: DEMO": "environment: PAPER"}, "environment"),
    ({"schema: mt5-instance/1": "schema: mt5-instance/2"}, "schema"),
    ({"image: mt5-gateway:CANDIDATE-unbuilt-from-main": "image: mt5-gateway:latest"}, "non-latest"),
    ({"image: mt5-gateway:CANDIDATE-unbuilt-from-main": "image: mt5-gateway"}, "$.image"),
    ({"broker_server: ExampleBroker-Demo": "broker_server: 203.0.113.9"}, "broker_server"),
    ({"memory_mb: 2048": "memory_mb: 10"}, "below minimum"),
    ({"memory_mb: 2048": "memory_mb: lots"}, "must be integer"),
    ({"data_volume: mt5-example-demo-a1-data": "data_volume: mt5-other-data"}, "<instance_name>-"),
    ({"account_class: demo-unfunded": "account_class: live-capital"}, "demo-*"),
    ({"servers_dat: /srv/example/_shared/servers.dat": "servers_dat: /srv/$(x)/s.dat"}, "servers_dat"),
])
def test_rejections(ctl, make_instance, edit, frag):
    errs, _ = ctl.lint(make_instance(edit=edit))
    assert errs and any(frag in e for e in errs), errs


def test_missing_required_key(ctl, make_instance):
    errs, _ = ctl.lint(make_instance(edit={"timezone: Etc/UTC\n": ""}))
    assert any("missing required key 'timezone'" in e for e in errs)


@pytest.mark.parametrize("port", ["22", "70000", "x"])
def test_bad_operator_ports(ctl, make_instance, port):
    errs, _ = ctl.lint(make_instance(ui=port))
    assert errs


def test_loopback_ui_port_ok(ctl, make_instance):
    assert ctl.lint(make_instance(ui=16901))[0] == []


@pytest.mark.parametrize("bad", [
    "a: [1, 2]", "a: {b: 1}", "a: &x 1", "a: *x", "a: |", "- item", "a: 1\na: 2", "\ta: 1", " a: 1", "a:\n    b: 1", "---",
])
def test_yaml_subset_rejects(ctl, bad):
    with pytest.raises(ctl.ParseError):
        ctl.parse_yaml(bad)


def test_yaml_subset_parses(ctl):
    d = ctl.parse_yaml("a: 1\nb:\n  c: 'x # y'  # comment\n  d: true\n  e: 1.5\n  f: none\n")
    assert d == {"a": 1, "b": {"c": "x # y", "d": True, "e": 1.5, "f": "none"}}


def test_mini_validator_agrees_with_jsonschema(ctl, make_instance):
    js = pytest.importorskip("jsonschema")
    schema = json.loads(ctl.SCHEMA_PATH.read_text())
    good = ctl.parse_yaml(make_instance().read_text())
    assert not ctl.validate_schema(good, schema)
    js.validate(good, schema)
    import copy
    for mut in (lambda d: d.update(x=1), lambda d: d["network"].update(bind="0.0.0.0"),
                lambda d: d["limits"].update(cpus=99), lambda d: d.pop("secrets"),
                lambda d: d["ports"].update(operator_ui=80)):
        bad = copy.deepcopy(good); mut(bad)
        with pytest.raises(js.ValidationError):
            js.validate(bad, schema)
        assert ctl.validate_schema(bad, schema)


def test_cli_exit_codes(ctl, make_instance, capsys):
    assert ctl.main(["lint", str(make_instance()), "--peers"]) == 0
    assert ctl.main(["lint", str(ctl.SKELETON), "--peers"]) == 1


def test_new_creates_demo_only(ctl, tmp_path):
    assert ctl.new(tmp_path / "x", "mt5-vantage-live-a1")
    assert ctl.new(tmp_path / "x", "mt5-vantage-demo-b2") == []
    assert ctl.new(tmp_path / "x", "mt5-vantage-demo-b2")  # exists, no --force
    errs, _ = ctl.lint(tmp_path / "x" / "instance.yaml", skip_fs=True)
    assert errs == []


def test_new_refuses_symlinked_instance_yaml_even_with_force(ctl, tmp_path):
    d = tmp_path / "x"; d.mkdir()
    victim = tmp_path / "victim.txt"; victim.write_text("keep")
    os.symlink(victim, d / "instance.yaml")
    assert any("symlink" in e for e in ctl.new(d, "mt5-vantage-demo-b2", force=True))
    assert victim.read_text() == "keep"
    # dangling symlink too
    (d / "instance.yaml").unlink(); os.symlink(tmp_path / "nope", d / "instance.yaml")
    assert any("symlink" in e for e in ctl.new(d, "mt5-vantage-demo-b2", force=True))
    assert not (tmp_path / "nope").exists()


@pytest.mark.parametrize("name", ["mt5-a-demo-b2", "mt5-" + "x" * 25 + "-demo-b2", "mt5-vantage-demo-" + "a" * 17])
def test_new_name_regex_matches_schema(ctl, tmp_path, name):
    assert ctl.new(tmp_path / "x", name)  # broker 2..24, id 1..16


def test_new_generated_file_for_longest_names_lints(ctl, tmp_path):
    name = "mt5-" + "x" * 24 + "-demo-" + "a" * 16
    assert ctl.new(tmp_path / "x", name) == []


@pytest.mark.parametrize("tag", ["mt5-gateway:LATEST", "mt5-gateway:Latest"])
def test_latest_rejected_case_insensitively(ctl, make_instance, tag):
    errs, _ = ctl.lint(make_instance(edit={"image: mt5-gateway:CANDIDATE-unbuilt-from-main": f"image: {tag}"}))
    assert any("non-latest" in e for e in errs), errs


def test_yaml_splits_on_lf_only(ctl):
    # U+2028 / form feed / vertical tab / U+0085 must not act as line breaks
    for sep in ("\x0b", "\x0c", "\x85", "\u2028", "\x1c"):
        d = ctl.parse_yaml(f"a: 1{sep}b: 2\n")
        assert list(d) == ["a"], (sep, d)  # one line, one key: the separator did not split it
    with pytest.raises(ctl.ParseError):
        ctl.parse_yaml("a: 1\r\nb: 2\r\n")
    assert ctl.parse_yaml("a: 1\nb: 2\n") == {"a": 1, "b": 2}


def test_skip_fs_warning_text_is_accurate(ctl):
    _, warns = ctl.lint(ctl.SKELETON, skip_fs=True)
    assert any("capital-gate marker check still runs" in w for w in warns)
