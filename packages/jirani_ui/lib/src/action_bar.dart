import 'package:flutter/material.dart';

import 'tokens.dart';

/// The screen's main action, pinned to the bottom so it stays in reach above long
/// content such as a rule book. Use as `Scaffold.bottomNavigationBar`.
class ActionBar extends StatelessWidget {
  const ActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(JiraniSpace.l, JiraniSpace.s, JiraniSpace.l,
              JiraniSpace.s),
          child: child,
        ),
      ),
    );
  }
}
