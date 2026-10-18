import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/retry_loop.dart';
import 'parrot.dart';
import 'speech_theme.dart';

/// The parrot with a speech bubble holding the instruction or feedback. With [onReplay], a round
/// speaker button on the bubble repeats the spoken instruction ([replayLabel] for screen readers).
class ParrotSays extends StatelessWidget {
  const ParrotSays({
    super.key,
    required this.text,
    this.mood = ParrotMood.idle,
    this.parrotSize = 104,
    this.talking = false,
    this.onReplay,
    this.replayLabel = 'Hear again',
  });

  final String text;
  final ParrotMood mood;
  final double parrotSize;
  final bool talking;
  final VoidCallback? onReplay;
  final String replayLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ParrotBuddy(mood: mood, size: parrotSize, talking: talking),
        const SizedBox(width: 4),
        Expanded(
          child: CustomPaint(
            painter: _BubblePainter(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: SpeechTheme.motion(context)
                          ? const Duration(milliseconds: 250)
                          : Duration.zero,
                      child: Text(
                        text,
                        key: ValueKey(text),
                        style: theme.textTheme.titleMedium!
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  if (onReplay != null) ...[
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      label: replayLabel,
                      excludeSemantics: true,
                      child: Material(
                        color: talking ? SpeechColors.coral : SpeechColors.sky,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onReplay,
                          child: SizedBox.square(
                            dimension: 52,
                            child: Icon(Icons.volume_up_rounded,
                                size: 30,
                                color: talking
                                    ? SpeechColors.paper
                                    : SpeechColors.blue),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tail = 12.0;
    final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(tail, 0, size.width - tail, size.height),
        const Radius.circular(22));
    final path = Path()
      ..addRRect(r)
      ..moveTo(tail, size.height * 0.45)
      ..lineTo(0, size.height * 0.55)
      ..lineTo(tail, size.height * 0.62)
      ..close();
    canvas.drawShadow(path, SpeechColors.shadow, 4, false);
    canvas.drawPath(path, Paint()..color = SpeechColors.paper);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Big round coral mic. Pulsing rings while recording; a soft stop square to finish.
class MicButton extends StatefulWidget {
  const MicButton({
    super.key,
    required this.recording,
    required this.onPressed,
    required this.label,
    this.size = 140,
  });

  final bool recording;
  final VoidCallback? onPressed;

  /// Spoken by screen readers (e.g. "Tap the mic and say the word").
  final String label;
  final double size;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(MicButton old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.recording && SpeechTheme.motion(context)) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      value: widget.recording ? 'recording' : null,
      child: SizedBox.square(
        dimension: s * 1.5,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) => CustomPaint(
            painter: _RingsPainter(_pulse.value, widget.recording),
            child: child,
          ),
          child: Center(
            child: GestureDetector(
              onTap: widget.onPressed,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: s,
                height: s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: enabled
                        ? [SpeechColors.coral, SpeechColors.coralDeep]
                        : [const Color(0xFFD9D4CC), const Color(0xFFC4BEB4)],
                  ),
                  boxShadow: speechShadow,
                ),
                child: Center(
                  child: widget.recording
                      ? Container(
                          width: s * 0.3,
                          height: s * 0.3,
                          decoration: BoxDecoration(
                            color: SpeechColors.paper,
                            borderRadius: BorderRadius.circular(s * 0.08),
                          ),
                        )
                      : Icon(Icons.mic_rounded,
                          size: s * 0.48, color: SpeechColors.paper),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.t, this.on);

  final double t;
  final bool on;

  @override
  void paint(Canvas canvas, Size size) {
    if (!on) return;
    final c = size.center(Offset.zero);
    final base = size.width / 3;
    for (var i = 0; i < 2; i++) {
      final ph = (t + i * 0.5) % 1.0;
      canvas.drawCircle(
        c,
        base + ph * size.width / 6,
        Paint()
          ..color = SpeechColors.coral.withValues(alpha: (1 - ph) * 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6,
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.t != t || old.on != on;
}

/// Big sky-blue speaker button for the Listen step, with sound waves while playing.
class ListenButton extends StatefulWidget {
  const ListenButton({
    super.key,
    required this.playing,
    required this.onPressed,
    required this.label,
    this.size = 140,
  });

  final bool playing;
  final VoidCallback onPressed;
  final String label;
  final double size;

  @override
  State<ListenButton> createState() => _ListenButtonState();
}

class _ListenButtonState extends State<ListenButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ListenButton old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.playing && SpeechTheme.motion(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: SizedBox(
          width: s * 1.7,
          height: s,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              painter: _WavesPainter(_c.value, widget.playing, s),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: s,
                  height: s,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: SpeechColors.blue,
                    boxShadow: speechShadow,
                  ),
                  child: Icon(Icons.volume_up_rounded,
                      size: s * 0.5, color: SpeechColors.paper),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WavesPainter extends CustomPainter {
  _WavesPainter(this.t, this.on, this.s);

  final double t;
  final bool on;
  final double s;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(s * 0.55, size.height / 2);
    for (var i = 0; i < 3; i++) {
      final alpha = on
          ? (0.3 + 0.7 * ((math.sin((t - i * 0.2) * 2 * math.pi) + 1) / 2))
          : 0.35;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: s * (0.62 + 0.16 * i)),
        -0.6,
        1.2,
        false,
        Paint()
          ..color = SpeechColors.blue.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_WavesPainter old) => old.t != t || old.on != on;
}

/// The word as one tile per unit (akshara / letter chunk). Target units are raised and filled
/// with colour, which is easier on dyslexic readers than underlining.
class SyllableTiles extends StatelessWidget {
  const SyllableTiles({
    super.key,
    required this.units,
    this.targetStart,
    this.targetEnd,
    this.fontSize = 56,
    this.onTapUnit,
    this.canTapUnit,
    this.hearLabel = 'Hear',
  });

  final List<String> units;
  final int? targetStart;
  final int? targetEnd;
  final double fontSize;

  /// "Hear before saying": called with the tile's index when a tappable tile is tapped.
  final void Function(int index)? onTapUnit;

  /// Which tiles can be tapped (all, when null and [onTapUnit] is set).
  final bool Function(int index)? canTapUnit;

  /// Screen-reader prefix for tappable tiles, e.g. "Hear" -> "Hear ම".
  final String hearLabel;

  bool tappable(int i) => onTapUnit != null && (canTapUnit?.call(i) ?? true);

  bool isTarget(int i) =>
      targetStart != null && i >= targetStart! && i <= targetEnd!;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.displayMedium!;
    final motion = SpeechTheme.motion(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < units.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AnimatedScale(
                scale: isTarget(i) ? 1.1 : 1.0,
                duration:
                    motion ? const Duration(milliseconds: 300) : Duration.zero,
                curve: Curves.easeOutBack,
                child: _tappable(
                  i,
                  Container(
                    key: ValueKey('tile_$i'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          isTarget(i) ? SpeechColors.peach : SpeechColors.paper,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isTarget(i)
                            ? SpeechColors.coral
                            : SpeechColors.navySoft.withValues(alpha: 0.15),
                        width: isTarget(i) ? 3 : 2,
                      ),
                      boxShadow: isTarget(i) ? speechShadow : null,
                    ),
                    child: Text(units[i],
                        style:
                            style.copyWith(fontSize: fontSize, height: 1.25)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Makes a tile tappable (with a small speaker badge) when it can be heard.
  Widget _tappable(int i, Widget tile) {
    if (!tappable(i)) return tile;
    return Semantics(
      button: true,
      label: '$hearLabel ${units[i]}',
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('tap_tile_$i'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onTapUnit!(i),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            tile,
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: SpeechColors.sky,
                  boxShadow: speechShadow,
                ),
                child: const Icon(Icons.volume_up_rounded,
                    size: 16, color: SpeechColors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the child is in the practice loop: Word, Listen, Sound, Together (then Word again).
class StepTrail extends StatelessWidget {
  const StepTrail({super.key, required this.kind});

  final StepKind kind;

  static const _steps = [
    (StepKind.fullWord, Icons.record_voice_over_rounded),
    (StepKind.listen, Icons.hearing_rounded),
    (StepKind.sayUnit, Icons.mic_rounded),
    (StepKind.blend, Icons.join_inner_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final motion = SpeechTheme.motion(context);
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final (i, (k, icon)) in _steps.indexed) ...[
            if (i > 0)
              Container(
                width: 18,
                height: 4,
                decoration: BoxDecoration(
                  color: SpeechColors.navySoft.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            AnimatedContainer(
              duration:
                  motion ? const Duration(milliseconds: 250) : Duration.zero,
              width: k == kind ? 48 : 36,
              height: k == kind ? 48 : 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: k == kind ? SpeechColors.coral : SpeechColors.paper,
                border: Border.all(
                    color: SpeechColors.navySoft.withValues(alpha: 0.2),
                    width: 2),
              ),
              child: Icon(icon,
                  size: k == kind ? 26 : 20,
                  color:
                      k == kind ? SpeechColors.paper : SpeechColors.navySoft),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lays a Column (which may use Spacers) out to fill the screen, but scrolls instead of
/// overflowing on short screens or in landscape.
class FillOrScroll extends StatelessWidget {
  const FillOrScroll(
      {super.key, required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              minHeight: constraints.maxHeight - padding.vertical),
          child: IntrinsicHeight(child: child),
        ),
      ),
    );
  }
}
