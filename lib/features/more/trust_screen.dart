import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../l10n/app_localizations.dart';
import '../chamas/presentation/chama_screen.dart';
import '../chamas/presentation/records_tab.dart';

/// "How your records are protected", in plain words, with this phone's own live answers:
/// the chain it checked, the public timestamp, and how many members vouched for it.
class TrustScreen extends ConsumerWidget {
  const TrustScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final chain = ref.watch(chainCheckProvider(chamaId));
    final anchor = ref.watch(anchorCheckProvider(chamaId)).value;
    final myCode = ref.watch(chamaBundleProvider(chamaId)).value?.chama.myMemberCode;
    final vouch = ref.watch(countersignCheckProvider((chamaId, myCode))).value;
    Widget live(bool? ok, String good, String bad, String waiting) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Notice(ok == null ? waiting : (ok ? good : bad),
              tone: ok == null ? NoticeTone.info : (ok ? NoticeTone.good : NoticeTone.critical)),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l.trustTitle)),
      body: ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        Text(l.trustIntro, style: text.bodyLarge),
        const SizedBox(height: JiraniSpace.m),
        TitledCard(
          key: const ValueKey('trust-chain'),
          icon: Icons.link_rounded,
          tone: JiraniTone.good,
          title: l.trustChainTitle,
          children: [
            Text(l.trustChainBody, style: text.bodyMedium),
            chain.when(
              loading: () => live(null, '', '', l.trustChecking),
              error: (_, _) => live(false, '', l.trustChainBad, ''),
              data: (c) => live(c.ok, l.trustChainGood('${c.entries}'), l.trustChainBad, ''),
            ),
          ],
        ),
        const SizedBox(height: JiraniSpace.s),
        TitledCard(
          icon: Icons.draw_outlined,
          tone: JiraniTone.info,
          title: l.trustKeyTitle,
          children: [Text(l.trustKeyBody, style: text.bodyMedium)],
        ),
        const SizedBox(height: JiraniSpace.s),
        TitledCard(
          key: const ValueKey('trust-vouch'),
          icon: Icons.groups_2_outlined,
          tone: JiraniTone.brand,
          title: l.trustVouchTitle,
          children: [
            Text(l.trustVouchBody, style: text.bodyMedium),
            if (vouch != null)
              live(vouch.ok, l.trustVouchCount('${vouch.members.length}'), l.trustVouchBad, ''),
          ],
        ),
        const SizedBox(height: JiraniSpace.s),
        TitledCard(
          key: const ValueKey('trust-anchor'),
          icon: Icons.public_rounded,
          tone: JiraniTone.warning,
          title: l.trustAnchorTitle,
          children: [
            Text(l.trustAnchorBody, style: text.bodyMedium),
            live(anchor?.ok, l.trustAnchorGood, l.trustAnchorBad, l.trustAnchorNone),
          ],
        ),
        const SizedBox(height: JiraniSpace.s),
        TitledCard(
          icon: Icons.lock_person_outlined,
          tone: JiraniTone.neutral,
          title: l.trustStaffTitle,
          children: [Text(l.trustStaffBody, style: text.bodyMedium)],
        ),
      ]),
    );
  }
}
