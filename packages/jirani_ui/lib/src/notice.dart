import 'package:flutter/material.dart';

import 'tokens.dart';

enum NoticeTone { info, good, warning, critical }

/// A short message inside a screen: an explanation, a good result, a warning such as a
/// chain-check failure, or an error from the server. Announced to screen readers.
class Notice extends StatelessWidget {
  const Notice(this.message, {super.key, this.tone = NoticeTone.info, this.onTap});

  final String message;
  final NoticeTone tone;

  /// Makes the whole notice a link (with a chevron), e.g. to the screen that fixes it.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = JiraniStatus.of(context);
    final text = Theme.of(context).textTheme;
    final (Color accent, Color bg, Color fg, IconData icon) = switch (tone) {
      NoticeTone.info => (scheme.primary, status.card, scheme.onSurface,
          Icons.info_outline_rounded),
      NoticeTone.good => (status.good, status.goodContainer, status.onGoodContainer,
          Icons.verified_outlined),
      NoticeTone.warning => (status.warning, status.warningContainer,
          status.onWarningContainer, Icons.schedule_rounded),
      NoticeTone.critical => (scheme.error, scheme.errorContainer, scheme.onErrorContainer,
          Icons.error_outline_rounded),
    };
    final radius = BorderRadius.circular(16);
    return Semantics(
      liveRegion: true,
      button: onTap != null,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: tone == NoticeTone.info
              ? scheme.outlineVariant : accent.withValues(alpha: .28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(message, style: text.bodyMedium?.copyWith(color: fg)),
                  ),
                ),
                if (onTap != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, top: 3),
                    child: Icon(Icons.chevron_right_rounded, color: fg.withValues(alpha: .7)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
