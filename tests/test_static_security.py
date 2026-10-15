"""Static invariants over Dockerfile / compose / start.sh / bridge.

KNOWN-DEFERRED hazards are encoded as strict xfail with reasons: the suite is honest
(the hazard is reported, not hidden) and an XPASS (hazard fixed) FAILS the run, forcing
the allow-list entry to be removed. KNOWN_DEFERRED below is the explicit allow-list;
test_allow_list_is_exactly_the_xfails guards it from silently growing."""
import re, pytest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
R = lambda p: (REPO / p).read_text()
DOCKERFILE, STARTSH, BRIDGE = R("Dockerfile"), R("start.sh"), R("bridge/rpyc_server.py")
COMPOSE, UI = R("deploy/compose.instance.yml"), R("deploy/compose.operator-ui.yml")

KNOWN_DEFERRED = {
    "H1-nopasswd-sudo": "Dockerfile grants the runtime user NOPASSWD sudo (used by start.sh to read root:0400 secrets). Contract gap G6; production hardening deferred.",
    "H2-vnc-fail-open": "start.sh falls back to -disableBasicAuth (no VNC auth) when the vnc_password secret is absent. Deferred; mitigated by lint (secret required) + loopback-only publishing.",
    "H3-rpyc-unauthenticated": "bridge/rpyc_server.py serves classic RPyC SlaveService on 0.0.0.0 inside the container, unauthenticated (WO-MT5GW-0010 accepted risk). Never published; ADR-MT5-001 replaces it.",
}


def code_lines(text):
    return [l for l in text.splitlines() if not l.strip().startswith("#")]


# ---- invariants that must hold NOW
def test_compose_publishes_no_ports_by_default():
    assert not [l for l in code_lines(COMPOSE) if re.match(r"\s*ports:", l)]


def test_overlay_port_uses_variable_bind_only():
    ports = [l for l in code_lines(UI) if l.strip().startswith("- ")]
    assert ports == ['      - "${OPERATOR_UI_BIND:?}:${OPERATOR_UI_PORT:?}:6901"']


@pytest.mark.parametrize("text,name", [(COMPOSE, "compose"), (UI, "overlay")])
def test_no_wildcard_bind_or_host_network(text, name):
    body = "\n".join(code_lines(text))
    assert "0.0.0.0" not in body and "::]" not in body
    for bad in ("network_mode", "privileged", "cap_add", "pid: host", "/var/run/docker.sock"):
        assert bad not in body, bad


def test_no_secret_values_in_compose_or_env_templates():
    for text in (COMPOSE, UI, R("instances/_skeleton/instance.yaml")):
        for l in code_lines(text):
            assert not re.search(r"(?i)(password|passwd|secret|token|login)\s*[:=]\s*['\"]?[^\s$'\"{<]{4,}", l.split("#")[0]) or "file:" in l, l
    assert not re.search(r"(?m)^\s*environment:", "\n".join(code_lines(COMPOSE)))  # nothing inlined


def test_secrets_are_compose_file_secrets_outside_repo_var():
    for k in ("mt5_login", "mt5_password", "vnc_password"):
        assert re.search(rf"{k}:\n\s+file: \$\{{SECRETS_DIR:\?\}}/{k}", COMPOSE)


def test_dockerfile_has_no_secret_build_args_or_env():
    for l in code_lines(DOCKERFILE):
        assert not re.match(r"\s*(ARG|ENV)\s+\w*(PASS|SECRET|TOKEN|LOGIN)", l, re.I), l


def test_no_live_defaults_anywhere():
    for name, t in (("compose", COMPOSE), ("skeleton", R("instances/_skeleton/instance.yaml")), ("start.sh", STARTSH), ("Dockerfile", DOCKERFILE)):
        for l in code_lines(t):
            assert not re.search(r"(?i)\b(ENVIRONMENT|environment)\b\s*[:=]\s*['\"]?LIVE", l), (name, l)
    assert re.search(r"^environment: DEMO", R("instances/_skeleton/instance.yaml"), re.M)


def test_image_ref_is_parameter_and_rc6_not_relabelled():
    assert "image: ${IMAGE_REF:?}" in COMPOSE
    assert "rc6" not in "\n".join(code_lines(COMPOSE))
    sk = R("instances/_skeleton/instance.yaml")
    assert "CANDIDATE" in sk and "rc6" not in "\n".join(code_lines(sk))


def test_secret_files_are_gitignored():
    gi = R(".gitignore")
    assert "secrets" in gi


def test_allow_list_is_exactly_the_xfails():
    src = Path(__file__).read_text()
    marked = set(re.findall(r'xfail\(strict=True, reason="(H\d-[a-z-]+):', src))
    assert marked == set(KNOWN_DEFERRED), (marked, set(KNOWN_DEFERRED))


def test_known_hazards_are_still_exactly_as_recorded():
    assert len(re.findall(r"NOPASSWD", DOCKERFILE)) == 1
    assert len(re.findall(r"-disableBasicAuth", "\n".join(code_lines(STARTSH)))) == 1
    assert len(re.findall(r'hostname="0\.0\.0\.0"', BRIDGE)) == 1


# ---- KNOWN-DEFERRED (strict xfail; XPASS = hazard fixed -> remove the allow-list entry)
@pytest.mark.xfail(strict=True, reason="H1-nopasswd-sudo: " + KNOWN_DEFERRED["H1-nopasswd-sudo"])
def test_runtime_user_has_no_passwordless_sudo():
    assert "NOPASSWD" not in DOCKERFILE


@pytest.mark.xfail(strict=True, reason="H2-vnc-fail-open: " + KNOWN_DEFERRED["H2-vnc-fail-open"])
def test_vnc_never_fails_open():
    assert "-disableBasicAuth" not in "\n".join(code_lines(STARTSH))


@pytest.mark.xfail(strict=True, reason="H3-rpyc-unauthenticated: " + KNOWN_DEFERRED["H3-rpyc-unauthenticated"])
def test_bridge_not_wildcard_bound_or_unauthenticated():
    assert "0.0.0.0" not in BRIDGE and "SlaveService" not in BRIDGE
