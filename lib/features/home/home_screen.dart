import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../core/labels.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../auth/application/session.dart';
import '../auth/presentation/problem_text.dart';
import '../chamas/data/models.dart';

final chamaListProvider = FutureProvider.autoDispose<List<Chama>>(
    (ref) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).list();
});

/// The member's chamas, and the way into creating or joining one.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final chamas = ref.watch(chamaListProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.homeTitle),
        actions: [
          IconButton(
            tooltip: l.signOut,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sessionProvider.notifier).signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(chamaListProvider.future),
        child: chamas.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(padding: const EdgeInsets.all(JiraniSpace.l), children: [
            Notice(problemText(l, e), tone: NoticeTone.critical),
            TextButton(onPressed: () => ref.invalidate(chamaListProvider), child: Text(l.retry)),
          ]),
          data: (list) => ListView(
            padding: const EdgeInsets.all(JiraniSpace.m),
            children: [
              if (list.isEmpty) Notice(l.homeEmpty),
              for (final c in list)
                Card(
                  child: ListTile(
                    title: Text(c.name),
                    subtitle: Text('${typeLabel(l, c.type)} · ${stateLabel(l, c.state)}'
                        '${c.myRole != null ? ' · ${roleLabel(l, c.myRole!)}' : ''}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await context.push('/chamas/${c.id}');
                      ref.invalidate(chamaListProvider);
                    },
                  ),
                ),
              const SizedBox(height: JiraniSpace.l),
              PrimaryButton(
                label: l.createChama,
                onPressed: () async {
                  await context.push('/create');
                  ref.invalidate(chamaListProvider);
                },
              ),
              const SizedBox(height: JiraniSpace.s),
              OutlinedButton(
                onPressed: () async {
                  await context.push('/join');
                  ref.invalidate(chamaListProvider);
                },
                child: Text(l.joinChama),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
