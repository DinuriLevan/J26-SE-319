import 'dart:ui';

enum StrokeSegmentType { line, quadratic, cubic }

class StrokeSegment {
  const StrokeSegment.line(this.end)
      : type = StrokeSegmentType.line,
        control1 = null,
        control2 = null;

  const StrokeSegment.quadratic({required this.control1, required this.end})
      : type = StrokeSegmentType.quadratic,
        control2 = null;

  const StrokeSegment.cubic({
    required this.control1,
    required this.control2,
    required this.end,
  }) : type = StrokeSegmentType.cubic;

  final StrokeSegmentType type;
  final Offset end;
  final Offset? control1;
  final Offset? control2;
}

/// A single uninterrupted pen stroke expressed with normalized coordinates.
/// Coordinates run from 0 to 1, making the same data fit any canvas size.
class StrokeDefinition {
  const StrokeDefinition({
    required this.start,
    required this.segments,
    required this.instruction,
  }) : sampledPoints = const [];

  /// A stroke captured as ordered, normalized centre-line points.
  ///
  /// The first point is kept in [start]. Every point in [sampledPoints]
  /// follows it in the exact direction the pen should travel.
  const StrokeDefinition.polyline({
    required this.start,
    required this.sampledPoints,
    required this.instruction,
  }) : segments = const [];

  final Offset start;
  final List<StrokeSegment> segments;
  final List<Offset> sampledPoints;
  final String instruction;

  Path buildPath(Size size) {
    Offset scale(Offset point) => Offset(
          point.dx * size.width,
          point.dy * size.height,
        );

    final startPoint = scale(start);
    final path = Path()..moveTo(startPoint.dx, startPoint.dy);

    if (sampledPoints.isNotEmpty) {
      for (final point in sampledPoints) {
        final scaledPoint = scale(point);
        path.lineTo(scaledPoint.dx, scaledPoint.dy);
      }
      return path;
    }

    for (final segment in segments) {
      final end = scale(segment.end);
      switch (segment.type) {
        case StrokeSegmentType.line:
          path.lineTo(end.dx, end.dy);
        case StrokeSegmentType.quadratic:
          final control = scale(segment.control1!);
          path.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
        case StrokeSegmentType.cubic:
          final control1 = scale(segment.control1!);
          final control2 = scale(segment.control2!);
          path.cubicTo(
            control1.dx,
            control1.dy,
            control2.dx,
            control2.dy,
            end.dx,
            end.dy,
          );
      }
    }

    return path;
  }
}
