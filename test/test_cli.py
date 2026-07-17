import json

from compiler.cli import main as compile_main
from validator.cli import main as validate_main


def test_validate_cli_exits_zero_and_prints_passing_report_for_real_packages(capsys):
    exit_code = validate_main([])
    captured = capsys.readouterr()
    report = json.loads(captured.out)
    assert exit_code == 0
    assert report["passed"] is True


def test_validate_cli_exits_nonzero_for_a_broken_packages_dir(tmp_path, capsys):
    packages_dir = tmp_path / "packages"
    broken_package = packages_dir / "broken_package"
    broken_package.mkdir(parents=True)
    (broken_package / "manifest.yaml").write_text(
        "package_id: broken_package\ndisplay_name: Broken\npublisher: t\n"
        'version: "0.1.0"\nrelease_date: "2026-01-01"\npackage_type: Core Library\nlicense: x\n',
        encoding="utf-8",
    )
    object_dir = broken_package / "unit.broken"
    object_dir.mkdir()
    (object_dir / "object.yaml").write_text("identity:\n  object_id: unit.broken\n", encoding="utf-8")

    exit_code = validate_main(["--packages-dir", str(packages_dir)])
    captured = capsys.readouterr()
    report = json.loads(captured.out)
    assert exit_code == 1
    assert report["passed"] is False
    assert report["summary"]["errors"] > 0


def test_compile_cli_prints_output_path_and_hash_on_success(tmp_path, capsys):
    exit_code = compile_main(["core_reference", "--output-dir", str(tmp_path)])
    captured = capsys.readouterr()
    assert exit_code == 0
    assert "core_reference_v1.oerp" in captured.out
    assert "SHA-256:" in captured.out


def test_compile_cli_prints_validation_report_and_exits_nonzero_on_failure(tmp_path, capsys):
    packages_dir = tmp_path / "packages"
    broken_package = packages_dir / "broken_package"
    broken_package.mkdir(parents=True)
    (broken_package / "manifest.yaml").write_text(
        "package_id: broken_package\ndisplay_name: Broken\npublisher: t\n"
        'version: "0.1.0"\nrelease_date: "2026-01-01"\npackage_type: Core Library\nlicense: x\n',
        encoding="utf-8",
    )
    object_dir = broken_package / "unit.broken"
    object_dir.mkdir()
    (object_dir / "object.yaml").write_text("identity:\n  object_id: unit.broken\n", encoding="utf-8")

    exit_code = compile_main(
        [
            "broken_package",
            "--packages-dir",
            str(packages_dir),
            "--output-dir",
            str(tmp_path / "dist"),
        ]
    )
    captured = capsys.readouterr()
    assert exit_code == 1
    assert "Validation failed" in captured.err
