import 'package:flutter/material.dart';

import 'tokens.dart';

enum NoticeTone { info, warning, critical }

/// A short message inside a screen: an error from the server, or a warning such as a
/// chain-check failure. Announced to screen readers when it appears.
class Notice extends StatelessWidget {
  const Notice(this.message, {super.key, this.tone = NoticeTone.info});

  final String message;
  final NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg, IconData icon) = switch (tone) {
      NoticeTone.info => (scheme.secondaryContainer, scheme.onSecondaryContainer,
          Icons.info_outline),
      NoticeTone.warning => (scheme.tertiaryContainer, scheme.onTertiaryContainer,
          Icons.warning_amber_outlined),
      NoticeTone.critical => (scheme.errorContainer, scheme.onErrorContainer,
          Icons.error_outline),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(JiraniSpace.m),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(JiraniRadius.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg),
            const SizedBox(width: JiraniSpace.s),
            Expanded(child: Text(message, style: TextStyle(color: fg))),
          ],
        ),
      ),
    );
  }
}
