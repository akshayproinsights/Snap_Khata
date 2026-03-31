import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/config/data/config_repository.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';

final configRepositoryProvider = Provider<ConfigRepository>((ref) {
  return ConfigRepository();
});

final configProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated) {
    return {};
  }
  
  final repo = ref.read(configRepositoryProvider);
  return await repo.getUserConfig();
});

final tableColumnsProvider = Provider.family<List<dynamic>, String>((ref, section) {
  final configAsync = ref.watch(configProvider);
  final config = configAsync.when(
    data: (data) => data,
    loading: () => null,
    error: (e, s) => null,
  );
  if (config == null || config['columns'] == null) {
    return [];
  }
  return config['columns'][section] ?? [];
});
