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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in clauses)
          Padding(
            padding: const EdgeInsets.only(bottom: JiraniSpace.s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 44, child: Text(c.ref, style: text.labelLarge)),
                Expanded(child: Text(c.text, style: text.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}
