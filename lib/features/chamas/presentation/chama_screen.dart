import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../data/models.dart';
import 'active_view.dart';
import 'adoption_view.dart';
import 'setup_view.dart';

class ChamaBundle {
  ChamaBundle(this.chama, this.members, this.rules);
  final Chama chama;
  final List<Member> members;
  final RuleBook rules;

  Member? get me => members.where((m) => m.memberCode == chama.myMemberCode).firstOrNull;
}

final chamaBundleProvider =
    FutureProvider.autoDispose.family<ChamaBundle, String>((ref, id) async {
  ref.cacheFor(const Duration(minutes: 5));
  final repo = ref.watch(chamaRepositoryProvider);
  final results = await Future.wait([repo.get(id), repo.members(id), repo.rules(id)]);
  return ChamaBundle(results[0] as Chama, results[1] as List<Member>, results[2] as RuleBook);
});

/// One chama. What it shows follows the chama's state: setup, confirming the rules,
/// or the active chama.
class ChamaScreen extends ConsumerWidget {
  const ChamaScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final bundle = ref.watch(chamaBundleProvider(id));
    void refresh() => ref.invalidate(chamaBundleProvider(id));
    return bundle.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ListView(padding: const EdgeInsets.all(JiraniSpace.l), children: [
          Notice(problemText(l, e), tone: NoticeTone.critical),
          TextButton(onPressed: refresh, child: Text(l.retry)),
        ]),
      ),
      data: (b) {
        // One chama is on screen at a time: its amounts show in its own currency.
        Kes.currency = b.chama.currency;
        return switch (b.chama.state) {
        ChamaState.setup || ChamaState.awaitingOfficials =>
          SetupView(bundle: b, onChanged: refresh),
        ChamaState.awaitingAdoption => AdoptionView(bundle: b, onChanged: refresh),
        _ => ActiveView(bundle: b, onChanged: refresh),
      };
      },
    );
  }
}
