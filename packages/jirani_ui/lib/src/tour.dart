import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'components.dart';
import 'tokens.dart';

/// One stop on a guided tour: what to point at and what to say about it. A step with no
/// [target] (or whose target is not on screen) is shown as a card in the middle.
class TourStep {
  const TourStep({
    required this.title,
    required this.body,
    this.target,
    this.icon = Icons.lightbulb_outline_rounded,
    this.tone = JiraniTone.brand,
  });

  final GlobalKey? target;
  final String title;
  final String body;
  final IconData icon;
  final JiraniTone tone;
}

/// The words on the tour's buttons, in the member's language.
class TourLabels {
  const TourLabels({required this.next, required this.done, required this.skip});

  final String next;
  final String done;
  final String skip;
}

/// Walks the member through [steps]: the screen dims, a spotlight moves to each part,
/// a ring pulses around it, and a card springs in beside it explaining what it does.
/// Tapping anywhere or Next moves on; Skip ends it. Completes when the tour closes,
/// with true if every step was seen.
Future<bool> showTour(BuildContext context, List<TourStep> steps,
    {required TourLabels labels}) async {
  if (steps.isEmpty) return true;
  final done = await Navigator.of(context, rootNavigator: true).push<bool>(PageRouteBuilder(
    opaque: false,
    barrierDismissible: false,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, _, _) => _Tour(steps: steps, labels: labels),
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  ));
  return done ?? false;
}

class _Tour extends StatefulWidget {
  const _Tour({required this.steps, required this.labels});

  final List<TourStep> steps;
  final TourLabels labels;

  @override
  State<_Tour> createState() => _TourState();
}

class _TourState extends State<_Tour> with TickerProviderStateMixin {
  int _i = 0;
  Rect? _from;
  Rect? _to;
  late final _move = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 420));
  late final _card = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 460));
  late final _pulse = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _go(0));
  }

  @override
  void dispose() {
    _move.dispose();
    _card.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// Where the step's target is on screen right now, or null when it is not built.
  Rect? _measure(TourStep step) {
    final ctx = step.target?.currentContext;
    if (ctx == null || !ctx.mounted) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return (topLeft & box.size).inflate(6);
  }

  /// Scrolls the step's target into view, then waits for the list to settle.
  Future<Rect?> _rectOf(TourStep step) async {
    final ctx = step.target?.currentContext;
    if (ctx == null || !ctx.mounted) return null;
    await Scrollable.ensureVisible(ctx, alignment: .3,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    await WidgetsBinding.instance.endOfFrame;
    return _measure(step);
  }

  Future<void> _go(int i) async {
    if (i >= widget.steps.length) return _close(true);
    await _card.reverse();
    final rect = await _rectOf(widget.steps[i]);
    if (!mounted) return;
    setState(() {
      _i = i;
      _from = _current;
      _to = rect;
    });
    _move.forward(from: 0);
    _card.forward(from: 0);
  }

  Rect? get _current {
    // Measured every frame: a part that loads late, or a list still settling, is followed.
    final live = _measure(widget.steps[_i]) ?? _to;
    final t = Curves.easeInOutCubic.transform(_move.value);
    if (_from == null) return live;
    if (live == null) return _from;
    return Rect.lerp(_from, live, t);
  }

  void _close(bool finished) {
    if (mounted) Navigator.of(context, rootNavigator: true).pop(finished);
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_i];
    final last = _i == widget.steps.length - 1;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close(false);
      },
      child: Material(
        type: MaterialType.transparency,
        child: LayoutBuilder(builder: (context, box) {
          return AnimatedBuilder(
            animation: Listenable.merge([_move, _pulse, _card]),
            builder: (context, _) {
              final screen = Offset.zero & box.biggest;
              final raw = _current;
              final hole = raw == null || !raw.overlaps(screen) ? null
                  : raw.intersect(screen.deflate(4));
              return Stack(children: [
                // The dimmed screen with the spotlight; a tap moves on.
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _go(_i + 1),
                    child: CustomPaint(
                      painter: _SpotlightPainter(
                        hole: hole,
                        pulse: _pulse.value,
                        scrim: Colors.black.withValues(alpha: .72),
                        ring: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                _placeCard(context, box.biggest, hole, step, last),
              ]);
            },
          );
        }),
      ),
    );
  }

  Widget _placeCard(BuildContext context, Size screen, Rect? hole, TourStep step,
      bool last) {
    const margin = 16.0;
    final safe = MediaQuery.paddingOf(context);
    final width = math.min(screen.width - margin * 2, 420.0);
    final left = (screen.width - width) / 2;
    final t = Curves.easeOutBack.transform(_card.value.clamp(0, 1));
    final fade = Curves.easeOut.transform(_card.value.clamp(0, 1));
    final card = Opacity(
      opacity: fade,
      child: Transform.scale(
        scale: .88 + .12 * t,
        child: _TourCard(
          step: step,
          index: _i,
          count: widget.steps.length,
          labels: widget.labels,
          last: last,
          onNext: () => _go(_i + 1),
          onSkip: () => _close(false),
        ),
      ),
    );
    if (hole == null) {
      return Positioned(left: left, width: width, top: 0, bottom: 0,
          child: Center(child: card));
    }
    // Below the spotlight if it fits, else above it, else at the foot of the screen.
    const room = 250.0;
    final below = hole.bottom + 16;
    final spaceBelow = screen.height - safe.bottom - below;
    final spaceAbove = hole.top - 16 - safe.top;
    final rise = (1 - fade) * 18;
    if (spaceBelow >= room) {
      return Positioned(left: left, width: width, top: below + rise, child: card);
    }
    if (spaceAbove >= room) {
      return Positioned(left: left, width: width,
          bottom: screen.height - hole.top + 16 + rise, child: card);
    }
    return Positioned(left: left, width: width, bottom: safe.bottom + 16 + rise,
        child: card);
  }
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.step,
    required this.index,
    required this.count,
    required this.labels,
    required this.last,
    required this.onNext,
    required this.onSkip,
  });

  final TourStep step;
  final int index;
  final int count;
  final TourLabels labels;
  final bool last;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: JiraniStatus.of(context).card,
      elevation: 12,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ToneIcon(step.icon, tone: step.tone, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(step.title, style: text.titleMedium),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Text(step.body, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          Row(children: [
            // Progress: one dot per step, the current one stretched.
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(right: 5),
                width: i == index ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == index ? scheme.primary : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            const Spacer(),
            if (!last)
              TextButton(key: const ValueKey('tour-skip'), onPressed: onSkip,
                  child: Text(labels.skip)),
            const SizedBox(width: 4),
            FilledButton(
              key: const ValueKey('tour-next'),
              style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
              onPressed: onNext,
              child: Text(last ? labels.done : labels.next),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.hole, required this.pulse, required this.scrim,
      required this.ring});

  final Rect? hole;
  final double pulse;
  final Color scrim;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Path()..addRect(Offset.zero & size);
    final h = hole;
    if (h == null) {
      canvas.drawPath(screen, Paint()..color = scrim);
      return;
    }
    final radius = Radius.circular(math.min(22, h.shortestSide / 2));
    final spot = RRect.fromRectAndRadius(h, radius);
    canvas.drawPath(Path.combine(PathOperation.difference, screen, Path()..addRRect(spot)),
        Paint()..color = scrim);
    // A steady outline, and a ring that grows and fades, drawing the eye to the spot.
    canvas.drawRRect(spot, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = ring);
    final grow = 4 + 14 * pulse;
    canvas.drawRRect(
        RRect.fromRectAndRadius(h.inflate(grow), radius + Radius.circular(grow)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = ring.withValues(alpha: (1 - pulse) * .55));
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole || old.pulse != pulse || old.scrim != scrim;
}
