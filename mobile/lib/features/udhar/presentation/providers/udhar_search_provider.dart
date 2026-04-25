import 'package:flutter_riverpod/flutter_riverpod.dart';

enum UdharFilterMode {
  all,
  customers,
  suppliers,
  pending,
  settled,
}

class UdharFilterNotifier extends Notifier<UdharFilterMode> {
  @override
  UdharFilterMode build() => UdharFilterMode.all; // Default to all as per new design

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
