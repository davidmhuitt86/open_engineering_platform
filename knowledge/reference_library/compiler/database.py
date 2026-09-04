"""Builds the compiled `reference.db` (SQLite) deterministically.

SDD-R004 §9: "The package contains a compiled runtime database ...
The schema remains internal to the compiler/runtime" -- this module's
table shapes are an implementation detail, not part of any public
contract.

As of WORK_PACKAGE_002, tables mirror the SDD-R011 facet model:
`objects` carries Identity/Classification/Authority/Provenance
columns, with dedicated tables for the array-heavy facets (Properties,
Relationships, Behaviors, Validation, Evidence).

Determinism is the load-bearing requirement here (SDD-R004 §7: "The
archive shall be byte-for-byte reproducible"; ENGINE-TASK-000007:
"Running the compiler twice shall produce identical package hashes").
SQLite's on-disk format is itself fully deterministic *given* an
identical sequence of operations against a freshly created file with
fixed pragmas -- so this module always: creates a brand new file,
fixes `page_size` before any table is created, never uses
`AUTOINCREMENT` (which would consume the internal `sqlite_sequence`
table and introduce state dependent on insert history), inserts every
row in a stable sorted order, and commits exactly once before closing.
"""

from __future__ import annotations

import json
import sqlite3
from pathlib import Path

from oep_reference_core.package_source import ObjectSource, PackageSource

_SCHEMA = """
CREATE TABLE objects (
    object_id TEXT PRIMARY KEY,
    uuid TEXT NOT NULL,
    package_id TEXT NOT NULL,
    short_name TEXT NOT NULL,
    display_name TEXT NOT NULL,
    object_type TEXT NOT NULL,
    version TEXT NOT NULL,
    lifecycle_state TEXT NOT NULL,
    domain TEXT NOT NULL,
    discipline TEXT,
    family TEXT,
    category TEXT NOT NULL,
    subcategory TEXT,
    authority_type TEXT NOT NULL,
    authority_reference TEXT NOT NULL,
    short_definition TEXT NOT NULL,
    detailed_description TEXT NOT NULL,
    provenance_author TEXT NOT NULL,
    provenance_reviewer TEXT,
    provenance_organization TEXT NOT NULL,
    provenance_confidence TEXT NOT NULL,
    document_json TEXT NOT NULL
);

CREATE TABLE properties (
    object_id TEXT NOT NULL REFERENCES objects(object_id),
    position INTEGER NOT NULL,
    property_id TEXT NOT NULL,
    display_name TEXT,
    value_type TEXT NOT NULL,
    unit_ref TEXT,
    unit_symbol_pending TEXT,
    required INTEGER NOT NULL,
    read_only INTEGER NOT NULL,
    document_json TEXT NOT NULL,
    PRIMARY KEY (object_id, property_id)
);

CREATE TABLE relationships (
    relationship_id TEXT PRIMARY KEY,
    source_object_id TEXT NOT NULL REFERENCES objects(object_id),
    target_object_id TEXT NOT NULL,
    relationship_type TEXT NOT NULL,
    document_json TEXT NOT NULL
);

CREATE TABLE behaviors (
    behavior_id TEXT PRIMARY KEY,
    object_id TEXT NOT NULL REFERENCES objects(object_id),
    name TEXT NOT NULL,
    behavior_type TEXT NOT NULL,
    document_json TEXT NOT NULL
);

CREATE TABLE validation_rules (
    rule_id TEXT PRIMARY KEY,
    object_id TEXT NOT NULL REFERENCES objects(object_id),
    severity TEXT NOT NULL,
    document_json TEXT NOT NULL
);

CREATE TABLE evidence (
    object_id TEXT NOT NULL REFERENCES objects(object_id),
    position INTEGER NOT NULL,
    evidence_type TEXT NOT NULL,
    reference TEXT NOT NULL,
    document_json TEXT NOT NULL,
    PRIMARY KEY (object_id, position)
);

CREATE INDEX idx_relationships_source ON relationships(source_object_id);
CREATE INDEX idx_relationships_target ON relationships(target_object_id);
CREATE INDEX idx_properties_object ON properties(object_id);
CREATE INDEX idx_behaviors_object ON behaviors(object_id);
CREATE INDEX idx_validation_rules_object ON validation_rules(object_id);
CREATE INDEX idx_evidence_object ON evidence(object_id);
"""


def _canonical_json(value: object) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def _composite_document(package_id: str, obj: ObjectSource) -> dict:
    return {
        "package_id": package_id,
        "object": obj.object,
        "properties": obj.properties or [],
        "relationships": obj.relationships or [],
        "behaviors": obj.behaviors or [],
        "validation": obj.validation or [],
        "education": obj.education or {},
    }


def build_database(packages: list[PackageSource], db_path: Path) -> None:
    """Creates ``db_path`` fresh and populates it from ``packages``.

    ``packages`` and each package's ``objects`` must already be in a
    stable, deterministic order -- :func:`oep_reference_core.package_source.discover_packages`
    and :func:`~oep_reference_core.package_source.load_package_source`
    both sort by directory name, so callers get this for free.
    """
    if db_path.exists():
        db_path.unlink()

    connection = sqlite3.connect(db_path)
    try:
        connection.execute("PRAGMA page_size = 4096")
        connection.execute("PRAGMA journal_mode = DELETE")
        connection.executescript(_SCHEMA)

        for package in packages:
            package_id = package.package_id or package.package_dir.name
            for obj in sorted(package.objects, key=lambda o: o.object_id or ""):
                identity = obj.object["identity"]
                classification = obj.object["classification"]
                authority = obj.object["authority"]
                education = obj.education or {}
                provenance = obj.object["provenance"]

                connection.execute(
                    """
                    INSERT INTO objects (
                        object_id, uuid, package_id, short_name, display_name, object_type,
                        version, lifecycle_state, domain, discipline, family, category,
                        subcategory, authority_type, authority_reference, short_definition,
                        detailed_description, provenance_author, provenance_reviewer,
                        provenance_organization, provenance_confidence, document_json
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        identity["object_id"],
                        identity["uuid"],
                        package_id,
                        identity["short_name"],
                        identity["display_name"],
                        identity["object_type"],
                        identity["version"],
                        identity["lifecycle_state"],
                        classification["domain"],
                        classification.get("discipline"),
                        classification.get("family"),
                        classification["category"],
                        classification.get("subcategory"),
                        authority["authority_type"],
                        authority["authority_reference"],
                        education.get("short_definition", ""),
                        education.get("detailed_description", ""),
                        provenance["author"],
                        provenance.get("reviewer"),
                        provenance["organization"],
                        provenance["confidence"],
                        _canonical_json(_composite_document(package_id, obj)),
                    ),
                )

                for position, prop in enumerate(sorted(obj.properties or [], key=lambda p: p["property_id"])):
                    connection.execute(
                        """
                        INSERT INTO properties (
                            object_id, position, property_id, display_name, value_type,
                            unit_ref, unit_symbol_pending, required, read_only, document_json
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        (
                            identity["object_id"],
                            position,
                            prop["property_id"],
                            prop.get("display_name"),
                            prop["value_type"],
                            prop.get("unit_ref"),
                            prop.get("unit_symbol_pending"),
                            int(bool(prop["required"])),
                            int(bool(prop["read_only"])),
                            _canonical_json(prop),
                        ),
                    )

                for relationship in sorted(obj.relationships or [], key=lambda r: r["relationship_id"]):
                    connection.execute(
                        """
                        INSERT INTO relationships (
                            relationship_id, source_object_id, target_object_id,
                            relationship_type, document_json
                        ) VALUES (?, ?, ?, ?, ?)
                        """,
                        (
                            relationship["relationship_id"],
                            identity["object_id"],
                            relationship["target"],
                            relationship["relationship_type"],
                            _canonical_json(relationship),
                        ),
                    )

                for behavior in sorted(obj.behaviors or [], key=lambda b: b["behavior_id"]):
                    connection.execute(
                        """
                        INSERT INTO behaviors (behavior_id, object_id, name, behavior_type, document_json)
                        VALUES (?, ?, ?, ?, ?)
                        """,
                        (
                            behavior["behavior_id"],
                            identity["object_id"],
                            behavior["name"],
                            behavior["behavior_type"],
                            _canonical_json(behavior),
                        ),
                    )

                for rule in sorted(obj.validation or [], key=lambda r: r["rule_id"]):
                    connection.execute(
                        """
                        INSERT INTO validation_rules (rule_id, object_id, severity, document_json)
                        VALUES (?, ?, ?, ?)
                        """,
                        (
                            rule["rule_id"],
                            identity["object_id"],
                            rule["severity"],
                            _canonical_json(rule),
                        ),
                    )

                evidence_items = obj.object.get("evidence") or []
                for position, evidence_item in enumerate(
                    sorted(evidence_items, key=lambda e: (e["evidence_type"], e["reference"]))
                ):
                    connection.execute(
                        """
                        INSERT INTO evidence (object_id, position, evidence_type, reference, document_json)
                        VALUES (?, ?, ?, ?, ?)
                        """,
                        (
                            identity["object_id"],
                            position,
                            evidence_item["evidence_type"],
                            evidence_item["reference"],
                            _canonical_json(evidence_item),
                        ),
                    )

        connection.commit()
    finally:
        connection.close()
