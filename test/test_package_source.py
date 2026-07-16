from pathlib import Path

from oep_reference_core.package_source import discover_packages, load_object_source, load_package_source

_OBJECT_YAML = """
identity:
  object_id: unit.test_unit
  canonical_name: test_unit
  display_name: Test Unit
  object_type: Unit
  version: "1.0.0"
  status: Draft
classification:
  domain: Electrical
  category: Test
description:
  short_definition: x
  detailed_description: y
provenance:
  author: tester
  created_date: "2026-01-01"
  review_status: Draft
  confidence: low
  content_license: CC-BY-4.0
version:
  major: 1
  minor: 0
  patch: 0
"""


def _write_object_dir(root: Path, name: str, *, with_relationships: bool = False) -> Path:
    object_dir = root / name
    object_dir.mkdir(parents=True)
    (object_dir / "object.yaml").write_text(_OBJECT_YAML, encoding="utf-8")
    if with_relationships:
        (object_dir / "relationships.yaml").write_text("[]\n", encoding="utf-8")
    return object_dir


def test_load_object_source_reads_object_yaml_and_defaults_optional_sections_to_none(tmp_path):
    object_dir = _write_object_dir(tmp_path, "unit.test_unit")
    source = load_object_source(object_dir)
    assert source.object_id == "unit.test_unit"
    assert source.properties is None
    assert source.relationships is None
    assert source.behaviors is None
    assert source.validation is None
    assert source.education is None


def test_load_object_source_reads_present_optional_sections(tmp_path):
    object_dir = _write_object_dir(tmp_path, "unit.test_unit", with_relationships=True)
    source = load_object_source(object_dir)
    assert source.relationships == []


def test_load_package_source_discovers_every_object_directory(tmp_path):
    package_dir = tmp_path / "test_package"
    package_dir.mkdir()
    (package_dir / "manifest.yaml").write_text(
        "package_id: test_package\ndisplay_name: Test\npublisher: t\nversion: \"0.1.0\"\n"
        'release_date: "2026-01-01"\npackage_type: Core Library\nlicense: x\n',
        encoding="utf-8",
    )
    _write_object_dir(package_dir, "unit.a")
    _write_object_dir(package_dir, "unit.b")
    # A non-object directory (no object.yaml) must be ignored.
    (package_dir / "not_an_object").mkdir()

    package = load_package_source(package_dir)
    assert package.package_id == "test_package"
    assert [obj.object_dir.name for obj in package.objects] == ["unit.a", "unit.b"]


def test_load_package_source_orders_objects_by_directory_name(tmp_path):
    package_dir = tmp_path / "test_package"
    package_dir.mkdir()
    (package_dir / "manifest.yaml").write_text(
        "package_id: test_package\ndisplay_name: Test\npublisher: t\nversion: \"0.1.0\"\n"
        'release_date: "2026-01-01"\npackage_type: Core Library\nlicense: x\n',
        encoding="utf-8",
    )
    _write_object_dir(package_dir, "unit.zeta")
    _write_object_dir(package_dir, "unit.alpha")

    package = load_package_source(package_dir)
    assert [obj.object_dir.name for obj in package.objects] == ["unit.alpha", "unit.zeta"]


def test_discover_packages_ignores_directories_without_a_manifest(tmp_path):
    packages_root = tmp_path / "packages"
    packages_root.mkdir()
    real_package = packages_root / "real_package"
    real_package.mkdir()
    (real_package / "manifest.yaml").write_text(
        "package_id: real_package\ndisplay_name: Real\npublisher: t\nversion: \"0.1.0\"\n"
        'release_date: "2026-01-01"\npackage_type: Core Library\nlicense: x\n',
        encoding="utf-8",
    )
    (packages_root / "not_a_package").mkdir()

    packages = discover_packages(packages_root)
    assert [p.package_dir.name for p in packages] == ["real_package"]


def test_assets_dir_property_points_under_object_directory(tmp_path):
    object_dir = _write_object_dir(tmp_path, "unit.test_unit")
    source = load_object_source(object_dir)
    assert source.assets_dir == object_dir / "assets"
