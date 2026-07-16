import pytest

from oep_reference_core.yaml_io import YamlLoadError, load_optional_yaml_file, load_yaml_file


def test_load_yaml_file_parses_a_mapping(tmp_path):
    path = tmp_path / "object.yaml"
    path.write_text("identity:\n  object_id: a.b\n", encoding="utf-8")
    data = load_yaml_file(path)
    assert data == {"identity": {"object_id": "a.b"}}


def test_load_yaml_file_parses_a_sequence(tmp_path):
    path = tmp_path / "relationships.yaml"
    path.write_text("- relationship_id: a.b.c\n  type: USES\n", encoding="utf-8")
    data = load_yaml_file(path)
    assert data == [{"relationship_id": "a.b.c", "type": "USES"}]


def test_load_yaml_file_raises_for_missing_file(tmp_path):
    with pytest.raises(YamlLoadError, match="does not exist"):
        load_yaml_file(tmp_path / "missing.yaml")


def test_load_yaml_file_raises_for_malformed_yaml(tmp_path):
    path = tmp_path / "broken.yaml"
    path.write_text("identity: [unterminated\n", encoding="utf-8")
    with pytest.raises(YamlLoadError, match="invalid YAML"):
        load_yaml_file(path)


def test_load_optional_yaml_file_returns_none_for_missing_file(tmp_path):
    assert load_optional_yaml_file(tmp_path / "missing.yaml") is None


def test_load_optional_yaml_file_loads_an_existing_file(tmp_path):
    path = tmp_path / "education.yaml"
    path.write_text("examples: []\n", encoding="utf-8")
    assert load_optional_yaml_file(path) == {"examples": []}
