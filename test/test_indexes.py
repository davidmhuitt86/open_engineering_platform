import json

from compiler.indexes import build_graph_index, build_search_index, write_json_index


def test_build_search_index_indexes_short_and_display_name(object_factory, package_factory):
    obj = object_factory("component.passive.resistor")
    obj.object["identity"]["short_name"] = "resistor"
    obj.object["identity"]["display_name"] = "Resistor"
    package = package_factory([obj])

    index = build_search_index([package])
    assert index["terms"]["resistor"] == ["component.passive.resistor"]


def test_build_search_index_indexes_classification_search_fields(object_factory, package_factory):
    obj = object_factory("component.passive.resistor")
    obj.object["classification"]["keywords"] = ["ohmic"]
    obj.object["classification"]["abbreviations"] = ["R"]
    package = package_factory([obj])

    index = build_search_index([package])
    assert "component.passive.resistor" in index["terms"]["ohmic"]
    assert "component.passive.resistor" in index["terms"]["r"]


def test_build_search_index_is_deterministic_regardless_of_object_order(object_factory, package_factory):
    obj_a = object_factory("unit.a", dir_name="a")
    obj_b = object_factory("unit.b", dir_name="b")

    index_forward = build_search_index([package_factory([obj_a, obj_b])])
    index_backward = build_search_index([package_factory([obj_b, obj_a])])
    assert index_forward == index_backward


def test_build_graph_index_lists_outgoing_edges_sorted(object_factory, package_factory):
    rel_b = {"relationship_id": "a.uses.b", "relationship_type": "USES", "target": "unit.b"}
    rel_a = {"relationship_id": "a.uses.a2", "relationship_type": "CONTAINS", "target": "unit.a2"}
    obj = object_factory("unit.a", relationships=[rel_b, rel_a])
    package = package_factory([obj])

    index = build_graph_index([package])
    edges = index["nodes"]["unit.a"]
    assert [e["relationship_type"] for e in edges] == ["CONTAINS", "USES"]


def test_build_graph_index_includes_every_object_even_with_no_relationships(object_factory, package_factory):
    obj = object_factory("unit.a")
    package = package_factory([obj])
    index = build_graph_index([package])
    assert index["nodes"]["unit.a"] == []


def test_write_json_index_produces_sorted_keys_and_trailing_newline(tmp_path):
    path = tmp_path / "index.json"
    write_json_index({"b": 1, "a": 2}, path)
    text = path.read_text(encoding="utf-8")
    assert text.endswith("\n")
    parsed = json.loads(text)
    assert parsed == {"a": 2, "b": 1}
    # Keys appear in sorted order in the raw text, not just after parsing.
    assert text.index('"a"') < text.index('"b"')
