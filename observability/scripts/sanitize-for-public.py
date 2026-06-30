#!/usr/bin/env python3
"""Replace org-specific hostnames, IPs, and identities with PLACEHOLDERS.md tokens."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SKIP_DIRS = {".git", "charts"}  # do not rewrite vendored .tgz tree names under charts/*.tgz
TEXT_SUFFIXES = {
    ".yaml", ".yml", ".json", ".md", ".ini", ".j2", ".sh", ".tpl", ".example",
    "",  # README without extension
}

# Order matters: more specific hostnames first
HOST_REPLACEMENTS = [
    (re.compile(r"grafana\.observability\.eodc\.eu", re.I), "grafana.yourdomain.tld"),
    (re.compile(r"otel\.observability\.eodc\.eu", re.I), "otel.yourdomain.tld"),
    (re.compile(r"grafana\.infra\.eodc\.eu", re.I), "grafana.yourdomain.tld"),
    (re.compile(r"otel\.infra\.eodc\.eu", re.I), "otel.yourdomain.tld"),
    (re.compile(r"argocd\.infra\.eodc\.eu", re.I), "argocd.yourdomain.tld"),
    (re.compile(r"vault\.infra\.eodc\.eu", re.I), "vault.yourdomain.tld"),
    (re.compile(r"argocd\.assembly\.eodc\.eu", re.I), "argocd.assembly.yourdomain.tld"),
    (re.compile(r"vault\.assembly\.eodc\.eu", re.I), "vault.assembly.yourdomain.tld"),
    (re.compile(r"argocd\.observability\.eodc\.eu", re.I), "argocd.yourdomain.tld"),
    (re.compile(r"objectstore\.eodc\.eu", re.I), "objectstore.yourdomain.tld"),
    (re.compile(r"\.eodc\.eu\b", re.I), ".yourdomain.tld"),
]

OTHER_REPLACEMENTS = [
    (re.compile(r"@eodcgmbh/", re.I), "@YOUR_GITHUB_ORG/"),
    (re.compile(r"\beodcgmbh\b", re.I), "YOUR_GITHUB_ORG"),
    (re.compile(r"customer=eodc\b", re.I), "customer=YOUR_ORG"),
    (re.compile(r"customer:\s*eodc\b", re.I), "customer: YOUR_ORG"),
    (re.compile(r"\bEODC\b"), "YOUR_ORG"),  # org display name in Grafana mapping comments
    # SNMP / internal targets (RFC 5737 documentation range)
    (re.compile(r"\b10\.250\.2\.180\b"), "192.0.2.10"),
    (re.compile(r"\b10\.250\.2\.181\b"), "192.0.2.11"),
    (re.compile(r"\b10\.250\.2\.182\b"), "192.0.2.12"),
    (re.compile(r"\b10\.250\.2\.183\b"), "192.0.2.13"),
    (re.compile(r"\b10\.250\.2\.65\b"), "AGENT_SERVER_IP_01"),
    (re.compile(r"\b10\.11\.110\.(230|196|95)\b"), r"YOUR_K8S_NODE_IP_\1"),
    (re.compile(r"\b10\.10\.33\.206\b"), "YOUR_K8S_NODE_IP"),
    (re.compile(r"\b10\.152\.183\.0/24\b"), "YOUR_CLUSTER_SERVICE_CIDR"),
    (re.compile(r"med-1repl-retain"), "YOUR_STORAGE_CLASS"),
    (re.compile(r"vmmetrics-observability-backups"), "YOUR_VM_BACKUP_BUCKET"),
    (re.compile(r"victoria-cluster-backups"), "YOUR_VM_CLUSTER_BACKUP_BUCKET"),
    (re.compile(r"10\.250\.2\.18\[0-3\]"), "192.0.2.1[0-3]"),
    (re.compile(r"10\.250\.2\.\(180\|181\|182\|183\)"), "192.0.2.(10|11|12|13)"),
    (re.compile(r"\b10\.250\.2\.\d+\b"), "YOUR_OTEL_MASTER_IP"),
    (re.compile(r"\beodc_prod_gateway\b"), "YOUR_SSH_JUMP_HOST"),
    (re.compile(r"\beodc_dev_gateway\b"), "YOUR_SSH_JUMP_HOST_DEV"),
    (re.compile(r"\bUser eodc\b"), "User SSH_USER"),
    (re.compile(r"`eodc/"), "`YOUR_ORG/"),
    (re.compile(r"/eodc/"), "/YOUR_ORG/"),
    (re.compile(r"customer=\"eodc\""), 'customer="YOUR_ORG"'),
    (re.compile(r"s3://eodc-observability-backups"), "s3://YOUR_OBSERVABILITY_BACKUP_BUCKET"),
    (re.compile(r"default\('eodc'\)"), "default('YOUR_ORG')"),
    (re.compile(r"glft-[A-Za-z0-9]+"), "glft-REDACTED"),


def should_process(path: Path) -> bool:
    if path.suffix == ".tgz":
        return False
    if any(part in SKIP_DIRS and part != "charts" for part in path.parts):
        pass
    if path.suffix in TEXT_SUFFIXES or path.name == "README":
        return True
    return False


def sanitize_text(text: str) -> str:
    for pat, repl in HOST_REPLACEMENTS:
        text = pat.sub(repl, text)
    for pat, repl in OTHER_REPLACEMENTS:
        text = pat.sub(repl, text)
    return text


def main() -> int:
    target = ROOT
    if len(sys.argv) > 1:
        target = Path(sys.argv[1])
    changed = 0
    for path in target.rglob("*"):
        if not path.is_file() or not should_process(path):
            continue
        if path.match("**/charts/*.tgz"):
            continue
        try:
            original = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        updated = sanitize_text(original)
        if updated != original:
            path.write_text(updated, encoding="utf-8")
            changed += 1
    print(f"Sanitized {changed} files under {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
