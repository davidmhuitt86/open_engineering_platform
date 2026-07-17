import pytest

from oep_reference_core.repo_paths import SCHEMAS_DIR

from compiler.build import CompilationError, compile_package


def test_compile_package_builds_core_reference_successfully(tmp_path):
    result = compile_package("core_reference", output_dir=tmp_path)
    assert result.output_path.name == "core_reference_v1.oerp"
    assert result.output_path.is_file()
    assert result.validation_report.passed is True
    assert len(result.sha256) == 64


def test_compile_package_is_deterministic_across_two_independent_builds(tmp_path):
    first = compile_package("core_reference", output_dir=tmp_path / "build1")
    second = compile_package("core_reference", output_dir=tmp_path / "build2")
    assert first.sha256 == second.sha256


def test_compile_package_raises_for_unknown_package_id(tmp_path):
    with pytest.raises(ValueError, match="no_such_package"):
        compile_package("no_such_package", output_dir=tmp_path)


def test_compile_package_refuses_to_build_when_validation_fails(tmp_path):
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
    (object_dir / "object.yaml").write_text(
        "identity:\n  object_id: unit.broken\n", encoding="utf-8"
    )  # missing every other required object.yaml section

    with pytest.raises(CompilationError) as excinfo:
        compile_package(
            "broken_package",
            packages_dir=packages_dir,
            schemas_dir=SCHEMAS_DIR,
            output_dir=tmp_path / "dist",
        )
    assert excinfo.value.report.passed is False
    assert not (tmp_path / "dist" / "broken_package_v0.oerp").exists()
