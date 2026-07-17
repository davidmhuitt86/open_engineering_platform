import sqlite3

from compiler.database import build_database


def test_build_database_creates_a_fresh_file(tmp_path, object_factory, package_factory):
    obj = object_factory("component.passive.a")
    package = package_factory([obj])
    db_path = tmp_path / "reference.db"

    build_database([package], db_path)

    assert db_path.is_file()


def test_build_database_inserts_object_row_with_expected_fields(tmp_path, object_factory, package_factory):
    obj = object_factory("component.passive.a")
    package = package_factory([obj])
    db_path = tmp_path / "reference.db"
    build_database([package], db_path)

    conn = sqlite3.connect(db_path)
    try:
        row = conn.execute(
            "SELECT object_id, package_id, object_type, lifecycle_state FROM objects"
        ).fetchone()
    finally:
        conn.close()
    assert row == ("component.passive.a", "test_package", "Component", "Published")


def test_build_database_inserts_properties_relationships_behaviors_validation_and_evidence(
    tmp_path, object_factory, package_factory
):
    rel = {
        "relationship_id": "component.passive.a.uses.b",
        "relationship_type": "USES",
        "target": "component.passive.b",
    }
    behavior = {
        "behavior_id": "component.passive.a.calc",
        "name": "Calc",
        "behavior_type": "Calculator",
        "description": "x",
        "inputs": [],
        "outputs": [],
    }
    rule = {"rule_id": "component.passive.a.positive", "subject": "resistance", "operator": "gt", "operand": 0, "severity": "error"}
    prop = {
        "property_id": "resistance",
        "display_name": "Resistance",
        "value_type": "number",
        "required": True,
        "read_only": False,
    }

    obj_a = object_factory(
        "component.passive.a",
        relationships=[rel],
        behaviors=[behavior],
        validation=[rule],
        properties=[prop],
    )
    obj_a.object["evidence"] = [
        {"evidence_type": "Calculation", "reference": "dimensional analysis"},
    ]
    obj_b = object_factory("component.passive.b", dir_name="b")
    package = package_factory([obj_a, obj_b])
    db_path = tmp_path / "reference.db"
    build_database([package], db_path)

    conn = sqlite3.connect(db_path)
    try:
        assert conn.execute("SELECT COUNT(*) FROM properties").fetchone()[0] == 1
        assert conn.execute("SELECT COUNT(*) FROM relationships").fetchone()[0] == 1
        assert conn.execute("SELECT COUNT(*) FROM behaviors").fetchone()[0] == 1
        assert conn.execute("SELECT COUNT(*) FROM validation_rules").fetchone()[0] == 1
        assert conn.execute("SELECT COUNT(*) FROM evidence").fetchone()[0] == 1
        target = conn.execute("SELECT target_object_id FROM relationships").fetchone()[0]
        assert target == "component.passive.b"
    finally:
        conn.close()


def test_build_database_overwrites_an_existing_file(tmp_path, object_factory, package_factory):
    db_path = tmp_path / "reference.db"
    db_path.write_bytes(b"not a real sqlite file")

    obj = object_factory("component.passive.a")
    package = package_factory([obj])
    build_database([package], db_path)

    conn = sqlite3.connect(db_path)
    try:
        count = conn.execute("SELECT COUNT(*) FROM objects").fetchone()[0]
    finally:
        conn.close()
    assert count == 1


def test_build_database_is_byte_deterministic_across_repeated_builds(tmp_path, object_factory, package_factory):
    obj = object_factory("component.passive.a")
    package = package_factory([obj])

    first_path = tmp_path / "first.db"
    second_path = tmp_path / "second.db"
    build_database([package], first_path)
    build_database([package], second_path)

    assert first_path.read_bytes() == second_path.read_bytes()
