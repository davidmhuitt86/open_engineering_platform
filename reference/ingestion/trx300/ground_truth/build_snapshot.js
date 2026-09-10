// Build script (not part of the dataset itself) — AP-KIE-REFERENCE-001
// Phase 11. Merges object_inventory.json + relationship_inventory.json
// (both already derived from diagram7.json by build_inventory.js) into
// one flat, comparison-ready snapshot: the single file a future ingestion
// benchmark's comparator would diff a candidate graph against. Adds
// nothing new electrically -- purely a re-shaping/indexing pass over data
// that already exists in the two inventory files, so it never touches
// diagram7.json itself and never duplicates the live solver's own logic.
'use strict';
const fs = require('fs');

const objInv = JSON.parse(fs.readFileSync('object_inventory.json', 'utf8'));
const relInv = JSON.parse(fs.readFileSync('relationship_inventory.json', 'utf8'));

if (objInv.sourceSha256 !== relInv.sourceSha256) {
  throw new Error('object_inventory.json and relationship_inventory.json were generated from different diagram7.json versions -- re-run build_inventory.js before building the snapshot.');
}

const objectsById = new Map(objInv.objects.map(o => [o.oepNodeId, o]));

// Adjacency index: for every object, the list of relationship ids touching
// it (either end) -- lets a comparator answer "what is object X connected
// to" without re-scanning the whole relationship list each time.
const adjacency = {};
for (const o of objInv.objects) adjacency[o.oepNodeId] = [];
for (const r of relInv.relationships) {
  if (adjacency[r.source.oepNodeId]) adjacency[r.source.oepNodeId].push(r.oepRelationshipId);
  if (adjacency[r.target.oepNodeId]) adjacency[r.target.oepNodeId].push(r.oepRelationshipId);
}

const snapshot = {
  $schema: 'trx300-ground-truth-snapshot-v1',
  purpose: 'Single comparison-ready file for a future ingestion benchmark comparator to diff a candidate (ingested) graph against. Derived entirely from object_inventory.json + relationship_inventory.json, which are themselves derived entirely from diagram7.json -- introduces no new data, only re-shapes existing HUMAN_VERIFIED data into a comparator-friendly indexed form.',
  sourceFile: 'platform/oep_studio/samples/diagram7.json',
  sourceSha256: objInv.sourceSha256,
  generatedAt: new Date().toISOString(),
  provenance: 'HUMAN_VERIFIED',
  counts: {
    objects: objInv.objects.length,
    relationships: relInv.relationships.length,
    connectors: objInv.objects.filter(o => o.isConnector).length,
    splices: objInv.objects.filter(o => o.isSplice).length,
    grounds: objInv.objects.filter(o => o.isGround).length,
  },
  objects: objInv.objects,
  relationships: relInv.relationships,
  adjacency,
};

fs.writeFileSync('ground_truth_snapshot.json', JSON.stringify(snapshot, null, 2));
console.log('wrote ground_truth_snapshot.json:', snapshot.counts);
