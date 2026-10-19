import 'package:flutter/foundation.dart';

class HandwritingDebugConfig {
  const HandwritingDebugConfig._();

  /// Enable with `--dart-define=HANDWRITING_DEBUG=true` in a debug build.
  /// It is deliberately unavailable in profile and release builds.
  static const bool _requested = bool.fromEnvironment(
    'HANDWRITING_DEBUG',
    defaultValue: false,
  );

  static const bool enabled = kDebugMode && _requested;
}
