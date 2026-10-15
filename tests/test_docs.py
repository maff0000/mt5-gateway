"""Documentation hygiene (MT5GW-DOCS-001): relative links resolve, and no public doc carries an
IPv4 address other than loopback, bind-all or an RFC 5737 documentation range.

docs/evidence/ is excluded on purpose: those are preserved historical records.
"""
import ipaddress
import re
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DOCS = [REPO / "README.md"] + sorted(
    p for p in (REPO / "docs").rglob("*.md") if "evidence" not in p.relative_to(REPO / "docs").parts
)
LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
IPV4 = re.compile(r"(?<![\w.])((?:\d{1,3}\.){3}\d{1,3})(?![\w.]|~)")  # '10.0.0.0~bookworm' is a Wine version
ALLOWED_NETS = [ipaddress.ip_network(n) for n in ("192.0.2.0/24", "198.51.100.0/24", "203.0.113.0/24")]
ALLOWED_ADDRS = {"127.0.0.1", "0.0.0.0"}


def test_docs_exist():
    names = {p.name for p in DOCS}
    for n in ("README.md", "OPERATOR-GUIDE.md", "CONFIG-REFERENCE.md", "ARCHITECTURE.md", "TROUBLESHOOTING.md",
              "RECOVERY.md", "EVIDENCE-INDEX.md", "ERRATA.md", "KNOWN-LIMITATIONS.md"):
        assert n in names, n


def test_relative_links_resolve():
    bad = []
    for doc in DOCS:
        for target in LINK.findall(doc.read_text()):
            if re.match(r"^(https?:|mailto:|#)", target):
                continue
            path = target.split("#", 1)[0]
            if path and not (doc.parent / path).resolve().exists():
                bad.append(f"{doc.relative_to(REPO)} -> {target}")
    assert not bad, bad


def test_no_non_documentation_ipv4_in_docs():
    bad = []
    for doc in DOCS:
        for i, line in enumerate(doc.read_text().splitlines(), 1):
            for m in IPV4.finditer(line):
                s = m.group(1)
                try:
                    ip = ipaddress.ip_address(s)
                except ValueError:
                    continue  # not an address (e.g. a version string with an octet > 255)
                if s in ALLOWED_ADDRS or any(ip in n for n in ALLOWED_NETS):
                    continue
                bad.append(f"{doc.relative_to(REPO)}:{i}: {s}")
    assert not bad, bad
