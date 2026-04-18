import 'package:flutter_riverpod/flutter_riverpod.dart';

enum UdharFilterMode {
  all,
  pending,
  settled,
}

class UdharFilterNotifier extends Notifier<UdharFilterMode> {
  @override
  UdharFilterMode build() => UdharFilterMode.pending; // Default to pending as requested

  void setFilter(UdharFilterMode mode) {
    state = mode;
  }
}

final udharFilterProvider =
    NotifierProvider<UdharFilterNotifier, UdharFilterMode>(
        UdharFilterNotifier.new);

class UdharSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }
}

final udharSearchQueryProvider = NotifierProvider<UdharSearchQueryNotifier, String>(
    UdharSearchQueryNotifier.new);
