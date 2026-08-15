/// OIP-SPEC-001 §25 — Version Negotiation: given a Host's and a Client's
/// own supported protocol version lists, resolves the highest version
/// both sides support, or `null` if no compatible version exists (in
/// which case §25 specifies "Connection Refused").
///
/// Versions are compared as simple dotted strings (`'1.0'`, `'1.2'`) —
/// deliberately not semver-strict, since OIP's own versioning philosophy
/// (§26) only requires ordering, not full semver semantics.
String? negotiateProtocolVersion(List<String> hostVersions, List<String> clientVersions) {
  final compatible = hostVersions.toSet().intersection(clientVersions.toSet());
  if (compatible.isEmpty) return null;
  final sorted = compatible.toList()..sort(_compareVersions);
  return sorted.last;
}

int _compareVersions(String a, String b) {
  final partsA = a.split('.').map(int.parse).toList();
  final partsB = b.split('.').map(int.parse).toList();
  final length = partsA.length > partsB.length ? partsA.length : partsB.length;
  for (var i = 0; i < length; i++) {
    final valueA = i < partsA.length ? partsA[i] : 0;
    final valueB = i < partsB.length ? partsB[i] : 0;
    if (valueA != valueB) return valueA.compareTo(valueB);
  }
  return 0;
}
