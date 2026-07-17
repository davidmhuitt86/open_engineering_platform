from compiler.manifest import build_manifest


def test_build_manifest_maps_source_manifest_fields(object_factory, package_factory):
    package = package_factory([object_factory("unit.a")])
    manifest = build_manifest(package)

    assert manifest["package_name"] == "Test Package"
    assert manifest["package_id"] == "test_package"
    assert manifest["version"] == "0.1.0"
    assert manifest["publisher"] == "Tester"
    assert manifest["build_date"] == "2026-01-01"


def test_build_manifest_counts_objects_relationships_and_assets(object_factory, package_factory):
    rel = {"relationship_id": "unit.a.uses.b", "relationship_type": "USES", "target": "unit.b"}
    obj_a = object_factory("unit.a", relationships=[rel])
    obj_a.object["assets"] = [{"role": "icon", "path": "x.svg", "kind": "svg"}]
    obj_b = object_factory("unit.b", dir_name="b")

    package = package_factory([obj_a, obj_b])
    manifest = build_manifest(package)

    assert manifest["object_count"] == 2
    assert manifest["relationship_count"] == 1
    assert manifest["asset_count"] == 1


def test_build_manifest_never_calls_the_wall_clock(object_factory, package_factory, monkeypatch):
    """Guards ENGINE-TASK-000007 determinism: no datetime.now() anywhere in this path."""
    import datetime

    def _forbidden(*args, **kwargs):
        raise AssertionError("build_manifest must never read the wall clock")

    monkeypatch.setattr(datetime, "datetime", type("Blocked", (), {"now": staticmethod(_forbidden)}))

    package = package_factory([object_factory("unit.a")])
    manifest = build_manifest(package)
    assert manifest["build_date"] == "2026-01-01"


def test_build_manifest_defaults_dependencies_and_target_domains_to_empty(object_factory, package_factory):
    package = package_factory([object_factory("unit.a")])
    manifest = build_manifest(package)
    assert manifest["dependencies"] == []
    assert manifest["target_domains"] == []
