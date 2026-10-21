import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../l10n/app_localizations.dart';
import '../auth/presentation/problem_text.dart';
import '../chamas/presentation/vote_screen.dart';
import 'automation_repository.dart';
import 'models.dart';
import 'motions.dart';

/// The bell in the top bar: how many notices are unread.
class NoticesButton extends ConsumerWidget {
  const NoticesButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final unread = ref.watch(noticesProvider).value?.unread ?? 0;
    return IconButton(
      key: const ValueKey('notices-button'),
      tooltip: l.ntcTitle,
      onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NoticesScreen())),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 9 ? '9+' : '$unread'),
        child: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }
}

IconData _icon(String kind) => switch (kind) {
      'due' => Icons.event_rounded,
      'vote' || 'motion' => Icons.how_to_vote_outlined,
      'approve' || 'money_out' => Icons.north_east_rounded,
      'cash' => Icons.payments_outlined,
      'statement' => Icons.description_outlined,
      'meeting' => Icons.groups_2_outlined,
      'monthly' => Icons.summarize_outlined,
      'bill' => Icons.receipt_outlined,
      'unmatched' => Icons.manage_search_rounded,
      'payer' => Icons.phone_android_rounded,
      _ => Icons.notifications_none_rounded,
    };

/// Every reminder and alert JiraniChama sent this person, newest first. Opening the list
/// marks them read; tapping one goes where it is about.
class NoticesScreen extends ConsumerStatefulWidget {
  const NoticesScreen({super.key});

  @override
  ConsumerState<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends ConsumerState<NoticesScreen> {
  bool _marked = false;

  Future<void> _markRead() async {
    if (_marked) return;
    _marked = true;
    try {
      await ref.read(automationRepositoryProvider).readNotices();
    } catch (_) {
      return; // they stay unread; nothing else depends on it
    }
    // The badge and the list show them read.
    if (mounted) ref.invalidate(noticesProvider);
  }

  Future<void> _open(NoticeItem n) async {
    final l = AppLocalizations.of(context);
    final chama = n.chamaId;
    if (chama == null) return;
    switch (n.screen) {
      case 'vote' when n.targetId != null:
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => VoteScreen(chamaId: chama, voteId: n.targetId!)));
      case 'motion':
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MotionsScreen(chamaId: chama)));
      case 'money_out':
        await context.push('/chamas/$chama/money-out');
      case 'cash':
        await context.push('/chamas/$chama/cash');
      case 'statements':
        await context.push('/chamas/$chama/statements');
      case 'unmatched':
        await context.push('/chamas/$chama/unmatched');
      case 'bill' when n.targetId != null:
        final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
              title: Text(l.ntcBillTitle),
              content: Text(n.text),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
                FilledButton(onPressed: () => Navigator.pop(c, true),
                    child: Text(l.ntcBillPropose)),
              ],
            ));
        if (yes != true || !mounted) return;
        try {
          await ref.read(automationRepositoryProvider).proposeBill(n.targetId!);
          if (mounted) await context.push('/chamas/$chama/money-out');
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(problemText(l, e))));
          }
        }
      default:
        await context.push('/chamas/$chama');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final notices = ref.watch(noticesProvider);
    if (notices.hasValue) _markRead();
    return Scaffold(
      appBar: AppBar(title: Text(l.ntcTitle)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(noticesProvider.future),
        child: notices.when(
          loading: () => const LoadingView(),
          error: (e, _) => ListView(padding: const EdgeInsets.all(JiraniSpace.m),
              children: [Notice(problemText(l, e), tone: NoticeTone.critical)]),
          data: (list) => ListView(
            padding: const EdgeInsets.all(JiraniSpace.m),
            children: [
              if (list.items.isEmpty)
                SurfaceCard(child: EmptyState(icon: Icons.notifications_none_rounded,
                    title: l.ntcEmpty)),
              for (final n in list.items)
                SurfaceCard(
                  key: ValueKey('notice-${n.id}'),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: ToneIcon(_icon(n.kind), size: 40,
                        tone: n.urgent ? JiraniTone.warning : JiraniTone.info),
                    title: Text(n.text, style: n.read ? text.bodyMedium
                        : text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    subtitle: Text([if (n.chama != null) n.chama!,
                      n.at.substring(0, 16).replaceFirst('T', ' ')].join(' · ')),
                    onTap: () => _open(n),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
