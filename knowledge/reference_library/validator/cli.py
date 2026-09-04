"""``oep-validate`` -- validates every package under packages/.

Usage::

    oep-validate [--packages-dir PATH] [--schemas-dir PATH]

Exits 0 when validation passes (zero errors; warnings/infos do not
block), 1 otherwise. Always prints the deterministic JSON report to
stdout.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from oep_reference_core.package_source import discover_packages
from oep_reference_core.repo_paths import PACKAGES_DIR, SCHEMAS_DIR
from oep_reference_core.schema_registry import SchemaRegistry

from validator.checks import run_all_checks


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="oep-validate", description=__doc__)
    parser.add_argument("--packages-dir", type=Path, default=PACKAGES_DIR)
    parser.add_argument("--schemas-dir", type=Path, default=SCHEMAS_DIR)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_arg_parser().parse_args(argv)
    registry = SchemaRegistry(args.schemas_dir)
    packages = discover_packages(args.packages_dir)
    report = run_all_checks(packages, registry)
    sys.stdout.write(report.to_json())
    return 0 if report.passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
