import 'package:flutter/material.dart';

import '../../../core/theme/app_fonts.dart';
import '../models/character_stroke_definition.dart';

class StrokeDemonstrationCanvas extends StatelessWidget {
  const StrokeDemonstrationCanvas({
    super.key,
    required this.definition,
    required this.currentStrokeIndex,
    required this.progress,
    this.showReferenceGlyph = false,
  });

  final CharacterStrokeDefinition definition;
  final int currentStrokeIndex;
  final double progress;
  final bool showReferenceGlyph;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Stroke demonstration for ${definition.character}',
      child: CustomPaint(
        painter: _StrokeDemonstrationPainter(
          definition: definition,
          currentStrokeIndex: currentStrokeIndex,
          progress: progress,
          showReferenceGlyph: showReferenceGlyph,
          strokeColor: Theme.of(context).colorScheme.onSurface,
          accentColor: Theme.of(context).colorScheme.primary,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _StrokeDemonstrationPainter extends CustomPainter {
  const _StrokeDemonstrationPainter({
    required this.definition,
    required this.currentStrokeIndex,
    required this.progress,
    required this.showReferenceGlyph,
    required this.strokeColor,
    required this.accentColor,
  });

  final CharacterStrokeDefinition definition;
  final int currentStrokeIndex;
  final double progress;
  final bool showReferenceGlyph;
  final Color strokeColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGuideLines(canvas, size);
    if (showReferenceGlyph) _paintReferenceGlyph(canvas, size);

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final paths = [
      for (final stroke in definition.strokes) stroke.buildPath(size),
    ];

    for (var index = 0; index < currentStrokeIndex; index++) {
      canvas.drawPath(paths[index], strokePaint);
    }

    final activePath = paths[currentStrokeIndex];
    final metric = activePath.computeMetrics().first;
    final visibleLength = metric.length * progress.clamp(0.0, 1.0);
    if (visibleLength > 0) {
      canvas.drawPath(metric.extractPath(0, visibleLength), strokePaint);
    }

    final penPosition = metric.getTangentForOffset(visibleLength)?.position;
    if (penPosition != null) _paintPen(canvas, penPosition);

    // Keep debug markers above the pen indicator so the end ring remains
    // visible when an animation reaches 100 percent.
    if (showReferenceGlyph) {
      _paintDebugMarkers(canvas, paths);
    } else {
      final start = metric.getTangentForOffset(0)?.position;
      if (start != null) _paintStartPoint(canvas, start);
    }
  }

  void _paintReferenceGlyph(Canvas canvas, Size size) {
    final glyphPainter = TextPainter(
      text: TextSpan(
        text: definition.character,
        style: TextStyle(
          color: const Color(0xFF455A64).withValues(alpha: 0.09),
          fontFamily: AppFonts.sinhala,
          fontSize: size.shortestSide * 0.72,
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    glyphPainter.paint(
      canvas,
      Offset(
        (size.width - glyphPainter.width) / 2,
        (size.height - glyphPainter.height) / 2,
      ),
    );
  }

  void _paintDebugMarkers(Canvas canvas, List<Path> paths) {
    for (var index = 0; index < paths.length; index++) {
      final metric = paths[index].computeMetrics().first;
      final start = metric.getTangentForOffset(0)?.position;
      final end = metric.getTangentForOffset(metric.length)?.position;
      if (start == null || end == null) continue;

      _paintStartPoint(canvas, start);
      canvas.drawCircle(
        end,
        8,
        Paint()
          ..color = const Color(0xFFE65100)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );

      final numberPainter = TextPainter(
        text: TextSpan(
          text: '${index + 1}',
          style: const TextStyle(
            color: Color(0xFF2E7D32),
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      numberPainter.paint(canvas, start + const Offset(12, -24));
    }
  }

  void _paintStartPoint(Canvas canvas, Offset start) {
    canvas.drawCircle(
      start,
      8,
      Paint()..color = const Color(0xFF43A047),
    );
    canvas.drawCircle(
      start,
      13,
      Paint()
        ..color = const Color(0xFF43A047).withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  void _paintGuideLines(Canvas canvas, Size size) {
    final guidePaint = Paint()
      ..color = const Color(0xFF90CAF9).withValues(alpha: 0.24)
      ..strokeWidth = 2;
    for (final fraction in [0.25, 0.5, 0.75]) {
      final y = size.height * fraction;
      canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), guidePaint);
    }
  }

  void _paintPen(Canvas canvas, Offset position) {
    const iconSize = 30.0;
    final background = Path()
      ..addOval(Rect.fromCircle(center: position, radius: 22));
    canvas.drawShadow(background, Colors.black, 4, false);
    canvas.drawCircle(position, 20, Paint()..color = Colors.white);

    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.edit_rounded.codePoint),
        style: TextStyle(
          color: accentColor,
          fontSize: iconSize,
          fontFamily: Icons.edit_rounded.fontFamily,
          package: Icons.edit_rounded.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    iconPainter.paint(
      canvas,
      position - Offset(iconPainter.width / 2, iconPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_StrokeDemonstrationPainter oldDelegate) =>
      oldDelegate.definition != definition ||
      oldDelegate.currentStrokeIndex != currentStrokeIndex ||
      oldDelegate.progress != progress ||
      oldDelegate.showReferenceGlyph != showReferenceGlyph ||
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.accentColor != accentColor;
}
