import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accounting/statement.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/utils/dates.dart';
import '../data/party_repository.dart';
import '../domain/party.dart';

final partyRepositoryProvider = Provider.family<PartyRepository, PartyKind>(
  (ref, kind) => PartyRepository(ref.watch(firestoreProvider), kind),
);

final partyProvider = StreamProvider.autoDispose.family<Party, (PartyKind, String)>(
  (ref, key) => ref.watch(partyRepositoryProvider(key.$1)).watch(key.$2),
);

final partyStatementProvider = FutureProvider.autoDispose
    .family<Statement, (PartyKind, String, DateRange)>((ref, key) {
  // Recompute whenever the party's balance changes (new movement posted).
  ref.watch(partyProvider((key.$1, key.$2)).select((p) => p.value?.balance));
  return ref.watch(partyRepositoryProvider(key.$1)).statement(key.$2, key.$3);
});
