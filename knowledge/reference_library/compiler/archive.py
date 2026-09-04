"""Writes a deterministic, byte-for-byte reproducible `.oerp` ZIP archive.

SDD-R004 §7: "An `.oerp` package shall be a deterministic ZIP archive
... The archive shall be byte-for-byte reproducible." Python's
``zipfile`` embeds each entry's filesystem modification time by
default, which breaks reproducibility across builds run at different
times -- a well-known hazard for "reproducible builds" tooling in any
language. This module fixes every non-content byte (timestamp,
permission bits, compression settings) to a constant so the only thing
that can change the resulting archive's hash is the *content* being
archived.
"""

from __future__ import annotations

import zipfile
from pathlib import Path

# The minimum date representable in a ZIP entry's DOS timestamp field --
# the conventional fixed value reproducible-build tooling uses instead
# of the real filesystem mtime.
_FIXED_DATE_TIME = (1980, 1, 1, 0, 0, 0)

# A fixed, regular-file Unix permission (0o644) shifted into the
# upper 16 bits of `external_attr`, matching how Python's zipfile
# itself encodes Unix permissions when running on a platform that sets
# them. Fixing this removes any dependency on the OS/umask of whichever
# machine happens to run the compiler.
_FIXED_EXTERNAL_ATTR = 0o644 << 16


def write_deterministic_zip(staging_dir: Path, output_path: Path) -> None:
    """Zips every file under ``staging_dir`` into ``output_path``, deterministically.

    Entries are added in sorted, platform-independent path order
    (forward slashes, regardless of OS) so the archive's central
    directory is identical across operating systems as well as across
    repeated runs on the same machine.
    """
    if output_path.exists():
        output_path.unlink()

    file_paths = sorted(
        (path for path in staging_dir.rglob("*") if path.is_file()),
        key=lambda path: path.relative_to(staging_dir).as_posix(),
    )

    with zipfile.ZipFile(output_path, mode="w") as archive:
        for file_path in file_paths:
            arcname = file_path.relative_to(staging_dir).as_posix()
            info = zipfile.ZipInfo(filename=arcname, date_time=_FIXED_DATE_TIME)
            info.external_attr = _FIXED_EXTERNAL_ATTR
            info.compress_type = zipfile.ZIP_DEFLATED
            data = file_path.read_bytes()
            archive.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
