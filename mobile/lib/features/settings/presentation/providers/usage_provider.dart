import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/settings/data/usage_repository.dart';

final usageRepositoryProvider = Provider<UsageRepository>((ref) {
  return UsageRepository();
});

final usageStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repository = ref.read(usageRepositoryProvider);
  return repository.getUsageStats();
});
