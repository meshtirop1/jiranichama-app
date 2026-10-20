import 'package:flutter/material.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../data/models.dart';

/// The numbered rule book. Rule numbers are shown so a fine or refusal that names
/// "rule 3.2" can be found.
class RuleBookList extends StatelessWidget {
  const RuleBookList(this.clauses, {super.key});

  final List<Clause> clauses;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, c) in clauses.indexed) ...[
            if (i > 0) const Divider(indent: 70),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(c.ref, style: text.labelMedium?.copyWith(
                        color: scheme.onPrimaryContainer, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Text(c.text, style: text.bodyMedium)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
