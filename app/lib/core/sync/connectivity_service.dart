import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device currently has some form of network connectivity.
/// Feature components generally don't need this directly — the sync
/// service already reacts to it — but it's exposed for UI that wants to
/// show an offline indicator.
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.maybeWhen(
    data: (results) => results.any((r) => r != ConnectivityResult.none),
    orElse: () => false,
  );
});
