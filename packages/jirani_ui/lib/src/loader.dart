import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// The loading sign: the JiraniChama mark with its members (the gold dots) spinning fast
/// around the pot, and a bright trail behind them. Used wherever a page is loading, in
/// place of a plain spinner, so waiting still looks like JiraniChama.
///
/// With "reduce motion" on (the phone's setting or ours) it turns slowly instead.
class BrandLoader extends StatefulWidget {
  const BrandLoader({super.key, this.size = 64, this.label});

  final double size;

  /// A short line under the mark ("Loading your chama…"). Optional.
  final String? label;

  @override
  State<BrandLoader> createState() => _BrandLoaderState();
}

class _BrandLoaderState extends State<BrandLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 650));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final calm = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _spin.duration = calm ? const Duration(milliseconds: 2400) : const Duration(milliseconds: 650);
    _spin.repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = JiraniStatus.of(context);
    final size = widget.size;
    final mark = Semantics(
      label: widget.label ?? 'Loading',
      child: Container(
        key: const ValueKey('brand-loader'),
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * .3),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [status.heroStart, status.heroEnd],
          ),
          boxShadow: [
            BoxShadow(color: status.heroStart.withValues(alpha: .35), blurRadius: size * .3,
                offset: Offset(0, size * .08)),
          ],
        ),
        child: AnimatedBuilder(
          animation: _spin,
          builder: (_, _) => CustomPaint(painter: _SpinPainter(_spin.value)),
        ),
      ),
    );
    if (widget.label == null) return mark;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      mark,
      const SizedBox(height: JiraniSpace.m),
      Text(widget.label!, textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]);
  }
}

class _SpinPainter extends CustomPainter {
  _SpinPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final w = size.width;
    // The pot breathes a little as the members go round it.
    final pulse = 1 + .06 * math.sin(t * 2 * math.pi * 2);
    canvas.drawCircle(c, w * .18 * pulse, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .07
      ..color = Colors.white);
    final turn = t * 2 * math.pi;
    final orbit = w * .32;
    // A gold trail sweeping behind the leading dot.
    final trail = Rect.fromCircle(center: c, radius: orbit);
    canvas.drawArc(trail, -math.pi / 2 + turn - 1.6, 1.6, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * .05
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        colors: const [Color(0x00F2C36B), Color(0xAAF2C36B)],
        transform: GradientRotation(-math.pi / 2 + turn - 1.6),
        stops: const [0, .26],
      ).createShader(trail));
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 3 + turn;
      // The leading dot is brightest and largest; the rest fade behind it.
      final lead = i == 0;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * orbit,
          w * (lead ? .07 : .052),
          Paint()..color = Color.lerp(const Color(0xFFF2C36B), Colors.white, lead ? .35 : 0)!
              .withValues(alpha: lead ? 1 : .55 + .07 * i));
    }
  }

  @override
  bool shouldRepaint(_SpinPainter old) => old.t != t;
}

/// A page that is loading: the spinning mark in the middle.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) => Center(child: BrandLoader(label: label));
}
