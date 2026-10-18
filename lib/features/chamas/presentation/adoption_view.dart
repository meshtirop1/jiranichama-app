import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../data/models.dart';
import 'chama_screen.dart';
import 'widgets/rule_book_list.dart';
import 'widgets/sms_code_sheet.dart';

/// Founding members read the rule book and confirm it with an SMS code (5.1 step 11).
class AdoptionView extends ConsumerStatefulWidget {
  const AdoptionView({super.key, required this.bundle, required this.onChanged});

  final ChamaBundle bundle;
  final VoidCallback onChanged;

  @override
  ConsumerState<AdoptionView> createState() => _AdoptionViewState();
}

class _AdoptionViewState extends ConsumerState<AdoptionView> {
  String? _error;
  bool _busy = false;

  Future<void> _confirm() async {
    final repo = ref.read(chamaRepositoryProvider);
    final id = widget.bundle.chama.id;
    setState(() {
      _busy = true;
      _error = null;
    });
    ChallengeSent sent;
    try {
      sent = await repo.startAdoption(id);
    } catch (e) {
      if (mounted) setState(() => _error = problemText(AppLocalizations.of(context), e));
      return;
    } finally {
      // Busy only while the code is being sent, not while the member types it.
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    final ok = await confirmWithSmsCode(context, sent: sent, onCode: (code) async {
      await repo.confirmAdoption(id, challengeId: sent.challengeId, code: code);
    });
    if (ok) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final b = widget.bundle;
    final status = b.chama.adoption;
    final me = b.me;
    final lang = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(b.chama.name)),
      body: ListView(
        padding: const EdgeInsets.all(JiraniSpace.l),
        children: [
          if (status != null)
            Notice(l.adoptionProgress(status.confirmed, status.founding, status.needed)),
          const SizedBox(height: JiraniSpace.m),
          RuleBookList(b.rules.clauses(lang)),
          if (_error != null) ...[
            const SizedBox(height: JiraniSpace.m),
            Notice(_error!, tone: NoticeTone.critical),
          ],
          const SizedBox(height: JiraniSpace.l),
          if (me != null && me.isFounding && !me.adoptedRules)
            PrimaryButton(label: l.confirmRules, busy: _busy, onPressed: _confirm)
          else if (me != null && me.adoptedRules)
            Notice(l.youConfirmed),
        ],
      ),
    );
  }
}
