"""Builds the compiled `reference.db` (SQLite) deterministically.

SDD-R004 §9: "The package contains a compiled runtime database ...
The schema remains internal to the compiler/runtime" -- this module's
table shapes are an implementation detail, not part of any public
contract.

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
    package_id TEXT NOT NULL,
    canonical_name TEXT NOT NULL,
    display_name TEXT NOT NULL,
    object_type TEXT NOT NULL,
    version TEXT NOT NULL,
    status TEXT NOT NULL,
    domain TEXT NOT NULL,
    discipline TEXT,
    family TEXT,
    category TEXT NOT NULL,
    subcategory TEXT,
    authority TEXT,
    visibility TEXT,
    ownership TEXT,
    short_definition TEXT NOT NULL,
    detailed_description TEXT NOT NULL,
    provenance_author TEXT NOT NULL,
    provenance_reviewer TEXT,
    provenance_review_status TEXT NOT NULL,
    provenance_confidence TEXT NOT NULL,
    document_json TEXT NOT NULL
);

CREATE TABLE properties (
    object_id TEXT NOT NULL REFERENCES objects(object_id),
    position INTEGER NOT NULL,
    name TEXT NOT NULL,
    display_name TEXT,
    value_type TEXT NOT NULL,
    units TEXT,
    required INTEGER NOT NULL,
    read_only INTEGER NOT NULL,
    document_json TEXT NOT NULL,
    PRIMARY KEY (object_id, name)
);

CREATE TABLE relationships (
    relationship_id TEXT PRIMARY KEY,
    source_object_id TEXT NOT NULL REFERENCES objects(object_id),
    target_object_id TEXT NOT NULL,
    type TEXT NOT NULL,
    category TEXT,
    document_json TEXT NOT NULL
);

CREATE TABLE behaviors (
    behavior_id TEXT PRIMARY KEY,
    object_id TEXT NOT NULL REFERENCES objects(object_id),
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    document_json TEXT NOT NULL
);

CREATE TABLE validation_rules (
    rule_id TEXT PRIMARY KEY,
    object_id TEXT NOT NULL REFERENCES objects(object_id),
    severity TEXT NOT NULL,
    document_json TEXT NOT NULL
);

CREATE INDEX idx_relationships_source ON relationships(source_object_id);
CREATE INDEX idx_relationships_target ON relationships(target_object_id);
CREATE INDEX idx_properties_object ON properties(object_id);
CREATE INDEX idx_behaviors_object ON behaviors(object_id);
CREATE INDEX idx_validation_rules_object ON validation_rules(object_id);
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
                description = obj.object["description"]
                provenance = obj.object["provenance"]

                connection.execute(
                    """
                    INSERT INTO objects (
                        object_id, package_id, canonical_name, display_name, object_type,
                        version, status, domain, discipline, family, category, subcategory,
                        authority, visibility, ownership, short_definition,
                        detailed_description, provenance_author, provenance_reviewer,
                        provenance_review_status, provenance_confidence, document_json
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        identity["object_id"],
                        package_id,
                        identity["canonical_name"],
                        identity["display_name"],
                        identity["object_type"],
                        identity["version"],
                        identity["status"],
                        classification["domain"],
                        classification.get("discipline"),
                        classification.get("family"),
                        classification["category"],
                        classification.get("subcategory"),
                        classification.get("authority"),
                        classification.get("visibility"),
                        classification.get("ownership"),
                        description["short_definition"],
                        description["detailed_description"],
                        provenance["author"],
                        provenance.get("reviewer"),
                        provenance["review_status"],
                        provenance["confidence"],
                        _canonical_json(_composite_document(package_id, obj)),
                    ),
                )

                for position, prop in enumerate(sorted(obj.properties or [], key=lambda p: p["name"])):
                    connection.execute(
                        """
                        INSERT INTO properties (
                            object_id, position, name, display_name, value_type, units,
                            required, read_only, document_json
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        (
                            identity["object_id"],
                            position,
                            prop["name"],
                            prop.get("display_name"),
                            prop["value_type"],
                            prop.get("units"),
                            int(bool(prop["required"])),
                            int(bool(prop["read_only"])),
                            _canonical_json(prop),
                        ),
                    )

                for relationship in sorted(obj.relationships or [], key=lambda r: r["relationship_id"]):
                    connection.execute(
                        """
                        INSERT INTO relationships (
                            relationship_id, source_object_id, target_object_id, type,
                            category, document_json
                        ) VALUES (?, ?, ?, ?, ?, ?)
                        """,
                        (
                            relationship["relationship_id"],
                            identity["object_id"],
                            relationship["target"],
                            relationship["type"],
                            relationship.get("category"),
                            _canonical_json(relationship),
                        ),
                    )

                for behavior in sorted(obj.behaviors or [], key=lambda b: b["behavior_id"]):
                    connection.execute(
                        """
                        INSERT INTO behaviors (behavior_id, object_id, name, type, document_json)
                        VALUES (?, ?, ?, ?, ?)
                        """,
                        (
                            behavior["behavior_id"],
                            identity["object_id"],
                            behavior["name"],
                            behavior["type"],
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

        connection.commit()
    finally:
        connection.close()
