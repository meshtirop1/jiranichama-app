import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/api/problem.dart';

void main() {
  runApp(const ProviderScope(retry: retryOnlyNetwork, child: JiraniApp()));
}

/// Loads are tried again only when the server was not reached, a few times, backing off.
/// A refusal (401, 403, 404, a rule) is shown at once: retrying it only kept the screen
/// spinning.
Duration? retryOnlyNetwork(int retryCount, Object error) {
  if (error is! ApiProblem || error.code != 'network' || retryCount >= 3) return null;
  return Duration(milliseconds: 400 * (1 << retryCount));
}
