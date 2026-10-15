import importlib.machinery, importlib.util, os, shutil, sys
from pathlib import Path
import pytest

REPO = Path(__file__).resolve().parent.parent


def _load():
    loader = importlib.machinery.SourceFileLoader("mt5ctl", str(REPO / "tools" / "mt5ctl"))
    spec = importlib.util.spec_from_loader("mt5ctl", loader)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["mt5ctl"] = mod
    loader.exec_module(mod)
    return mod


@pytest.fixture(scope="session")
def ctl():
    return _load()


@pytest.fixture
def make_instance(tmp_path, ctl):
    """Create an instance config dir + (optionally) a correct secrets dir, from the
    skeleton text only. Returns path to instance.yaml. Secrets are fake fixtures."""
    def _mk(name="mt5-example-demo-a1", ui="none", secrets=True, edit=None, sub=None):
        text = ctl.SKELETON.read_text()
        text = text.replace("mt5-example-demo-a1", name)
        base = tmp_path / "base"
        cfgdir = base / "cfg" / name
        sec = base / "secrets" / name
        text = text.replace(f"/srv/example/secrets/{name}", str(sec))
        text = text.replace("operator_ui: none", f"operator_ui: {ui}")
        for a, b in (edit or {}).items():
            assert a in text, a
            text = text.replace(a, b)
        cfgdir.mkdir(parents=True)
        cfg = cfgdir / "instance.yaml"
        cfg.write_text(text)
        if secrets:
            (base / "secrets").mkdir(exist_ok=True)
            sec.mkdir()
            os.chmod(sec, 0o700)
            for k in ctl.SECRET_KEYS:
                (sec / k).write_text("demo-fixture\n")
                os.chmod(sec / k, 0o600)
        return cfg
    return _mk
