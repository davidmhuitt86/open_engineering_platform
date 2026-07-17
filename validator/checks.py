"""The seven checks ENGINE-TASK-000003 requires, plus schema validity,
extended for the SDD-R011 facet model (WORK_PACKAGE_002).

Each ``check_*`` function is pure: given the loaded package source(s),
it returns a list of :class:`~oep_reference_core.findings.Finding`
objects. Nothing here mutates the source tree or touches the network.
"""

from __future__ import annotations

from oep_reference_core.constants import OBJECT_TYPES, RELATIONSHIP_TYPES
from oep_reference_core.findings import Finding, Severity
from oep_reference_core.package_source import ObjectSource, PackageSource
from oep_reference_core.schema_registry import SchemaRegistry


def _location(package_id: str, object_source: ObjectSource, suffix: str = "") -> str:
    base = f"{package_id}/{object_source.object_dir.name}"
    return f"{base}{suffix}" if suffix else base


def check_schema_validity(packages: list[PackageSource], registry: SchemaRegistry) -> list[Finding]:
    """Validates every authoring file against its JSON Schema."""
    findings: list[Finding] = []

    for package in packages:
        manifest_location = f"{package.package_dir.name}/manifest.yaml"
        for error in registry.iter_errors(package.manifest, "package_manifest"):
            findings.append(
                Finding(Severity.ERROR, "schema_invalid", f"manifest.yaml: {error.message}", manifest_location)
            )

        package_id = package.package_id or package.package_dir.name
        for obj in package.objects:
            for error in registry.iter_errors(obj.object, "object"):
                findings.append(
                    Finding(
                        Severity.ERROR,
                        "schema_invalid",
                        f"object.yaml: {error.message}",
                        _location(package_id, obj),
                    )
                )
            section_schema = {
                "properties": obj.properties,
                "relationships": obj.relationships,
                "behaviors": obj.behaviors,
                "validation": obj.validation,
                "education": obj.education,
            }
            for section, instance in section_schema.items():
                if instance is None:
                    continue
                for error in registry.iter_errors(instance, section):
                    findings.append(
                        Finding(
                            Severity.ERROR,
                            "schema_invalid",
                            f"{section}.yaml: {error.message}",
                            _location(package_id, obj),
                        )
                    )
    return findings


def check_required_semantic_fields(packages: list[PackageSource]) -> list[Finding]:
    """Cross-field requirements the JSON Schema alone cannot express.

    SDD-R008 §13: "Every published object shall possess at least one
    engineering review." Structurally, ``provenance.reviewer`` is an
    optional field (a Draft object legitimately has none yet) -- but a
    Published object without one is a real content defect, not merely
    an unpopulated optional field.
    """
    findings: list[Finding] = []
    for package in packages:
        package_id = package.package_id or package.package_dir.name
        for obj in package.objects:
            identity = obj.object.get("identity") or {}
            provenance = obj.object.get("provenance") or {}
            if identity.get("lifecycle_state") == "Published" and not provenance.get("reviewer"):
                findings.append(
                    Finding(
                        Severity.ERROR,
                        "missing_required_field",
                        "identity.lifecycle_state is Published but provenance.reviewer is missing "
                        "-- SDD-R008 §13 requires at least one engineering review before "
                        "publication.",
                        _location(package_id, obj, "/object.yaml#provenance.reviewer"),
                    )
                )
            object_type = identity.get("object_type")
            if object_type and object_type not in OBJECT_TYPES:
                findings.append(
                    Finding(
                        Severity.WARNING,
                        "unknown_object_type",
                        f"object_type {object_type!r} is not in the SDD-R001 §4 initial list "
                        "(this is only a warning -- object types remain extensible).",
                        _location(package_id, obj, "/object.yaml#identity.object_type"),
                    )
                )
    return findings


def check_duplicate_ids(packages: list[PackageSource]) -> list[Finding]:
    """No two objects, relationships, behaviors, or rules may share an id (SDD-R010 §11).

    Property IDs (REFERENCE-TASK-000012) are checked for uniqueness
    *within* their own owning object only -- unlike Object/Relationship/
    Behavior ids, a property_id is never independently addressed
    platform-wide, only through its owning object, so the same
    property_id legitimately repeating across different objects (e.g.
    every component with a "resistance" property) is not a conflict.
    """
    findings: list[Finding] = []
    seen_object_ids: dict[str, str] = {}
    seen_relationship_ids: dict[str, str] = {}
    seen_behavior_ids: dict[str, str] = {}
    seen_rule_ids: dict[str, str] = {}

    for package in packages:
        package_id = package.package_id or package.package_dir.name
        for obj in package.objects:
            location = _location(package_id, obj)
            object_id = obj.object_id
            if object_id:
                if object_id in seen_object_ids:
                    findings.append(
                        Finding(
                            Severity.ERROR,
                            "duplicate_object_id",
                            f"object_id {object_id!r} is also defined at {seen_object_ids[object_id]!r}.",
                            location,
                        )
                    )
                else:
                    seen_object_ids[object_id] = location

            seen_property_ids: dict[str, int] = {}
            for index, prop in enumerate(obj.properties or []):
                property_id = prop.get("property_id")
                if not property_id:
                    continue
                if property_id in seen_property_ids:
                    findings.append(
                        Finding(
                            Severity.ERROR,
                            "duplicate_property_id",
                            f"property_id {property_id!r} appears more than once in this "
                            "object's properties.yaml.",
                            f"{location}/properties.yaml",
                        )
                    )
                else:
                    seen_property_ids[property_id] = index

            for relationship in obj.relationships or []:
                rel_id = relationship.get("relationship_id")
                if not rel_id:
                    continue
                if rel_id in seen_relationship_ids:
                    findings.append(
                        Finding(
                            Severity.ERROR,
                            "duplicate_relationship_id",
                            f"relationship_id {rel_id!r} is also defined at "
                            f"{seen_relationship_ids[rel_id]!r}.",
                            f"{location}/relationships.yaml",
                        )
                    )
                else:
                    seen_relationship_ids[rel_id] = f"{location}/relationships.yaml"

            for behavior in obj.behaviors or []:
                behavior_id = behavior.get("behavior_id")
                if not behavior_id:
                    continue
                if behavior_id in seen_behavior_ids:
                    findings.append(
                        Finding(
                            Severity.ERROR,
                            "duplicate_behavior_id",
                            f"behavior_id {behavior_id!r} is also defined at "
                            f"{seen_behavior_ids[behavior_id]!r}.",
                            f"{location}/behaviors.yaml",
                        )
                    )
                else:
                    seen_behavior_ids[behavior_id] = f"{location}/behaviors.yaml"

            for rule in obj.validation or []:
                rule_id = rule.get("rule_id")
                if not rule_id:
                    continue
                if rule_id in seen_rule_ids:
                    findings.append(
                        Finding(
                            Severity.ERROR,
                            "duplicate_rule_id",
                            f"rule_id {rule_id!r} is also defined at {seen_rule_ids[rule_id]!r}.",
                            f"{location}/validation.yaml",
                        )
                    )
                else:
                    seen_rule_ids[rule_id] = f"{location}/validation.yaml"

    return findings


def _known_object_ids(packages: list[PackageSource]) -> set[str]:
    return {obj.object_id for package in packages for obj in package.objects if obj.object_id}


def check_broken_references(packages: list[PackageSource]) -> list[Finding]:
    """Every cross-reference by Object ID must resolve within the known universe.

    SDD-R010 §10: "Objects reference other objects only by Object ID
    ... Compiler resolves references." This mirrors that resolution
    ahead of compilation so a broken reference is caught here, not as
    an obscure compiler failure.
    """
    findings: list[Finding] = []
    known_ids = _known_object_ids(packages)

    for package in packages:
        package_id = package.package_id or package.package_dir.name
        for obj in package.objects:
            location = _location(package_id, obj)

            for relationship in obj.relationships or []:
                target = relationship.get("target")
                if target and target not in known_ids:
                    findings.append(
                        Finding(
                            Severity.ERROR,
                            "broken_reference",
                            f"relationship {relationship.get('relationship_id')!r} targets "
                            f"{target!r}, which does not resolve to any known object_id.",
                            f"{location}/relationships.yaml",
                        )
                    )

            for behavior in obj.behaviors or []:
                for dependency in behavior.get("depends_on") or []:
                    if dependency not in known_ids:
                        findings.append(
                            Finding(
                                Severity.ERROR,
                                "broken_reference",
                                f"behavior {behavior.get('behavior_id')!r} depends_on "
                                f"{dependency!r}, which does not resolve to any known object_id.",
                                f"{location}/behaviors.yaml",
                            )
                        )

            for prop in obj.properties or []:
                unit_ref = prop.get("unit_ref")
                if unit_ref and unit_ref not in known_ids:
                    findings.append(
                        Finding(
                            Severity.ERROR,
                            "broken_reference",
                            f"property {prop.get('property_id')!r} declares unit_ref "
                            f"{unit_ref!r}, which does not resolve to any known object_id "
                            "(REFERENCE-TASK-000011: unit_ref must resolve to a compiled Unit "
                            "EKO -- use unit_symbol_pending instead if none exists yet).",
                            f"{location}/properties.yaml",
                        )
                    )

            authority = obj.object.get("authority") or {}
            authority_source = authority.get("authority_source_object")
            if authority_source and authority_source not in known_ids:
                findings.append(
                    Finding(
                        Severity.ERROR,
                        "broken_reference",
                        f"authority.authority_source_object {authority_source!r} does not "
                        "resolve to any known object_id.",
                        f"{location}/object.yaml",
                    )
                )

            for evidence_item in obj.object.get("evidence") or []:
                evidence_source = evidence_item.get("evidence_source_object")
                if evidence_source and evidence_source not in known_ids:
                    findings.append(
                        Finding(
                            Severity.ERROR,
                            "broken_reference",
                            f"evidence_source_object {evidence_source!r} does not resolve to "
                            "any known object_id.",
                            f"{location}/object.yaml",
                        )
                    )
    return findings


def check_pending_unit_exceptions(packages: list[PackageSource]) -> list[Finding]:
    """Surfaces every documented, temporary `unit_symbol_pending` exception.

    REFERENCE-TASK-000011: "Document any temporary exceptions that
    cannot yet be resolved without introducing additional Unit EKOs."
    This is deliberately an INFO finding, not a warning or error --
    using `unit_symbol_pending` is the *correct*, expected way to
    represent a unit with no compiled Unit EKO yet (see
    docs/SCHEMA_MIGRATION.md); it is not a defect to fix, only a fact
    worth surfacing in every validation report until a real Unit EKO
    resolves it.
    """
    findings: list[Finding] = []
    for package in packages:
        package_id = package.package_id or package.package_dir.name
        for obj in package.objects:
            location = f"{_location(package_id, obj)}/properties.yaml"
            for prop in obj.properties or []:
                pending = prop.get("unit_symbol_pending")
                if pending:
                    findings.append(
                        Finding(
                            Severity.INFO,
                            "pending_unit_reference",
                            f"property {prop.get('property_id')!r} uses the temporary unit "
                            f"symbol {pending!r} -- no compiled Unit EKO exists for it yet.",
                            location,
                        )
                    )
    return findings


def check_relationship_integrity(packages: list[PackageSource]) -> list[Finding]:
    """SDD-R003/SDD-R011 §8 relationship-shape checks beyond pure schema structure."""
    findings: list[Finding] = []
    for package in packages:
        package_id = package.package_id or package.package_dir.name
        for obj in package.objects:
            location = f"{_location(package_id, obj)}/relationships.yaml"
            for relationship in obj.relationships or []:
                rel_type = relationship.get("relationship_type")
                if rel_type and rel_type not in RELATIONSHIP_TYPES:
                    findings.append(
                        Finding(
                            Severity.WARNING,
                            "unknown_relationship_type",
                            f"relationship_type {rel_type!r} is not in the SDD-R003 §8 initial "
                            "list (this is only a warning -- relationship types remain "
                            "extensible).",
                            location,
                        )
                    )
                if relationship.get("target") == obj.object_id:
                    findings.append(
                        Finding(
                            Severity.WARNING,
                            "self_referential_relationship",
                            f"relationship {relationship.get('relationship_id')!r} targets its "
                            "own owning object.",
                            location,
                        )
                    )
    return findings


def check_behavior_references(packages: list[PackageSource]) -> list[Finding]:
    """SDD-R011 §9 behavior-shape checks beyond pure schema structure.

    behavior_type itself is a closed SDD-R011 §9 enum enforced by
    ``behaviors.schema.json`` -- unlike relationship_type/object_type,
    it needs no separate soft-extensibility check here.
    """
    findings: list[Finding] = []
    for package in packages:
        package_id = package.package_id or package.package_dir.name
        for obj in package.objects:
            location = f"{_location(package_id, obj)}/behaviors.yaml"
            for behavior in obj.behaviors or []:
                if not behavior.get("inputs") and not behavior.get("outputs"):
                    findings.append(
                        Finding(
                            Severity.WARNING,
                            "behavior_without_variables",
                            f"behavior {behavior.get('behavior_id')!r} declares neither inputs "
                            "nor outputs.",
                            location,
                        )
                    )
    return findings


def check_asset_references(packages: list[PackageSource]) -> list[Finding]:
    """Every referenced asset file must actually exist on disk (SDD-R010 §9, SDD-R011 §14).

    As of WORK_PACKAGE_002, asset file paths live in the top-level
    ``assets`` facet (object.yaml's ``assets`` list), not nested inside
    ``visualization`` -- see docs/SCHEMA_MIGRATION.md.
    """
    findings: list[Finding] = []
    for package in packages:
        package_id = package.package_id or package.package_dir.name
        for obj in package.objects:
            location = f"{_location(package_id, obj)}/object.yaml"
            for asset_entry in obj.object.get("assets") or []:
                relative_path = asset_entry.get("path")
                if not relative_path:
                    continue
                asset_path = obj.assets_dir / relative_path
                if not asset_path.is_file():
                    findings.append(
                        Finding(
                            Severity.ERROR,
                            "missing_asset",
                            f"assets facet references asset {relative_path!r} (role "
                            f"{asset_entry.get('role')!r}), which does not exist at "
                            f"{asset_path}.",
                            location,
                        )
                    )

            visualization = obj.object.get("visualization") or {}
            asset_roles = {entry.get("role") for entry in obj.object.get("assets") or []}
            for role in visualization.get("asset_roles") or []:
                if role not in asset_roles:
                    findings.append(
                        Finding(
                            Severity.ERROR,
                            "broken_reference",
                            f"visualization.asset_roles references role {role!r}, which is not "
                            "defined by any entry in this object's own assets facet.",
                            location,
                        )
                    )
    return findings


def run_all_checks(packages: list[PackageSource], registry: SchemaRegistry):
    """Runs every check and returns one merged, deterministic report."""
    from oep_reference_core.findings import ValidationReport

    findings: list[Finding] = []
    findings += check_schema_validity(packages, registry)
    findings += check_required_semantic_fields(packages)
    findings += check_duplicate_ids(packages)
    findings += check_broken_references(packages)
    findings += check_pending_unit_exceptions(packages)
    findings += check_relationship_integrity(packages)
    findings += check_behavior_references(packages)
    findings += check_asset_references(packages)
    return ValidationReport(findings=findings)
