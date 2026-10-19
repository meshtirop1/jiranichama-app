import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'canonical_json.dart';

/// The nightly public anchor (jiranichama-api docs/flows/anchoring.md): a chama's chain
/// head is a leaf, SHA-256 of canonical JSON {chama_id, seq, hash}; a node is SHA-256 of
/// its two children's bytes, left then right.
String anchorLeaf(String chamaId, int seq, String headHash) => sha256
    .convert(utf8.encode(canonicalJson({'chama_id': chamaId, 'seq': seq, 'hash': headHash})))
    .toString();

List<int> _hex(String h) =>
    [for (var i = 0; i < h.length; i += 2) int.parse(h.substring(i, i + 2), radix: 16)];

String _parent(String a, String b) => sha256.convert([..._hex(a), ..._hex(b)]).toString();

/// Walks a Merkle path (`[{side: left|right, hash}]`, leaf first) and says whether it
/// reaches [root].
bool verifyAnchorPath(String leaf, List<Map<String, Object?>> path, String root) {
  var h = leaf;
  for (final step in path) {
    final sibling = step['hash'] as String;
    h = step['side'] == 'left' ? _parent(sibling, h) : _parent(h, sibling);
  }
  return h == root;
}
