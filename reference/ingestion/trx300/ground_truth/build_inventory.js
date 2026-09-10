// Build script (not part of the dataset itself) — derives the object
// and relationship inventories DIRECTLY from diagram7.json's own data.
// Run once, output committed; re-run if diagram7.json is ever updated
// and the ground-truth hash in ground_truth_manifest.json is bumped.
'use strict';
const fs = require('fs');
const crypto = require('crypto');

const SRC = 'C:/dev/open_engineering_platform/platform/oep_studio/samples/diagram7.json';
const raw = fs.readFileSync(SRC, 'utf8');
const hash = crypto.createHash('sha256').update(raw).digest('hex');
const d = JSON.parse(raw);

const nodes = d.graph.nodes;
const rels = d.graph.relationships;

// ---- Object inventory ----
const objects = nodes.map(n => {
  const md = n.metadata || {};
  const terminals = md.v2Terminals || [];
  return {
    oepNodeId: n.id,
    v2ModuleId: md.v2ModuleId || null,
    displayName: n.displayName,
    category: md.v2Category || null,
    kind: md.v2Kind || null,
    isConnector: md.v2Connector === true,
    isSplice: md.v2Category === 'splice',
    isGround: md.v2Category === 'ground',
    terminals: terminals.map((t, i) => ({ index: i + 1, name: t.n, color: t.c || null })),
    provenance: 'HUMAN_VERIFIED', // this IS the user's own completed engineering diagram
  };
});

// ---- Relationship inventory ----
const nodeById = new Map(nodes.map(n => [n.id, n]));
const relationships = rels.map(r => {
  const md = r.metadata || {};
  const sourceNode = nodeById.get(r.sourceNode);
  const targetNode = nodeById.get(r.targetNode);
  return {
    oepRelationshipId: r.id,
    v2WireId: md.v2WireId || null,
    label: md.label || null,
    wireColor: md.wireColor || null,
    source: {
      oepNodeId: r.sourceNode,
      displayName: sourceNode ? sourceNode.displayName : null,
      port: md.sourcePort || null,
    },
    target: {
      oepNodeId: r.targetNode,
      displayName: targetNode ? targetNode.displayName : null,
      port: md.targetPort || null,
    },
    // Electrical connectivity classification -- NOT visual adjacency.
    // A relationship touching a splice-category node on either end
    // represents a many-way electrical bridge (the splice's own job);
    // one touching a connector-category node represents a same-pin-only
    // passthrough (see PRODUCT-READINESS-002's AP-CONNECTOR-BRIDGE-001/
    // AP-DEADEND-GENERALIZE-001 for the authoritative solver semantics
    // this classification is DESCRIBING, not redefining).
    touchesSplice: (sourceNode && sourceNode.metadata && sourceNode.metadata.v2Category === 'splice') ||
                   (targetNode && targetNode.metadata && targetNode.metadata.v2Category === 'splice'),
    touchesConnector: (sourceNode && sourceNode.metadata && sourceNode.metadata.v2Connector === true) ||
                       (targetNode && targetNode.metadata && targetNode.metadata.v2Connector === true),
    hasExplicitTerminalRefs: !!(md.sourcePort && md.targetPort),
    provenance: 'HUMAN_VERIFIED',
  };
});

fs.writeFileSync('object_inventory.json', JSON.stringify({
  $schema: 'trx300-ground-truth-object-inventory-v1',
  sourceFile: 'platform/oep_studio/samples/diagram7.json',
  sourceSha256: hash,
  generatedAt: new Date().toISOString(),
  objectCount: objects.length,
  objects,
}, null, 2));

fs.writeFileSync('relationship_inventory.json', JSON.stringify({
  $schema: 'trx300-ground-truth-relationship-inventory-v1',
  sourceFile: 'platform/oep_studio/samples/diagram7.json',
  sourceSha256: hash,
  generatedAt: new Date().toISOString(),
  relationshipCount: relationships.length,
  relationships,
}, null, 2));

// ---- Summary stats for the manifest ----
const byCategory = {};
const byKind = {};
for (const o of objects) {
  if (o.category) byCategory[o.category] = (byCategory[o.category] || 0) + 1;
  if (o.kind) byKind[o.kind] = (byKind[o.kind] || 0) + 1;
}
console.log('sha256:', hash);
console.log('objects:', objects.length, 'relationships:', relationships.length);
console.log('byCategory:', JSON.stringify(byCategory));
console.log('byKind:', JSON.stringify(byKind));
console.log('connectors:', objects.filter(o => o.isConnector).length);
console.log('splices:', objects.filter(o => o.isSplice).length);
console.log('grounds:', objects.filter(o => o.isGround).length);
console.log('relationships with explicit terminal refs on both ends:', relationships.filter(r => r.hasExplicitTerminalRefs).length);
