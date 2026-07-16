"""Builds the precompiled `search.idx` and `graph.idx` (SDD-R004 §10/§11).

Both are deterministic JSON documents. WORK_PACKAGE_001 does not
implement a Discovery/Search runtime (explicitly out of scope) -- these
are the precompiled *data* a future runtime will load, per SDD-R004
§10: "The runtime shall never build indexes during installation."
"""

from __future__ import annotations

import json
import re
from pathlib import Path

from oep_reference_core.package_source import PackageSource

_WORD_PATTERN = re.compile(r"[a-z0-9]+")


def _terms(*texts: str | None) -> set[str]:
    terms: set[str] = set()
    for text in texts:
        if not text:
            continue
        terms.update(_WORD_PATTERN.findall(text.lower()))
    return terms


def build_search_index(packages: list[PackageSource]) -> dict:
    """A term -> sorted object id list inverted index.

    Indexes: canonical/display name, classification tags/keywords/
    aliases, and search_metadata keywords/aliases/abbreviations/
    alternate_names/manufacturer_terms/standards_references
    (SDD-R004 §10 field list).
    """
    postings: dict[str, set[str]] = {}

    for package in packages:
        for obj in package.objects:
            object_id = obj.object_id
            if not object_id:
                continue
            identity = obj.object.get("identity") or {}
            classification = obj.object.get("classification") or {}
            search_metadata = obj.object.get("search_metadata") or {}

            terms = _terms(identity.get("canonical_name"), identity.get("display_name"))
            for field in ("tags", "keywords", "aliases"):
                for value in classification.get(field) or []:
                    terms |= _terms(value)
            for field in (
                "keywords",
                "aliases",
                "abbreviations",
                "alternate_names",
                "manufacturer_terms",
                "standards_references",
            ):
                for value in search_metadata.get(field) or []:
                    terms |= _terms(value)

            for term in terms:
                postings.setdefault(term, set()).add(object_id)

    return {
        "version": 1,
        "terms": {term: sorted(object_ids) for term, object_ids in sorted(postings.items())},
    }


def build_graph_index(packages: list[PackageSource]) -> dict:
    """An adjacency list: object id -> sorted list of outgoing relationship edges."""
    adjacency: dict[str, list[dict]] = {}

    for package in packages:
        for obj in package.objects:
            object_id = obj.object_id
            if not object_id:
                continue
            edges = []
            for relationship in obj.relationships or []:
                edges.append(
                    {
                        "relationship_id": relationship["relationship_id"],
                        "type": relationship["type"],
                        "target": relationship["target"],
                    }
                )
            edges.sort(key=lambda e: (e["type"], e["target"], e["relationship_id"]))
            adjacency[object_id] = edges

    return {"version": 1, "nodes": {object_id: adjacency[object_id] for object_id in sorted(adjacency)}}


def write_json_index(data: dict, path: Path) -> None:
    """Writes ``data`` as canonical, deterministic JSON (sorted keys, fixed separators)."""
    path.write_text(json.dumps(data, sort_keys=True, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
