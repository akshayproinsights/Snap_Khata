import 'package:flutter_riverpod/flutter_riverpod.dart';

class UdharSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }
}

final udharSearchQueryProvider = NotifierProvider<UdharSearchQueryNotifier, String>(
    UdharSearchQueryNotifier.new);
