import 'package:flutter/material.dart';

class HandwritingPracticeScreen extends StatefulWidget {
  const HandwritingPracticeScreen({
    super.key,
    required this.character,
  });

  final String character;

  @override
  State<HandwritingPracticeScreen> createState() =>
      _HandwritingPracticeScreenState();
}

class _HandwritingPracticeScreenState extends State<HandwritingPracticeScreen> {
  final List<List<Offset>> _penStrokes = [];

  void _startStroke(DragStartDetails details) {
    setState(() => _penStrokes.add([details.localPosition]));
  }

  void _continueStroke(DragUpdateDetails details) {
    if (_penStrokes.isEmpty) return;
    setState(() => _penStrokes.last.add(details.localPosition));
  }

  void _clear() => setState(_penStrokes.clear);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Practice Time!')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Write ${widget.character}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Use your finger to follow the letter.',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.3,
                        ),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: GestureDetector(
                      key: const ValueKey('handwriting-practice-canvas'),
                      behavior: HitTestBehavior.opaque,
                      onPanStart: _startStroke,
                      onPanUpdate: _continueStroke,
                      child: CustomPaint(
                        painter: _PracticePainter(
                          character: widget.character,
                          penStrokes: _penStrokes,
                          inkColor: theme.colorScheme.onSurface,
                          guideColor: theme.colorScheme.primary,
                          fontFamily: theme.textTheme.displayLarge?.fontFamily,
                          fontFamilyFallback:
                              theme.textTheme.displayLarge?.fontFamilyFallback,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _penStrokes.isEmpty ? null : _clear,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Clear and Try Again'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PracticePainter extends CustomPainter {
  const _PracticePainter({
    required this.character,
    required this.penStrokes,
    required this.inkColor,
    required this.guideColor,
    required this.fontFamily,
    required this.fontFamilyFallback,
  });

  final String character;
  final List<List<Offset>> penStrokes;
  final Color inkColor;
  final Color guideColor;
  final String? fontFamily;
  final List<String>? fontFamilyFallback;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = guideColor.withValues(alpha: 0.16)
      ..strokeWidth = 2;
    for (final fraction in [0.25, 0.5, 0.75]) {
      final y = size.height * fraction;
      canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), linePaint);
    }

    final guideText = TextPainter(
      text: TextSpan(
        text: character,
        style: TextStyle(
          color: inkColor.withValues(alpha: 0.08),
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          fontSize: size.shortestSide * 0.65,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    guideText.paint(
      canvas,
      Offset(
        (size.width - guideText.width) / 2,
        (size.height - guideText.height) / 2,
      ),
    );

    final inkPaint = Paint()
      ..color = inkColor
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final points in penStrokes) {
      if (points.length == 1) {
        canvas.drawCircle(points.first, inkPaint.strokeWidth / 2, inkPaint);
        continue;
      }
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, inkPaint);
    }
  }

  @override
  bool shouldRepaint(_PracticePainter oldDelegate) => true;
}
