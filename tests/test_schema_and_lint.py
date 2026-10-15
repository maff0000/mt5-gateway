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
