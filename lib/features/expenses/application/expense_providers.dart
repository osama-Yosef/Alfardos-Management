import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../data/expense_repository.dart';
import '../domain/expense.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(ref.watch(firestoreProvider), ref.watch(storageProvider)),
);

final expenseCategoriesProvider = StreamProvider<List<ExpenseCategory>>(
  (ref) => ref.watch(expenseRepositoryProvider).watchCategories(),
);

final activeExpenseCategoriesProvider = Provider<List<ExpenseCategory>>((ref) {
  return (ref.watch(expenseCategoriesProvider).value ?? const [])
      .where((c) => c.active)
      .toList();
});
