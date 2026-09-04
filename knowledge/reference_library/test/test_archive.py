import os
import time
import zipfile

from compiler.archive import write_deterministic_zip


def _make_staging_dir(root, contents: dict[str, bytes]):
    for relative_path, data in contents.items():
        path = root / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    return root


def test_write_deterministic_zip_produces_identical_bytes_regardless_of_mtime(tmp_path):
    contents = {"manifest.json": b'{"a": 1}', "reference.db": b"binary-content", "assets/icon.svg": b"<svg/>"}

    staging_a = _make_staging_dir(tmp_path / "staging_a", contents)
    output_a = tmp_path / "a.oerp"
    write_deterministic_zip(staging_a, output_a)

    # Touch mtimes forward in time before building the second archive --
    # the resulting bytes must still match exactly.
    time.sleep(0.05)
    staging_b = _make_staging_dir(tmp_path / "staging_b", contents)
    for path in staging_b.rglob("*"):
        if path.is_file():
            os.utime(path, (time.time() + 10_000, time.time() + 10_000))
    output_b = tmp_path / "b.oerp"
    write_deterministic_zip(staging_b, output_b)

    assert output_a.read_bytes() == output_b.read_bytes()


def test_write_deterministic_zip_entries_use_fixed_dos_epoch(tmp_path):
    staging = _make_staging_dir(tmp_path / "staging", {"manifest.json": b"{}"})
    output = tmp_path / "out.oerp"
    write_deterministic_zip(staging, output)

    with zipfile.ZipFile(output) as archive:
        info = archive.getinfo("manifest.json")
        assert info.date_time == (1980, 1, 1, 0, 0, 0)


def test_write_deterministic_zip_orders_entries_by_posix_path(tmp_path):
    staging = _make_staging_dir(
        tmp_path / "staging",
        {"zeta.txt": b"z", "assets/alpha.svg": b"a", "manifest.json": b"m"},
    )
    output = tmp_path / "out.oerp"
    write_deterministic_zip(staging, output)

    with zipfile.ZipFile(output) as archive:
        names = archive.namelist()
    assert names == sorted(names)


def test_write_deterministic_zip_overwrites_existing_output(tmp_path):
    output = tmp_path / "out.oerp"
    output.write_bytes(b"stale content")
    staging = _make_staging_dir(tmp_path / "staging", {"manifest.json": b"{}"})

    write_deterministic_zip(staging, output)

    with zipfile.ZipFile(output) as archive:
        assert archive.namelist() == ["manifest.json"]


def test_write_deterministic_zip_roundtrips_file_content(tmp_path):
    staging = _make_staging_dir(tmp_path / "staging", {"reference.db": b"\x00\x01binary\xff"})
    output = tmp_path / "out.oerp"
    write_deterministic_zip(staging, output)

    with zipfile.ZipFile(output) as archive:
        assert archive.read("reference.db") == b"\x00\x01binary\xff"
