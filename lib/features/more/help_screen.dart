import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../core/tours.dart';
import '../../l10n/app_localizations.dart';
import 'welcome_screen.dart';

/// Answers to what members ask most, the SMS words and USSD menu for basic phones, and the
/// way back to the welcome pages and the guided tours.
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final faq = [
      (l.faqMoneyQ, l.faqMoneyA),
      (l.faqPayQ, l.faqPayA),
      (l.faqLateQ, l.faqLateA),
      (l.faqFineQ, l.faqFineA),
      (l.faqVoteQ, l.faqVoteA),
      (l.faqWrongQ, l.faqWrongA),
      (l.faqLeaveQ, l.faqLeaveA),
      (l.faqPhoneQ, l.faqPhoneA),
      (l.faqSafeQ, l.faqSafeA),
    ];
    final sms = [
      ('BAL / SALIO', l.smsBal), ('DUE / DENI', l.smsDue), ('FINES / FAINI', l.smsFines),
      ('LOAN / MKOPO', l.smsLoan), ('RULES / KANUNI', l.smsRules),
      ('VERIFY / HAKIKI', l.smsVerify), ('YES · NO · ABSTAIN', l.smsVote),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.helpTitle)),
      body: ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        SectionHeader(l.helpFaq),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final (i, (q, a)) in faq.indexed) ...[
              if (i > 0) const Divider(height: 1),
              ExpansionTile(
                key: ValueKey('faq-$i'),
                shape: const Border(),
                title: Text(q, style: text.titleSmall),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(a, style: text.bodyMedium)],
              ),
            ],
          ]),
        ),
        SectionHeader(l.helpBasicPhones),
        TitledCard(
          icon: Icons.sms_outlined,
          tone: JiraniTone.info,
          title: l.helpSmsTitle,
          subtitle: l.helpSmsBody,
          children: [
            for (final (word, what) in sms)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 140, child: Text(word, style: text.labelLarge)),
                  Expanded(child: Text(what, style: text.bodyMedium)),
                ]),
              ),
          ],
        ),
        const SizedBox(height: JiraniSpace.s),
        TitledCard(
          icon: Icons.dialpad_rounded,
          tone: JiraniTone.info,
          title: l.helpUssdTitle,
          children: [Text(l.helpUssdBody, style: text.bodyMedium)],
        ),
        SectionHeader(l.helpMore),
        NavTile(
          key: const ValueKey('help-welcome'),
          icon: Icons.slideshow_rounded,
          title: l.helpWelcomeAgain,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (c) => WelcomeScreen(onDone: () => Navigator.of(c).pop()))),
        ),
        NavTile(
          key: const ValueKey('help-tours'),
          icon: Icons.tour_outlined,
          title: l.settingsTours,
          subtitle: l.settingsToursSub,
          onTap: () async {
            await replayTours(ref);
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(l.helpToursOn)));
            }
          },
        ),
      ]),
    );
  }
}
