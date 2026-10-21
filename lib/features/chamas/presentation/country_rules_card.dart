import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models.dart';

final countryRulesProvider = FutureProvider.autoDispose.family<Json, (String, String)>(
    (ref, args) => ref.watch(chamaRepositoryProvider).countryRules(args.$1, args.$2));

/// What the chama's country asks of it (the country rule pack): the group size the law
/// allows, rules the law forbids, and duties, each marked done, to do, or a problem.
/// Shown above the rule book on the Rules tab, to every member.
class CountryRulesCard extends ConsumerWidget {
  const CountryRulesCard({super.key, required this.chamaId});

  final String chamaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode == 'sw' ? 'sw' : 'en';
    final data = ref.watch(countryRulesProvider((chamaId, lang))).value;
    if (data == null) return const SizedBox.shrink();
    final items = [for (final i in data['items'] as List) i as Json];
    final country = countryByCode('${data['country']}');
    final problems = items.where((i) => i['ok'] == false && i['level'] != 'duty').length;
    String textOf(Json i) => switch ('${i['key']}') {
          'size' => i['max'] == null
              ? l.packSizeMin('${i['members']}', '${i['min']}')
              : l.packSizeRange('${i['max']}', '${i['members']}', '${i['min']}'),
          'country_rate_high' => l.packRateHigh('${i['max_annual_pct']}'),
          _ => '${i['text'] ?? i['key']}',
        };
    return Padding(
      padding: const EdgeInsets.only(bottom: JiraniSpace.m),
      child: TitledCard(
        key: const ValueKey('country-rules'),
        icon: Icons.gavel_rounded,
        tone: problems > 0 ? JiraniTone.warning : JiraniTone.info,
        title: l.packTitle('${country.flag} ${country.name}'),
        subtitle: problems > 0 ? l.packProblems('$problems') : l.packIntro,
        children: [
          for (final i in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(
                  switch (i['ok']) {
                    true => Icons.check_circle_rounded,
                    false when i['level'] == 'warn' => Icons.error_outline_rounded,
                    false => Icons.cancel_rounded,
                    _ => Icons.radio_button_unchecked_rounded,
                  },
                  size: 20,
                  color: switch (i['ok']) {
                    true => JiraniStatus.of(context).good,
                    false when i['level'] == 'warn' => JiraniStatus.of(context).warning,
                    false => Theme.of(context).colorScheme.error,
                    _ => Theme.of(context).colorScheme.onSurfaceVariant,
                  },
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(textOf(i),
                    style: Theme.of(context).textTheme.bodyMedium)),
              ]),
            ),
          Text(l.packDisclaimer, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
