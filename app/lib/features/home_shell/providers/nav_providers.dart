import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which page the home shell shows: 0 = Home, 1-4 = the four components
/// (bottom bar destinations, in order).
final selectedTabProvider = StateProvider<int>((ref) => 0);

/// Key of the shell's Scaffold so nested screens can open its drawer.
final shellScaffoldKeyProvider =
    Provider<GlobalKey<ScaffoldState>>((ref) => GlobalKey<ScaffoldState>());
