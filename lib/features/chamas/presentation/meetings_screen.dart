import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_ui/jirani_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../data/models.dart';

final meetingsProvider = FutureProvider.autoDispose.family<List<Meeting>, String>(
    (ref, chamaId) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).meetings(chamaId);
});

/// Reads a meeting's QR code with the camera. Behind a provider so tests hand in a code.
abstract class CodeScanner {
  Future<String?> scan(BuildContext context);
}

class CameraCodeScanner implements CodeScanner {
  @override
  Future<String?> scan(BuildContext context) => Navigator.of(context)
      .push<String>(MaterialPageRoute(builder: (_) => const _ScanScreen()));
}

final codeScannerProvider = Provider<CodeScanner>((ref) => CameraCodeScanner());

class _ScanScreen extends StatefulWidget {
  const _ScanScreen();

  @override
  State<_ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<_ScanScreen> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.meetScanTitle)),
      body: MobileScanner(onDetect: (capture) {
        final raw = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
        if (raw == null || _done || !raw.startsWith('jcmeet:')) return;
        _done = true;
        Navigator.of(context).pop(raw);
      }),
    );
  }
}

String meetingStateLabel(AppLocalizations l, String state) => switch (state) {
      'scheduled' => l.meetScheduled,
      'in_progress' => l.meetInProgress,
      'attendance_closed' => l.meetAttendanceClosed,
      'minutes_pending' => l.meetMinutesPending,
      'sealed' => l.meetSealed,
      _ => l.meetCancelled,
    };

String personStatusLabel(AppLocalizations l, String status) => switch (status) {
      'present' => l.meetPresent,
      'late' => l.meetLate,
      'excused' => l.meetExcused,
      'apology' => l.meetApology,
      'absent' => l.meetAbsent,
      _ => l.meetExpected,
    };

String _when(BuildContext context, String iso) {
  final t = DateTime.parse(iso).toLocal();
  final loc = MaterialLocalizations.of(context);
  return '${loc.formatMediumDate(t)} ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(t))}';
}

/// On the overview: the next meeting, and the way to every meeting.
class MeetingsCard extends ConsumerWidget {
  const MeetingsCard({super.key, required this.chamaId});

  final String chamaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final list = ref.watch(meetingsProvider(chamaId)).value ?? const <Meeting>[];
    final next = list.where((m) => m.state == 'scheduled' || m.state == 'in_progress')
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return Padding(
      padding: const EdgeInsets.only(top: JiraniSpace.s),
      child: Card(
        child: ListTile(
          key: const ValueKey('meetings-card'),
          leading: const Icon(Icons.groups_outlined),
          title: Text(l.meetingsTitle),
          subtitle: Text(next.isEmpty ? l.meetNoneComing
              : l.meetNext(next.first.title, _when(context, next.first.startsAt))),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MeetingsScreen(chamaId: chamaId))),
        ),
      ),
    );
  }
}

class MeetingsScreen extends ConsumerWidget {
  const MeetingsScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(meetingsProvider(chamaId));
    final runner = ref.watch(_runsMeetingsProvider(chamaId)).value ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(l.meetingsTitle)),
      floatingActionButton: runner
          ? FloatingActionButton.extended(
              key: const ValueKey('schedule-meeting'),
              icon: const Icon(Icons.add),
              label: Text(l.meetSchedule),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ScheduleMeetingScreen(chamaId: chamaId))),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(padding: const EdgeInsets.all(JiraniSpace.m),
            child: Notice(problemText(l, e), tone: NoticeTone.critical)),
        data: (list) => list.isEmpty
            ? Padding(padding: const EdgeInsets.all(JiraniSpace.m),
                child: Notice(l.meetNoneYet))
            : ListView(children: [
                for (final m in list)
                  ListTile(
                    title: Text(m.title),
                    subtitle: Text('${_when(context, m.startsAt)} · '
                        '${meetingStateLabel(l, m.state)}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => MeetingScreen(chamaId: chamaId, meetingId: m.id))),
                  ),
              ]),
      ),
    );
  }
}

/// Whether I run meetings here: the API says so on every meeting; with none yet, the
/// secretary (or an official when there is no secretary) does.
final _runsMeetingsProvider = FutureProvider.autoDispose.family<bool, String>((ref, id) async {
  final list = await ref.watch(meetingsProvider(id).future);
  if (list.isNotEmpty) return list.first.iRun;
  final repo = ref.watch(chamaRepositoryProvider);
  final chama = await repo.get(id);
  if (chama.myRole == 'secretary') return true;
  final members = await repo.members(id);
  return chama.iAmOfficial && !members.any((m) => m.role == 'secretary');
});

class ScheduleMeetingScreen extends ConsumerStatefulWidget {
  const ScheduleMeetingScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  ConsumerState<ScheduleMeetingScreen> createState() => _ScheduleMeetingScreenState();
}

class _ScheduleMeetingScreenState extends ConsumerState<ScheduleMeetingScreen> {
  final _title = TextEditingController();
  final _place = TextEditingController();
  final _link = TextEditingController();
  final _agenda = TextEditingController();
  final _key = newIdempotencyKey();
  late DateTime _day = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 7));
  TimeOfDay _time = const TimeOfDay(hour: 14, minute: 0);
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_title, _place, _link, _agenda]) {
      c.dispose();
    }
    super.dispose();
  }

  DateTime get _startsAt =>
      DateTime(_day.year, _day.month, _day.day, _time.hour, _time.minute);

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final m = await ref.read(chamaRepositoryProvider).scheduleMeeting(widget.chamaId, {
        'title': _title.text.trim(), 'starts_at': _startsAt.toUtc().toIso8601String(),
        'place': _place.text.trim(), 'online_link': _link.text.trim(),
        'agenda': _agenda.text.trim(),
      }, idempotencyKey: _key);
      ref.invalidate(meetingsProvider(widget.chamaId));
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => MeetingScreen(chamaId: widget.chamaId, meetingId: m.id)));
      }
    } catch (e) {
      if (mounted) setState(() => _error = problemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final loc = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.meetSchedule)),
      bottomNavigationBar: ActionBar(
          child: PrimaryButton(label: l.meetSchedule, busy: _busy, onPressed: _save)),
      body: ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        Notice(l.meetScheduleIntro),
        if (_error != null) ...[
          const SizedBox(height: JiraniSpace.s),
          Notice(_error!, tone: NoticeTone.critical),
        ],
        TextField(key: const ValueKey('meet-title'), controller: _title,
            decoration: InputDecoration(labelText: l.meetTitleLabel)),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            key: const ValueKey('meet-day'),
            icon: const Icon(Icons.event),
            label: Text(loc.formatMediumDate(_day)),
            onPressed: () async {
              final d = await showDatePicker(context: context, initialDate: _day,
                  firstDate: DateUtils.dateOnly(DateTime.now()),
                  lastDate: DateTime.now().add(const Duration(days: 365)));
              if (d != null) setState(() => _day = d);
            },
          )),
          const SizedBox(width: JiraniSpace.s),
          Expanded(child: OutlinedButton.icon(
            key: const ValueKey('meet-time'),
            icon: const Icon(Icons.schedule),
            label: Text(loc.formatTimeOfDay(_time)),
            onPressed: () async {
              final t = await showTimePicker(context: context, initialTime: _time);
              if (t != null) setState(() => _time = t);
            },
          )),
        ]),
        TextField(key: const ValueKey('meet-place'), controller: _place,
            decoration: InputDecoration(labelText: l.meetPlaceLabel)),
        TextField(key: const ValueKey('meet-link'), controller: _link,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(labelText: l.meetLinkLabel)),
        TextField(key: const ValueKey('meet-agenda'), controller: _agenda, maxLines: 4,
            decoration: InputDecoration(labelText: l.meetAgendaLabel)),
      ]),
    );
  }
}

/// One meeting: details, my status, and, by its state, apologies, check-in, the
/// secretary's attendance list and code, minutes and objections.
class MeetingScreen extends ConsumerStatefulWidget {
  const MeetingScreen({super.key, required this.chamaId, required this.meetingId});

  final String chamaId;
  final String meetingId;

  @override
  ConsumerState<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends ConsumerState<MeetingScreen> {
  String? _error;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(meetingsProvider(widget.chamaId));
    } catch (e) {
      if (mounted) setState(() => _error = problemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _ask(String title, String label, {int lines = 2}) =>
      showDialog<String>(context: context, builder: (_) => _AskDialog(
          title: title, label: label, lines: lines));

  Future<void> _checkIn() async {
    final l = AppLocalizations.of(context);
    final scanned = await ref.read(codeScannerProvider).scan(context);
    if (!mounted || scanned == null) return;
    await _run(() => ref.read(chamaRepositoryProvider)
        .checkIn(widget.meetingId, scanned.split(':').last));
    if (mounted && _error == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.meetCheckedIn)));
    }
  }

  Future<void> _typeCode() async {
    final l = AppLocalizations.of(context);
    final code = await _ask(l.meetTypeCode, l.meetCodeLabel, lines: 1);
    if (code == null || code.trim().isEmpty) return;
    await _run(() => ref.read(chamaRepositoryProvider).checkIn(widget.meetingId, code.trim()));
  }

  Future<void> _minutes() async {
    final l = AppLocalizations.of(context);
    final result = await Navigator.of(context).push<({String text, PickedFile? photo})>(
        MaterialPageRoute(builder: (_) => const _MinutesEditor()));
    if (result == null) return;
    await _run(() => ref.read(chamaRepositoryProvider).postMinutes(widget.meetingId,
        text: result.text, photo: result.photo));
    if (mounted && _error == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.meetMinutesSent)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final list = ref.watch(meetingsProvider(widget.chamaId));
    final m = list.value?.where((m) => m.id == widget.meetingId).firstOrNull;
    if (m == null) {
      return Scaffold(appBar: AppBar(), body: list.hasError
          ? Padding(padding: const EdgeInsets.all(JiraniSpace.m),
              child: Notice(problemText(l, list.error!), tone: NoticeTone.critical))
          : const Center(child: CircularProgressIndicator()));
    }
    final repo = ref.read(chamaRepositoryProvider);
    final minutes = m.minutes.isEmpty ? null : m.minutes.first;
    final openMinutes = m.state == 'minutes_pending' && minutes != null;

    return Scaffold(
      appBar: AppBar(title: Text(m.title)),
      body: ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        Text(_when(context, m.startsAt), style: text.titleMedium),
        if (m.place.isNotEmpty) Text(m.place),
        if (m.onlineLink.isNotEmpty) SelectableText(m.onlineLink),
        const SizedBox(height: JiraniSpace.s),
        Notice(m.state == 'cancelled' ? l.meetCancelledBecause(m.cancelReason)
            : meetingStateLabel(l, m.state)),
        if (m.myStatus != null) ...[
          const SizedBox(height: JiraniSpace.xs),
          Text(l.meetMyStatus(personStatusLabel(l, m.myStatus!)), style: text.bodyMedium),
        ],
        if (_error != null) ...[
          const SizedBox(height: JiraniSpace.s),
          Notice(_error!, tone: NoticeTone.critical),
        ],
        if (m.agenda.isNotEmpty) ...[
          const SizedBox(height: JiraniSpace.m),
          Text(l.meetAgendaLabel, style: text.titleSmall),
          Text(m.agenda),
        ],
        const SizedBox(height: JiraniSpace.m),

        // Members
        if (m.state == 'scheduled' && m.myStatus == 'expected')
          OutlinedButton(
            key: const ValueKey('meet-apology'),
            onPressed: _busy ? null : () async {
              final reason = await _ask(l.meetApologySend, l.meetApologyReason);
              if (reason == null || reason.trim().isEmpty) return;
              await _run(() => repo.apologise(m.id, reason.trim()));
            },
            child: Text(l.meetApologySend),
          ),
        if (m.state == 'in_progress' && m.myStatus == 'expected') ...[
          FilledButton.icon(
            key: const ValueKey('meet-scan'),
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(l.meetCheckIn),
            onPressed: _busy ? null : _checkIn,
          ),
          TextButton(key: const ValueKey('meet-type-code'),
              onPressed: _busy ? null : _typeCode, child: Text(l.meetTypeCode)),
        ],

        // The secretary
        if (m.iRun && m.state == 'scheduled') ...[
          FilledButton(key: const ValueKey('meet-start'),
              onPressed: _busy ? null : () => _run(() => repo.startMeeting(m.id)),
              child: Text(l.meetStart)),
          TextButton(
            key: const ValueKey('meet-cancel'),
            onPressed: _busy ? null : () async {
              final reason = await _ask(l.meetCancel, l.meetCancelReason);
              if (reason == null || reason.trim().isEmpty) return;
              await _run(() => repo.cancelMeeting(m.id, reason.trim()));
            },
            child: Text(l.meetCancel),
          ),
        ],
        if (m.iRun && m.state == 'in_progress') ...[
          FilledButton.icon(
            key: const ValueKey('meet-show-code'),
            icon: const Icon(Icons.qr_code_2),
            label: Text(l.meetShowCode),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => _CodeScreen(meetingId: m.id))),
          ),
          OutlinedButton(
            key: const ValueKey('meet-close'),
            onPressed: _busy ? null : () async {
              final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                content: Text(l.meetCloseConfirm),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false),
                      child: Text(MaterialLocalizations.of(c).cancelButtonLabel)),
                  FilledButton(onPressed: () => Navigator.pop(c, true),
                      child: Text(l.meetClose)),
                ],
              ));
              if (ok == true) await _run(() => repo.closeAttendance(m.id));
            },
            child: Text(l.meetClose),
          ),
        ],
        if (m.iRun && (m.state == 'attendance_closed'
            || (openMinutes && minutes.objections.isNotEmpty)))
          FilledButton(key: const ValueKey('meet-write-minutes'),
              onPressed: _busy ? null : _minutes,
              child: Text(minutes == null ? l.meetWriteMinutes : l.meetReviseMinutes)),

        // Who
        const SizedBox(height: JiraniSpace.m),
        Text(l.meetPeople(m.people.where((p) => p.status == 'present' || p.status == 'late')
            .length, m.people.length), style: text.titleSmall),
        for (final p in m.people)
          ListTile(
            key: ValueKey('meet-person-${p.memberCode}'),
            dense: true,
            title: Text(p.name),
            subtitle: Text([personStatusLabel(l, p.status), ?p.reason].join(' · ')),
            trailing: m.iRun && m.state == 'in_progress'
                && (p.status == 'expected' || p.status == 'apology')
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    TextButton(key: ValueKey('mark-${p.memberCode}'),
                        onPressed: _busy ? null
                            : () => _run(() => repo.markAttendance(m.id, p.membershipId)),
                        child: Text(l.meetMarkPresent)),
                    TextButton(
                        onPressed: _busy ? null : () => _run(
                            () => repo.markAttendance(m.id, p.membershipId, late: true)),
                        child: Text(l.meetMarkLate)),
                  ])
                : null,
          ),
        if (m.attendanceReceipt != null)
          Text(l.meetAttendanceReceipt(m.attendanceReceipt!), style: text.bodySmall),

        // Minutes
        if (minutes != null) ...[
          const SizedBox(height: JiraniSpace.m),
          Text(l.meetMinutesVersion(minutes.version), style: text.titleSmall),
          if (minutes.text.isNotEmpty) Text(minutes.text),
          if (minutes.hasPhoto) _MinutesPhoto(minutesId: minutes.id),
          if (openMinutes)
            Text(l.meetObjectUntil(_when(context, minutes.objectionUntil)),
                style: text.bodySmall),
          for (final o in minutes.objections)
            Padding(padding: const EdgeInsets.only(top: JiraniSpace.xs),
                child: Notice(l.meetObjection(o.by, o.reason), tone: NoticeTone.warning)),
          if (openMinutes)
            OutlinedButton(
              key: const ValueKey('meet-object'),
              onPressed: _busy ? null : () async {
                final reason = await _ask(l.meetObject, l.meetObjectReason);
                if (reason == null || reason.trim().isEmpty) return;
                await _run(() => repo.objectToMinutes(minutes.id, reason.trim()));
              },
              child: Text(l.meetObject),
            ),
          if (m.sealedReceipt != null)
            Text(l.meetSealedReceipt(m.sealedReceipt!), style: text.bodySmall),
        ],
      ]),
    );
  }
}

class _AskDialog extends StatefulWidget {
  const _AskDialog({required this.title, required this.label, required this.lines});

  final String title;
  final String label;
  final int lines;

  @override
  State<_AskDialog> createState() => _AskDialogState();
}

class _AskDialogState extends State<_AskDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(key: const ValueKey('ask-text'), controller: _c, autofocus: true,
            maxLines: widget.lines,
            keyboardType: widget.lines == 1 ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(labelText: widget.label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
          FilledButton(key: const ValueKey('ask-ok'),
              onPressed: () => Navigator.pop(context, _c.text),
              child: Text(MaterialLocalizations.of(context).okButtonLabel)),
        ],
      );
}

/// The secretary's phone during the meeting: the check-in code, refreshed before it
/// changes.
class _CodeScreen extends ConsumerStatefulWidget {
  const _CodeScreen({required this.meetingId});

  final String meetingId;

  @override
  ConsumerState<_CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends ConsumerState<_CodeScreen> {
  CheckInCode? _code;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await ref.read(chamaRepositoryProvider).checkInCode(widget.meetingId);
      if (!mounted) return;
      setState(() {
        _code = c;
        _error = null;
      });
      _timer = Timer(Duration(seconds: c.changesInSeconds.clamp(1, 30)), _load);
    } catch (e) {
      if (mounted) setState(() => _error = problemText(AppLocalizations.of(context), e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = _code;
    return Scaffold(
      appBar: AppBar(title: Text(l.meetShowCode)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(JiraniSpace.m),
          child: _error != null ? Notice(_error!, tone: NoticeTone.critical)
              : c == null ? const CircularProgressIndicator()
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(color: Colors.white, padding: const EdgeInsets.all(12),
                      child: QrImageView(data: c.qr, size: 240)),
                  const SizedBox(height: JiraniSpace.m),
                  Text(c.code, key: const ValueKey('meet-code'),
                      style: Theme.of(context).textTheme.displaySmall
                          ?.copyWith(letterSpacing: 6)),
                  Text(l.meetCodeHelp, textAlign: TextAlign.center),
                ]),
        ),
      ),
    );
  }
}

class _MinutesEditor extends ConsumerStatefulWidget {
  const _MinutesEditor();

  @override
  ConsumerState<_MinutesEditor> createState() => _MinutesEditorState();
}

class _MinutesEditorState extends ConsumerState<_MinutesEditor> {
  final _text = TextEditingController();
  PickedFile? _photo;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.meetWriteMinutes)),
      bottomNavigationBar: ActionBar(child: PrimaryButton(
        label: l.meetSendMinutes,
        onPressed: () => Navigator.of(context).pop((text: _text.text.trim(), photo: _photo)),
      )),
      body: ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        Notice(l.meetMinutesIntro),
        TextField(key: const ValueKey('minutes-text'), controller: _text, maxLines: 12,
            decoration: InputDecoration(labelText: l.meetMinutesLabel)),
        const SizedBox(height: JiraniSpace.s),
        OutlinedButton.icon(
          key: const ValueKey('minutes-photo'),
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(_photo == null ? l.meetAddPhoto : _photo!.name),
          onPressed: () async {
            final p = await ref.read(fileSourceProvider).pickPhoto();
            if (p != null) setState(() => _photo = p);
          },
        ),
      ]),
    );
  }
}

class _MinutesPhoto extends ConsumerWidget {
  const _MinutesPhoto({required this.minutesId});

  final String minutesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(_photoProvider(minutesId));
    return bytes.when(
      loading: () => const Padding(padding: EdgeInsets.all(JiraniSpace.s),
          child: LinearProgressIndicator()),
      error: (e, _) => const SizedBox.shrink(),
      data: (b) => Padding(padding: const EdgeInsets.only(top: JiraniSpace.s),
          child: Image.memory(b, errorBuilder: (_, _, _) => const SizedBox.shrink())),
    );
  }
}

final _photoProvider = FutureProvider.autoDispose.family((ref, String id) async {
  final bytes = await ref.watch(chamaRepositoryProvider).minutesPhoto(id);
  return Uint8List.fromList(bytes);
});
