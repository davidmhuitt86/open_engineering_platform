/// Human-readable "Suggested Fix" text per `ValidationFinding.code`
/// (WORK_PACKAGE_025, ENGINE-TASK-000125). A Studio-side presentation
/// convenience only — "Validation logic remains Engine-owned": no new
/// checks are added to `oep_engine`'s `ValidationService`, this is
/// purely a lookup from the codes it already emits to friendlier text
/// than the raw finding message.
abstract final class SuggestedFixes {
  static const Map<String, String> _byCode = {
    'missing_symbol': 'Assign a Symbol to this node from the Placement toolbar\'s "Add" menu, '
        'or replace it with a symbol that exists in the Symbol Library.',
    'unknown_symbol': 'This node references a Symbol ID that no longer exists in the Symbol '
        'Library. Use "Replace Symbol" to point it at a valid one.',
    'broken_relationship': 'This relationship references a node that no longer exists. Delete '
        'the relationship, or restore the missing node.',
    'duplicate_node': 'More than one node maps to the same Repository Object. Remove the '
        'duplicate mapping, or merge the nodes.',
    'duplicate_port': 'This node has two ports with the same ID. Rename one of them in the '
        'Symbol Library so ports on this node are unique.',
    'floating_node': 'This node has no relationships. Connect it to the rest of the diagram, '
        'or confirm it is intentionally standalone.',
    'invalid_evidence_mapping': 'This evidence link\'s Source Reference does not resolve to '
        'anything in the active Knowledge Session. Re-attach the evidence, or remove the link.',
  };

  static String? forCode(String code) => _byCode[code];
}
