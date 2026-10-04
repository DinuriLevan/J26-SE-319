import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Index of the currently selected bottom-nav tab in the home shell.
final selectedTabProvider = StateProvider<int>((ref) => 0);
