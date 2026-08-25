import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/session_providers.dart';
import '../domain/goal.dart';

final goalsStreamProvider = StreamProvider<List<Goal>>((ref) {
  final repo = ref.watch(goalsRepoProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchAll().map((g) => g.where((x) => !x.archived).toList()
    ..sort((a, b) => a.progress.compareTo(b.progress)));
});
