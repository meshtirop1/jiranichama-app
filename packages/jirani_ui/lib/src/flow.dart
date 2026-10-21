import 'package:flutter/material.dart';

import 'tokens.dart';

/// Which way money moved, as members read it: into the chama, out of it, or a fine.
enum MoneyFlow { incoming, outgoing, fine, other }

/// The sign for a money movement. Each kind differs in colour AND shape, so it still
/// reads for someone who cannot tell green from red:
/// - in: a green arrow coming down into the pot (bottom-left);
/// - out: a red arrow leaving up and away (top-right);
/// - fine: an amber gavel in a square.
class FlowArrow extends StatelessWidget {
  const FlowArrow(this.flow, {super.key, this.size = 42, this.muted = false});

  final MoneyFlow flow;
  final double size;

  /// A reversed record: grey, so nobody counts it.
  final bool muted;

  static JiraniTone toneOf(MoneyFlow f) => switch (f) {
        MoneyFlow.incoming => JiraniTone.good,
        MoneyFlow.outgoing => JiraniTone.critical,
        MoneyFlow.fine => JiraniTone.warning,
        MoneyFlow.other => JiraniTone.neutral,
      };

  static IconData iconOf(MoneyFlow f) => switch (f) {
        MoneyFlow.incoming => Icons.south_west_rounded,
        MoneyFlow.outgoing => Icons.north_east_rounded,
        MoneyFlow.fine => Icons.gavel_rounded,
        MoneyFlow.other => Icons.receipt_long_outlined,
      };

  /// "+" for money in, "−" for money out; fines and other records carry no sign.
  static String signOf(MoneyFlow f) => switch (f) {
        MoneyFlow.incoming => '+',
        MoneyFlow.outgoing => '−',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (strong, soft, _) =
        JiraniStatus.of(context).colors(scheme, muted ? JiraniTone.neutral : toneOf(flow));
    final round = flow == MoneyFlow.incoming || flow == MoneyFlow.outgoing;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: soft,
        // Money in and out are round; a fine is a square, like a ticket.
        shape: round ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: round ? null : BorderRadius.circular(size * .24),
        border: Border.all(color: strong.withValues(alpha: .35), width: 1.4),
      ),
      child: Stack(alignment: Alignment.center, children: [
        Icon(iconOf(flow), size: size * .52, color: strong),
        if (flow == MoneyFlow.incoming || flow == MoneyFlow.outgoing)
          // A short bar the arrow points into (in) or away from (out): the pot.
          Positioned(
            left: flow == MoneyFlow.incoming ? size * .2 : null,
            right: flow == MoneyFlow.outgoing ? size * .2 : null,
            bottom: flow == MoneyFlow.incoming ? size * .2 : null,
            top: flow == MoneyFlow.outgoing ? size * .2 : null,
            child: Container(width: size * .14, height: size * .14,
                decoration: BoxDecoration(color: strong, shape: BoxShape.circle)),
          ),
      ]),
    );
  }
}

/// A small total with its arrow ("↙ In KES 12,000"), for the top of a list of records.
class FlowTotal extends StatelessWidget {
  const FlowTotal({super.key, required this.flow, required this.label, required this.value,
      this.selected = false, this.onTap});

  final MoneyFlow flow;
  final String label;
  final String value;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // Nothing moved this way: plain, not green or red.
    final quiet = RegExp(r'^\D*0([.,]0+)?$').hasMatch(value.trim());
    final (strong, soft, _) = JiraniStatus.of(context).colors(
        scheme, quiet ? JiraniTone.neutral : FlowArrow.toneOf(flow));
    return Material(
      color: selected ? soft : JiraniStatus.of(context).card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(JiraniRadius.button),
        side: BorderSide(color: selected ? strong : scheme.outlineVariant,
            width: selected ? 1.6 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FlowArrow(flow, size: 30),
            const SizedBox(height: 8),
            Text(label, style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: text.titleSmall?.copyWith(color: strong,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()])),
            ),
          ]),
        ),
      ),
    );
  }
}
