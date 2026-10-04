import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

/// Shared dio instance, pointed at the configurable backend base URL.
/// All four components should use this provider rather than constructing
/// their own Dio instance, so base URL / interceptors / logging stay in one place.
final apiClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  dio.interceptors.add(LogInterceptor(requestBody: false, responseBody: false));

  return dio;
});
