import 'package:flutter/material.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../l10n/app_localizations.dart';

/// The first thing a new phone shows, before sign-in: what JiraniChama is, in four pages.
/// Shown once (the tour memory's "welcome"); Help shows it again.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final slides = [
      (Icons.account_balance_rounded, JiraniTone.brand, l.welMoneyTitle, l.welMoneyBody),
      (Icons.verified_outlined, JiraniTone.good, l.welRecordsTitle, l.welRecordsBody),
      (Icons.how_to_vote_outlined, JiraniTone.info, l.welTogetherTitle, l.welTogetherBody),
      (Icons.phone_android_rounded, JiraniTone.warning, l.welPhonesTitle, l.welPhonesBody),
    ];
    final last = _page == slides.length - 1;
    return Scaffold(
      key: const ValueKey('welcome'),
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(key: const ValueKey('welcome-skip'), onPressed: widget.onDone,
                child: Text(l.welSkip)),
          ),
          Expanded(
            child: PageView(
              controller: _pages,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                for (final (icon, tone, title, body) in slides)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: JiraniSpace.l),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (icon == Icons.account_balance_rounded)
                        const BrandMark(size: 96)
                      else
                        ToneIcon(icon, tone: tone, size: 96),
                      const SizedBox(height: JiraniSpace.l),
                      Text(title, style: text.headlineSmall, textAlign: TextAlign.center),
                      const SizedBox(height: JiraniSpace.s),
                      Text(body, style: text.bodyLarge, textAlign: TextAlign.center),
                    ]),
                  ),
              ],
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < slides.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(4),
                width: i == _page ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _page ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.all(JiraniSpace.m),
            child: PrimaryButton(
              key: const ValueKey('welcome-next'),
              label: last ? l.welStart : l.welNext,
              onPressed: last ? widget.onDone : () => _pages.nextPage(
                  duration: const Duration(milliseconds: 280), curve: Curves.easeOut),
            ),
          ),
        ]),
      ),
    );
  }
}
