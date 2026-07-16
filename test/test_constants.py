import re

from oep_reference_core.constants import (
    OBJECT_ID_PATTERN,
    OBJECT_TYPES,
    RELATIONSHIP_ID_PATTERN,
    RELATIONSHIP_TYPES,
)


def test_object_id_pattern_accepts_dotted_snake_case():
    assert re.match(OBJECT_ID_PATTERN, "component.passive.resistor")
    assert re.match(OBJECT_ID_PATTERN, "unit.volt")


def test_object_id_pattern_rejects_spaces_and_uppercase():
    assert re.match(OBJECT_ID_PATTERN, "Not A Valid Id") is None
    assert re.match(OBJECT_ID_PATTERN, "UPPER.case") is None


def test_relationship_id_pattern_accepts_dotted_snake_case():
    assert re.match(RELATIONSHIP_ID_PATTERN, "component.passive.resistor.uses_equation.ohms_law")


def test_gold_standard_relationship_types_are_registered():
    assert "USES_EQUATION" in RELATIONSHIP_TYPES
    assert "USED_BY" in RELATIONSHIP_TYPES
    assert "HAS_UNIT" in RELATIONSHIP_TYPES
    assert "REPRESENTED_BY" in RELATIONSHIP_TYPES


def test_gold_standard_object_types_are_registered():
    assert {"Component", "Equation", "Unit", "Symbol", "Material"} <= OBJECT_TYPES
