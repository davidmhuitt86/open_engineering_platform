"""``oep-compile`` -- validates then compiles one package into a `.oerp` file.

Usage::

    oep-compile <package_id> [--packages-dir PATH] [--schemas-dir PATH] [--output-dir PATH]

Exits 1 and prints the validation report if validation fails. Compiler
only -- no runtime loading (ENGINE-TASK-000004).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from oep_reference_core.repo_paths import DIST_DIR, PACKAGES_DIR, SCHEMAS_DIR

from compiler.build import CompilationError, compile_package


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="oep-compile", description=__doc__)
    parser.add_argument("package_id", help='e.g. "core_reference"')
    parser.add_argument("--packages-dir", type=Path, default=PACKAGES_DIR)
    parser.add_argument("--schemas-dir", type=Path, default=SCHEMAS_DIR)
    parser.add_argument("--output-dir", type=Path, default=DIST_DIR)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_arg_parser().parse_args(argv)
    try:
        result = compile_package(
            args.package_id,
            packages_dir=args.packages_dir,
            schemas_dir=args.schemas_dir,
            output_dir=args.output_dir,
        )
    except CompilationError as exc:
        sys.stderr.write("Validation failed -- compilation aborted.\n")
        sys.stderr.write(exc.report.to_json())
        return 1

    sys.stdout.write(f"Compiled {result.output_path}\n")
    sys.stdout.write(f"SHA-256: {result.sha256}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
