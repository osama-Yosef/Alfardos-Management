import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../data/invoice_repository.dart';
import '../domain/invoice.dart';

final invoiceRepositoryProvider = Provider.family<InvoiceRepository, InvoiceKind>(
  (ref, kind) => InvoiceRepository(ref.watch(firestoreProvider), kind),
);

final invoiceProvider = StreamProvider.autoDispose.family<Invoice, (InvoiceKind, String)>(
  (ref, key) => ref.watch(invoiceRepositoryProvider(key.$1)).watch(key.$2),
);
