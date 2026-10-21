import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/labels.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';

const _types = ['merry_go_round', 'table_banking', 'welfare', 'investment_club'];
const _founderRoles = ['chair', 'treasurer', 'secretary', 'member'];

class CreateChamaScreen extends ConsumerStatefulWidget {
  const CreateChamaScreen({super.key});

  @override
  ConsumerState<CreateChamaScreen> createState() => _CreateChamaScreenState();
}

class _CreateChamaScreenState extends ConsumerState<CreateChamaScreen> {
  final _name = TextEditingController();
  String _type = _types.first;
  String _role = 'chair';
  // One key per attempt on this screen: a retry after a dropped connection is the
  // same request, not a second chama.
  final _key = newIdempotencyKey();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().length < 2) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final chama = await ref.read(chamaRepositoryProvider).create(
          name: _name.text.trim(), type: _type, myRole: _role, idempotencyKey: _key);
      if (mounted) context.pushReplacement('/chamas/${chama.id}');
    } catch (e) {
      if (mounted) setState(() => _error = problemText(AppLocalizations.of(context), e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.createChama)),
      body: ListView(
        padding: const EdgeInsets.all(JiraniSpace.l),
        children: [
          const Align(alignment: Alignment.centerLeft,
              child: ToneIcon(Icons.groups_2_outlined, size: 56)),
          const SizedBox(height: JiraniSpace.m),
          Text(l.createHeading, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: JiraniSpace.xs),
          Text(l.createIntro, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: JiraniSpace.l),
          TextField(controller: _name, decoration: InputDecoration(labelText: l.chamaNameLabel)),
          const SizedBox(height: JiraniSpace.m),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: InputDecoration(labelText: l.chamaTypeLabel),
            items: [for (final t in _types) DropdownMenuItem(value: t, child: Text(typeLabel(l, t)))],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, JiraniSpace.s, 4, 0),
            child: Text(switch (_type) {
              'merry_go_round' => l.typeAboutMerry,
              'table_banking' => l.typeAboutTable,
              'welfare' => l.typeAboutWelfare,
              _ => l.typeAboutInvestment,
            }, key: const ValueKey('type-about'),
                style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(height: JiraniSpace.m),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: InputDecoration(labelText: l.myRoleLabel),
            items: [
              for (final r in _founderRoles) DropdownMenuItem(value: r, child: Text(roleLabel(l, r))),
            ],
            onChanged: (v) => setState(() => _role = v ?? _role),
          ),
          const SizedBox(height: JiraniSpace.m),
          Notice(l.createNext),
          if (_error != null) ...[
            const SizedBox(height: JiraniSpace.m),
            Notice(_error!, tone: NoticeTone.critical),
          ],
          const SizedBox(height: JiraniSpace.l),
          PrimaryButton(label: l.createButton, busy: _busy, onPressed: _create),
        ],
      ),
    );
  }
}
